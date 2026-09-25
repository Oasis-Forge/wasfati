import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:wasfati/services/web_import.dart';

bool _isJpeg(Uint8List b) => b.length > 2 && b[0] == 0xFF && b[1] == 0xD8;

void main() {
  group('resizeForImport (IMP-10): what leaves the device', () {
    test('a large photo comes out at most 1600 px on its long side, as a '
        'JPEG', () async {
      final big = img.encodePng(img.Image(width: 4000, height: 3000));
      final out = (await resizeForImport(big))!;
      expect(_isJpeg(out), isTrue);
      final back = img.decodeJpg(out)!;
      expect((back.width, back.height), (1600, 1200));
    });

    test('a tall page is limited by its height', () async {
      final tall = img.encodeJpg(img.Image(width: 1000, height: 3200));
      final back = img.decodeJpg((await resizeForImport(tall))!)!;
      expect((back.width, back.height), (500, 1600));
    });

    test('a small screenshot keeps its size, but is still a JPEG', () async {
      final small = img.encodePng(img.Image(width: 720, height: 1280));
      final out = (await resizeForImport(small))!;
      expect(_isJpeg(out), isTrue);
      final back = img.decodeJpg(out)!;
      expect((back.width, back.height), (720, 1280));
    });

    test('a sideways camera photo is turned upright, so the server reads '
        'the page the right way up', () async {
      final sideways = img.Image(width: 2000, height: 1000)
        ..exif.imageIfd.orientation = 6; // "rotate 90° to view"
      final back = img.decodeJpg(
        (await resizeForImport(img.encodeJpg(sideways)))!,
      )!;
      expect((back.width, back.height), (800, 1600));
      expect(back.exif.imageIfd.orientation ?? 1, 1);
    });

    test('JPEG quality 80 makes a smaller file than the recipe photo\'s 85 '
        '(REC-8)', () async {
      // Noise, so the quality setting actually changes the size.
      final noisy = img.Image(width: 800, height: 800);
      var seed = 7;
      for (final p in noisy) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        p
          ..r = seed & 0xff
          ..g = (seed >> 8) & 0xff
          ..b = (seed >> 16) & 0xff;
      }
      final source = img.encodePng(noisy);
      final forImport = (await resizeForImport(source))!;
      final forRecipe = (await resizeForRecipe(source))!;
      expect(forImport.length, lessThan(forRecipe.length));
    });

    test('something that is not an image gives null, not a crash', () async {
      expect(await resizeForImport(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('IMP-10, SRV-9: a photo leaves the device as pixels only', () {
    /// A camera photo that knows where it was taken and on which phone.
    Uint8List cameraPhoto(int width, int height) {
      final photo = img.Image(width: width, height: height);
      photo.exif.imageIfd.make = 'PhoneCo';
      photo.exif.imageIfd.model = 'Phone 9';
      photo.exif.gpsIfd.setGpsLocation(latitude: 51.5, longitude: -0.12);
      return img.encodeJpg(photo);
    }

    void expectNoLocationOrPhone(Uint8List out) {
      final exif = img.decodeJpgExif(out);
      expect(exif?.imageIfd.make, isNull);
      expect(exif?.imageIfd.model, isNull);
      expect(exif?.gpsIfd.hasGPSLatitude ?? false, isFalse);
      expect(exif?.gpsIfd.hasGPSLongitude ?? false, isFalse);
      expect(exif == null || exif.isEmpty, isTrue);
    }

    test('the test photo really carries a location and a phone make', () {
      final exif = img.decodeJpgExif(cameraPhoto(800, 600))!;
      expect(exif.imageIfd.make, 'PhoneCo');
      expect(exif.gpsIfd.gpsLatitude, closeTo(51.5, 0.01));
    });

    test('an import photo, resized or not, keeps no location, make or '
        'model', () async {
      expectNoLocationOrPhone(
        (await resizeForImport(cameraPhoto(3000, 2000)))!,
      );
      expectNoLocationOrPhone((await resizeForImport(cameraPhoto(800, 600)))!);
    });

    test(
      'nor does a recipe photo, which may be shared later (REC-8)',
      () async {
        expectNoLocationOrPhone(
          (await resizeForRecipe(cameraPhoto(3000, 2000)))!,
        );
        expectNoLocationOrPhone(
          (await resizeForRecipe(cameraPhoto(800, 600)))!,
        );
      },
    );
  });
}
