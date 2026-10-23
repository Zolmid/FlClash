import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String _androidAttribute(String source, String element, String attribute) {
  final elementTag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return RegExp(
    'android:$attribute="([^"]+)"',
  ).firstMatch(elementTag)!.group(1)!;
}

double _androidDoubleAttribute(
  String source,
  String element,
  String attribute,
) {
  return double.parse(
    _androidAttribute(
      source,
      element,
      attribute,
    ).replaceFirst(RegExp(r'dp$'), ''),
  );
}

Future<void> _expectLayer(String name, {required bool monochrome}) async {
  final layer = File(
    'android/app/src/main/res/drawable/$name.xml',
  ).readAsStringSync();
  final resource = _androidAttribute(layer, 'bitmap', 'src');
  expect(
    resource,
    monochrome ? '@drawable/zolnit_monochrome' : '@drawable/zolnit_launcher',
  );
  expect(_androidAttribute(layer, 'bitmap', 'gravity'), 'fill');
  final insets = [
    for (final side in ['Left', 'Top', 'Right', 'Bottom'])
      _androidDoubleAttribute(layer, 'inset', 'inset$side'),
  ];
  final canvas = ui.Rect.fromLTRB(
    insets[0],
    insets[1],
    108 - insets[2],
    108 - insets[3],
  );
  expect(canvas.center.dx, closeTo(54, 0.05));
  expect(canvas.center.dy, closeTo(54, 0.05));
  expect(canvas.width, closeTo(canvas.height, 0.05));
  final basename = resource.split('/').last;
  final raster = File(
    'android/app/src/main/res/drawable-xxxhdpi/$basename.png',
  );
  final codec = await ui.instantiateImageCodec(await raster.readAsBytes());
  addTearDown(codec.dispose);
  final image = (await codec.getNextFrame()).image;
  addTearDown(image.dispose);
  expect((image.width, image.height), (280, 280));
  expect(image.width / 4 + insets[0] + insets[2], closeTo(108, 0.05));
  expect(image.height / 4 + insets[1] + insets[3], closeTo(108, 0.05));
  final pixels = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  var left = image.width;
  var top = image.height;
  var right = 0;
  var bottom = 0;
  var transparent = 0;
  var opaque = 0;
  var colored = false;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final offset = (y * image.width + x) * 4;
      final alpha = pixels[offset + 3];
      if (alpha == 0) {
        transparent++;
        continue;
      }
      if (alpha == 255) opaque++;
      if (pixels[offset] != pixels[offset + 1] ||
          pixels[offset + 1] != pixels[offset + 2]) {
        colored = true;
      }
      if (x < left) left = x;
      if (y < top) top = y;
      if (x + 1 > right) right = x + 1;
      if (y + 1 > bottom) bottom = y + 1;
    }
  }
  expect(
    transparent,
    greaterThan(0),
    reason: '$resource needs transparent Alpha',
  );
  expect(right, greaterThan(left));
  expect(bottom, greaterThan(top));
  expect(colored, !monochrome);
  if (monochrome) expect(opaque, greaterThan(0));
  for (final corner in [
    0,
    image.width - 1,
    image.width * (image.height - 1),
    image.width * image.height - 1,
  ]) {
    expect(pixels[corner * 4 + 3], 0);
  }
  final bounds = ui.Rect.fromLTRB(
    canvas.left + left / image.width * canvas.width,
    canvas.top + top / image.height * canvas.height,
    canvas.left + right / image.width * canvas.width,
    canvas.top + bottom / image.height * canvas.height,
  );
  const safeZone = ui.Rect.fromLTWH(21, 21, 66, 66);
  expect(bounds.left, greaterThanOrEqualTo(safeZone.left));
  expect(bounds.top, greaterThanOrEqualTo(safeZone.top));
  expect(bounds.right, lessThanOrEqualTo(safeZone.right));
  expect(bounds.bottom, lessThanOrEqualTo(safeZone.bottom));
  expect(bounds.width, greaterThanOrEqualTo(48));
  expect(bounds.height, greaterThanOrEqualTo(48));
  if (monochrome) {
    expect(bounds.center.dx, closeTo(safeZone.center.dx, 0.05));
    expect(bounds.center.dy, closeTo(safeZone.center.dy, 0.05));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV launcher icons meet density-specific minimum sizes', () async {
    const expectedSizes = {
      'mdpi': 80,
      'hdpi': 120,
      'xhdpi': 160,
      'xxhdpi': 240,
      'xxxhdpi': 320,
    };

    for (final MapEntry(key: density, value: size) in expectedSizes.entries) {
      final file = File(
        'android/app/src/main/res/'
        'mipmap-television-$density/ic_launcher.webp',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(
        (frame.image.width, frame.image.height),
        (size, size),
        reason: file.path,
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  for (final (label, path, foreground) in [
    (
      'TV',
      'mipmap-television-anydpi-v26/ic_launcher.xml',
      'ic_launcher_foreground_tv',
    ),
    ('Phone', 'mipmap-anydpi-v26/ic_launcher.xml', 'ic_launcher_foreground'),
    (
      'Round',
      'mipmap-anydpi-v26/ic_launcher_round.xml',
      'ic_launcher_foreground',
    ),
  ]) {
    test(
      '$label adaptive launcher icon stays centered in the safe zone',
      () async {
        final adaptive = File(
          'android/app/src/main/res/$path',
        ).readAsStringSync();
        expect(
          _androidAttribute(adaptive, 'foreground', 'drawable'),
          '@drawable/$foreground',
        );
        expect(
          _androidAttribute(adaptive, 'background', 'drawable'),
          '@color/ic_launcher_background',
        );
        expect(
          _androidAttribute(adaptive, 'monochrome', 'drawable'),
          '@drawable/ic_launcher_monochrome',
        );
        await _expectLayer(foreground, monochrome: false);
        await _expectLayer('ic_launcher_monochrome', monochrome: true);
      },
    );
  }
}
