import { appendFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const TARGETS = [
  {platform: 'linux', os: 'ubuntu-22.04', arch: 'x64'},
  {platform: 'windows', os: 'windows-2022', arch: 'x64'},
  {platform: 'android', os: 'ubuntu-24.04', arch: 'arm64'},
  {platform: 'macos', os: 'xcode-27', arch: 'arm64'},
  {platform: 'macos', os: 'xcode-27', arch: 'x64', flutter_arch: 'x64'},
];

export function selectCloudBuild(env) {
  const official = env.OFFICIAL_REQUESTED === 'true';
  if (official && (env.OFFICIAL_TRUSTED !== 'true' || env.PLATFORM !== 'all' || env.IOS_SOURCE !== 'project')) {
    throw new Error('Official builds run only from client-release.yml on a Zolmid/FlClash tag push, for every platform');
  }
  if (env.ANDROID_RELEASE_REQUESTED === 'true' &&
      (env.CLIENT_BRANCH !== 'true' || !['all', 'android'].includes(env.PLATFORM))) {
    throw new Error('Android release requires a client branch and an Android target');
  }
  const targets = TARGETS.map(t => ({...t, safe_preview: false}))
    .filter(t => env.PLATFORM === 'all' || t.platform === env.PLATFORM);
  if (env.CLIENT_BRANCH === 'true' && ['all', 'macos'].includes(env.PLATFORM)) {
    targets.push({platform: 'macos', os: 'xcode-27', arch: 'arm64', safe_preview: true});
  }
  const clientBranch = env.CLIENT_BRANCH === 'true' || official;
  const androidRelease = env.ANDROID_RELEASE === 'true' || official;
  const nativeUi = env.NATIVE_BRANCH === 'true' || official;
  return `platform=${env.PLATFORM}\nios_source=${env.IOS_SOURCE}\nandroid_release=${androidRelease}\nofficial=${official}\nclient_branch=${clientBranch}\nnative_ui=${nativeUi}\nmatrix=${JSON.stringify({include: targets})}\nenabled=${targets.length > 0}\n`;
}

function invokedAsScript() {
  try {
    return realpathSync(process.argv[1]) === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
}

if (invokedAsScript()) {
  appendFileSync(process.env.GITHUB_OUTPUT, selectCloudBuild(process.env));
}
