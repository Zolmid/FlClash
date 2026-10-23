#!/usr/bin/env python3
"""Generate native icons from the unchanged, official ZolNit brand package."""

import argparse
import io
import json
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
SVG = 'http://www.w3.org/2000/svg'
ANDROID = 'http://schemas.android.com/apk/res/android'


def write(path, text):
    path = REPO / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')


def png(image, path, size):
    path = REPO / path
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, optimize=True)


def ico(image, path, sizes):
    stream = io.BytesIO()
    image.resize((256, 256), Image.Resampling.LANCZOS).save(
        stream, format='ICO', sizes=[(size, size) for size in sizes],
    )
    (REPO / path).write_bytes(stream.getvalue())


def tinted(image, color):
    result = Image.new('RGBA', image.size, color)
    result.putalpha(image.getchannel('A'))
    return result


def marker(image, color):
    result = image.copy()
    ImageDraw.Draw(result).ellipse((946, 946, 1010, 1010), fill=color)
    return result


def vector(paths, size, extent):
    root = ET.Element('vector', {
        'xmlns:android': ANDROID,
        'android:width': f'{size}dp', 'android:height': f'{size}dp',
        'android:viewportWidth': str(extent),
        'android:viewportHeight': str(extent),
    })
    scale = extent / 644
    group = ET.SubElement(root, 'group', {
        'android:scaleX': str(scale), 'android:scaleY': str(scale),
        'android:translateX': str(-190 * scale),
        'android:translateY': str(-190 * scale),
    })
    for path in paths:
        ET.SubElement(group, 'path', {
            'android:pathData': path, 'android:fillColor': '#FFFFFF',
        })
    return ET.tostring(root, encoding='unicode') + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('brand_package', type=Path)
    brand = parser.parse_args().brand_package.resolve()
    sources = {
        'light': brand / 'icons/zolnit-app-light-1024.png',
        'dark': brand / 'icons/zolnit-app-dark-1024.png',
        'symbol': brand / 'logos/png/zolnit-symbol-1024.png',
        'black': brand / 'logos/png/zolnit-symbol-black-1024.png',
        'svg': brand / 'logos/svg/zolnit-symbol.svg',
        'mono': brand / 'logos/svg/zolnit-symbol-black.svg',
    }
    for path in sources.values():
        if not path.is_file():
            parser.error(f'Missing official source: {path}')
    images = {
        name: Image.open(sources[name]).convert('RGBA')
        for name in ('light', 'dark', 'symbol', 'black')
    }
    light, dark = images['light'], images['dark']
    color_svg = sources['svg'].read_text()
    mono_svg = sources['mono'].read_text()
    paths = [
        element.attrib['d']
        for element in ET.fromstring(mono_svg).iter(f'{{{SVG}}}path')
    ]

    shutil.copyfile(sources['light'], REPO / 'assets/images/icon.png')
    sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    for path in ('assets/images/icon.ico', 'windows/runner/resources/app_icon.ico'):
        ico(light, path, sizes)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        png(light, f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png', size)

    app_icon = REPO / 'ios/Runner/AppIcon.icon'
    shutil.copyfile(sources['light'], app_icon / 'Assets/icon.png')
    (app_icon / 'Assets/icon.svg').unlink(missing_ok=True)
    composition = json.loads((app_icon / 'icon.json').read_text())
    layer = composition['groups'][0]['layers'][0]
    layer['image-name'] = 'icon.png'
    layer['position']['scale'] = 1
    composition['groups'][0]['shadow']['opacity'] = 0
    composition['groups'][0]['translucency']['enabled'] = False
    write('ios/Runner/AppIcon.icon/icon.json', json.dumps(composition, indent=2) + '\n')
    launch = 'ios/Runner/Assets.xcassets/LaunchLogo.imageset'
    for scale in (1, 2, 3):
        suffix = '' if scale == 1 else f'@{scale}x'
        png(light, f'{launch}/LaunchLogo{suffix}.png', 288 * scale)
        png(dark, f'{launch}/LaunchLogoDark{suffix}.png', 288 * scale)
    background = REPO / 'ios/Runner/Assets.xcassets/LaunchBackground.imageset'
    for name, image in [('background.png', light), ('darkbackground.png', dark)]:
        path = background / name
        with Image.open(path) as current:
            size = current.size
        Image.new('RGBA', size, image.getpixel((0, 0))).save(path, optimize=True)

    widget = REPO / 'ios/Widget/Assets.xcassets/AppLogo.imageset'
    shutil.copyfile(sources['symbol'], widget / 'AppLogo.png')
    (widget / 'AppLogo.svg').unlink(missing_ok=True)
    write('ios/Widget/Assets.xcassets/AppLogo.imageset/Contents.json', json.dumps({
        'images': [{'filename': 'AppLogo.png', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
    }, indent=2) + '\n')
    symbol_file = REPO / 'ios/Widget/Assets.xcassets/FlClash.symbolset/FlClash.svg'
    tree = ET.parse(symbol_file)
    for element in tree.getroot().iter(f'{{{SVG}}}path'):
        if 'monochrome' not in element.get('class', ''):
            continue
        if element.attrib['d'] == ''.join(paths):
            continue
        if not set(re.findall('[A-Za-z]', element.attrib['d'])) <= set('MLCZ'):
            raise ValueError('Unexpected SF Symbols path coordinates')
        numbers = [float(n) for n in re.findall(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?', element.attrib['d'])]
        xs, ys = numbers[::2], numbers[1::2]
        scale = min(max(xs) - min(xs), max(ys) - min(ys)) / 524
        x = (min(xs) + max(xs)) / 2 - 512 * scale
        y = (min(ys) + max(ys)) / 2 - 512 * scale
        element.set('d', ''.join(paths))
        element.set('transform', f'matrix({scale} 0 0 {scale} {x} {y})')
    ET.register_namespace('', SVG)
    tree.write(symbol_file, encoding='utf-8', xml_declaration=True)
    symbol_file.write_text(
        '\n'.join(line.rstrip() for line in symbol_file.read_text().splitlines()) + '\n',
        encoding='utf-8',
    )

    source_dir = 'assets_source/images/icon'
    write(f'{source_dir}/glyph.svg', mono_svg)
    gray, amber = '#7E8798', '#D59B56'
    badge = '<circle cx="805" cy="805" r="20" fill="#D59B56"/>'
    status = {
        'status_1': (tinted(images['black'], gray), mono_svg.replace('#000000', gray)),
        'status_2': (images['symbol'], color_svg),
        'status_3': (marker(images['symbol'], amber), color_svg.replace('</svg>', badge + '</svg>')),
        'status_4': (tinted(images['black'], amber), mono_svg.replace('#000000', amber)),
    }
    for name, (raster, svg) in status.items():
        for target in (source_dir, 'assets/images/tray/linux'):
            write(f'{target}/{name}.svg', svg)
        for scale in (1, 2, 3, 4):
            folder = '' if scale == 1 else f'/{scale}.0x'
            png(raster, f'assets/images/tray/unix{folder}/{name}.png', 18 * scale)
        ico(raster, f'assets/images/tray/windows/{name}.ico', [16, 20, 24, 32, 40, 48, 64])
    for name in ('status_1', 'status_4'):
        raster = images['black']
        for scale in (1, 2, 3, 4):
            folder = '' if scale == 1 else f'/{scale}.0x'
            png(raster, f'assets/images/tray/macos{folder}/{name}.png', 18 * scale)

    res = 'android/app/src/main/res'
    for name, image in [('zolnit_launcher', images['symbol']), ('zolnit_monochrome', images['black'])]:
        png(image, f'{res}/drawable-xxxhdpi/{name}.png', 280)
        (REPO / f'{res}/drawable-nodpi/{name}.png').unlink(missing_ok=True)
    png(images['symbol'], f'{res}/drawable-nodpi/zolnit_symbol.png', 1024)
    bitmap = f'<bitmap xmlns:android="{ANDROID}" android:src="@drawable/zolnit_launcher" android:gravity="fill"/>'
    foreground = (
        f'<inset xmlns:android="{ANDROID}" android:insetLeft="19dp" android:insetTop="19dp" '
        f'android:insetRight="19dp" android:insetBottom="19dp">{bitmap}</inset>\n'
    )
    for name in ('ic_launcher_foreground', 'ic_launcher_foreground_tv'):
        write(f'{res}/drawable/{name}.xml', foreground)
    write(f'{res}/drawable/ic_launcher_monochrome.xml', foreground.replace('zolnit_launcher', 'zolnit_monochrome'))
    for folder, name in (
        ('mipmap-anydpi-v26', 'ic_launcher'),
        ('mipmap-anydpi-v26', 'ic_launcher_round'),
        ('mipmap-television-anydpi-v26', 'ic_launcher'),
    ):
        path = REPO / f'{res}/{folder}/{name}.xml'
        adaptive = ET.parse(path)
        mono = adaptive.getroot().find('monochrome')
        if mono is None:
            mono = ET.SubElement(adaptive.getroot(), 'monochrome')
        mono.set(f'{{{ANDROID}}}drawable', '@drawable/ic_launcher_monochrome')
        ET.register_namespace('android', ANDROID)
        adaptive.write(path, encoding='utf-8', xml_declaration=True)
    write(f'{res}/drawable/ic_widget_logo.xml', bitmap.replace('zolnit_launcher', 'zolnit_symbol') + '\n')
    write(f'{res}/values/ic_launcher_background.xml', '<resources><color name="ic_launcher_background">#FFFFFF</color></resources>\n')
    for name in ('ic', 'ic_service'):
        write(f'android/service/src/main/res/drawable/{name}.xml', vector(paths, 240, 240))
    for density, size in zip(('mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'), (48, 72, 96, 144, 192)):
        for name in ('ic_launcher', 'ic_launcher_round'):
            light.resize((size, size), Image.Resampling.LANCZOS).save(
                REPO / f'{res}/mipmap-{density}/{name}.webp', lossless=True,
            )
        tv = round(size * 5 / 3)
        light.resize((tv, tv), Image.Resampling.LANCZOS).save(
            REPO / f'{res}/mipmap-television-{density}/ic_launcher.webp', lossless=True,
        )
    png(light, 'android/app/src/main/ic_launcher-playstore.png', 512)
    banner = Image.new('RGBA', (320, 180), light.getpixel((0, 0)))
    banner.alpha_composite(light.resize((180, 180), Image.Resampling.LANCZOS), (70, 0))
    banner.save(REPO / f'{res}/mipmap-xhdpi/ic_banner.png', optimize=True)
    print('Generated ZolNit native launcher, splash, widget, notification and tray resources for all five platforms.')


if __name__ == '__main__':
    main()
