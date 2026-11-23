"""Review OSV changes between two immutable Git trees, or export a source SBOM."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


MANIFESTS = frozenset(('pubspec.lock', 'Cargo.lock', 'go.mod', 'package-lock.json', 'pnpm-lock.yaml',
                       'yarn.lock', 'gradle.lockfile', 'buildscript-gradle.lockfile', 'Gemfile.lock'))
CORE = 'core/Clash.Meta'


def manifests(revision, store='.'):
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Expected a full commit SHA')
    tree = subprocess.check_output(['git', '-C', store, 'ls-tree', '-rz', '--full-tree', revision], timeout=30)
    result = {}
    for entry in tree.split(b'\0'):
        if not entry:
            continue
        header, path = entry.split(b'\t', 1)
        name = os.fsdecode(path)
        if Path(name).name not in MANIFESTS:
            continue
        mode, kind, oid = header.split()
        if kind != b'blob' or mode not in (b'100644', b'100755'):
            raise ValueError(f'Dependency input must be a regular tracked file: {name!r}')
        result[name] = oid.decode('ascii')
    return result


def core_pin(revision):
    entry = subprocess.check_output(['git', '-C', '.', 'ls-tree', revision, '--', CORE], text=True, timeout=15)
    if not entry:
        return ''
    mode, kind, oid, path = entry.split()
    if (mode, kind, path) != ('160000', 'commit', CORE):
        raise ValueError('Expected the Core gitlink')
    return oid


def core_manifests(pin):
    if not pin:
        return {}
    if Path(subprocess.check_output(['git', '-C', CORE, 'rev-parse', '--show-toplevel'],
                                    text=True, timeout=15).strip()).resolve() != Path(CORE).resolve():
        raise ValueError('Initialize the pinned Core submodule for dependency review')
    return {CORE + '/' + path: oid for path, oid in manifests(pin, CORE).items()}


def changed(before, after):
    return sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))


def scan(inputs, work, out, output_format):
    # Materialize only selected blobs outside the checkout. No build scripts or repository OSV ignores execute.
    args = ['osv-scanner', 'scan', 'source', '--all-packages', '--no-resolve', '--format', output_format,
            '--output-file', str(out)]
    sources = {}
    for i, (name, oid) in enumerate(sorted(inputs.items())):
        store = CORE if name.startswith(CORE + '/') else '.'
        cat = ['git', '-C', store, 'cat-file']
        size = int(subprocess.check_output([*cat, '-s', oid], timeout=15))
        if size > 16 * 1024 * 1024:
            raise ValueError(f'Dependency input exceeds 16 MiB: {name!r}')
        path = work / str(i) / Path(name).name
        path.parent.mkdir()
        path.write_bytes(subprocess.check_output([*cat, 'blob', oid], timeout=20))
        sources[str(path)] = name
        args.extend(['--lockfile', str(path)])
    with out.with_suffix('.log').open('w', encoding='utf-8') as log:
        run = subprocess.run(args, cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=360)
    if run.returncode not in (0, 1):
        raise ValueError(f'OSV-Scanner failed (exit {run.returncode}); see {out.name} scan log')
    report = json.loads(out.read_text(encoding='utf-8'))
    if output_format == 'json':
        seen = set()
        for group in report['results']:
            source = group['source']
            name = sources[source['path']]
            source['path'] = name
            seen.add(name)
        if seen != set(inputs):
            raise ValueError('OSV did not return results for every selected dependency input')
        out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return report


def findings(report):
    return {(group['source']['path'], pkg['package']['ecosystem'], pkg['package']['name'],
             pkg['package']['version'], vuln['id'])
            for group in report['results'] for pkg in group['packages']
            for vuln in pkg.get('vulnerabilities', [])}


def summarize(text):
    print(text)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as summary:
            summary.write(text + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('plan', 'compare', 'inventory'))
    parser.add_argument('--head', required=True)
    parser.add_argument('--base')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    head = manifests(args.head)
    pin = core_pin(args.head)
    if args.mode != 'inventory':
        if not args.base:
            parser.error('--base is required for a comparison')
        base = manifests(args.base)
        old_pin = core_pin(args.base)
        delta = changed(base, head)
        if args.mode == 'plan':
            print('changed=' + str(bool(delta) or old_pin != pin).lower())
            print('core_checkout=' + ((pin or old_pin) if old_pin != pin else ''))
            return 0
        if old_pin != pin:
            base.update(core_manifests(old_pin))
            head.update(core_manifests(pin))
            delta = changed(base, head)
    if not args.output:
        parser.error('--output is required for a report')
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if args.mode == 'inventory':
        head.update(core_manifests(pin))
        if not head:
            raise ValueError('No supported dependency files in the selected tree')
        with tempfile.TemporaryDirectory() as tmp:
            bom = scan(head, Path(tmp), out / 'sbom.cdx.json', 'cyclonedx-1-6')
        if bom.get('bomFormat') != 'CycloneDX' or bom.get('specVersion') != '1.6' or not bom.get('components'):
            raise ValueError('OSV did not produce a populated CycloneDX 1.6 inventory')
        evidence = {'commit': args.head, 'core_commit': pin, 'git_blobs': head, 'components': len(bom['components']),
                    'matched_advisories': len(bom.get('vulnerabilities', []))}
        (out / 'source.json').write_text(json.dumps(evidence, indent=2) + '\n')
        summarize(f"Source inventory: {len(head)} tracked inputs, {evidence['components']} components, "
                  f"{evidence['matched_advisories']} advisory records. Inspect the CycloneDX artifact for triage.")
        return 0
    sides = []
    for label, tree in (('base', base), ('merged', head)):
        inputs = {p: tree[p] for p in delta if p in tree}
        with tempfile.TemporaryDirectory() as tmp:
            report = scan(inputs, Path(tmp), out / (label + '.json'), 'json') if inputs else {'results': []}
        sides.append(findings(report))
    added = sorted(sides[1] - sides[0])
    (out / 'comparison.json').write_text(json.dumps({'base': args.base, 'head': args.head,
        'changed_inputs': delta, 'introduced': added, 'removed': sorted(sides[0] - sides[1])}, indent=2) + '\n')
    summarize(f'Dependency review: {len(delta)} changed inputs, {len(added)} newly matched '
              'package/version/advisory combinations. Details are in comparison.json.')
    return 1 if added else 0


if __name__ == '__main__':
    raise SystemExit(main())
