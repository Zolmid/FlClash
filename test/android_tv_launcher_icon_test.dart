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

  test('TV adaptive launcher icon stays centered in the safe zone', () async {
    final adaptiveIcon = File(
      'android/app/src/main/res/'
      'mipmap-television-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(
      _androidAttribute(adaptiveIcon, 'foreground', 'drawable'),
      '@drawable/ic_launcher_foreground_tv',
    );
    expect(
      _androidAttribute(adaptiveIcon, 'background', 'drawable'),
      '@color/ic_launcher_background',
    );

    final foreground = File(
      'android/app/src/main/res/drawable/'
      'ic_launcher_foreground_tv.xml',
    ).readAsStringSync();
    final resource = _androidAttribute(foreground, 'bitmap', 'src');
    expect(resource, '@drawable/zolnit_launcher');
    expect(_androidAttribute(foreground, 'bitmap', 'gravity'), 'fill');
    final insets = [
      for (final side in ['Left', 'Top', 'Right', 'Bottom'])
        _androidDoubleAttribute(foreground, 'inset', 'inset$side'),
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

    final raster = File(
      'android/app/src/main/res/drawable-nodpi/${resource.split('/').last}.png',
    );
    final codec = await ui.instantiateImageCodec(await raster.readAsBytes());
    addTearDown(codec.dispose);
    final image = (await codec.getNextFrame()).image;
    addTearDown(image.dispose);
    expect((image.width, image.height), (1024, 1024));
    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    var left = image.width;
    var top = image.height;
    var right = 0;
    var bottom = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final offset = (y * image.width + x) * 4;
        final visible = [0, 1, 2].any(
          (channel) => (pixels[offset + channel] - pixels[channel]).abs() > 8,
        );
        if (!visible) continue;
        if (x < left) left = x;
        if (y < top) top = y;
        if (x + 1 > right) right = x + 1;
        if (y + 1 > bottom) bottom = y + 1;
      }
    }
    expect(right, greaterThan(left));
    expect(bottom, greaterThan(top));

    final transformedBounds = ui.Rect.fromLTRB(
      canvas.left + left / image.width * canvas.width,
      canvas.top + top / image.height * canvas.height,
      canvas.left + right / image.width * canvas.width,
      canvas.top + bottom / image.height * canvas.height,
    );
    const safeZone = ui.Rect.fromLTWH(18, 18, 72, 72);

    expect(transformedBounds.left, greaterThanOrEqualTo(safeZone.left));
    expect(transformedBounds.top, greaterThanOrEqualTo(safeZone.top));
    expect(transformedBounds.right, lessThanOrEqualTo(safeZone.right));
    expect(transformedBounds.bottom, lessThanOrEqualTo(safeZone.bottom));
  });
}
