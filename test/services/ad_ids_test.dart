// ADS-7, ADS-8: which ad IDs each build asks with, that every copy of them
// agrees, and that a request hands the SDK nothing from the app.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/services/google_ads.dart';

/// Google's published sample publisher: every test ID, and nothing else.
const googleTestPublisher = 'ca-app-pub-3940256099942544';

/// Ours (docs/RELEASING.md).
const ourPublisher = 'ca-app-pub-8287765177319119';

String read(String path) => File(path).readAsStringSync();

/// The value `manifestPlaceholders["admobAppId"]` gets inside the Gradle
/// block that starts at [block] (`defaultConfig {`, `release {`).
String? placeholderIn(String gradle, String block) {
  final start = gradle.indexOf(block);
  if (start < 0) return null;
  // Up to the block's own closing brace, counting nested ones.
  var depth = 0;
  var end = start;
  for (var i = gradle.indexOf('{', start); i < gradle.length; i++) {
    if (gradle[i] == '{') depth++;
    if (gradle[i] == '}' && --depth == 0) {
      end = i;
      break;
    }
  }
  return RegExp(r'manifestPlaceholders\["admobAppId"\]\s*=\s*"([^"]+)"')
      .firstMatch(gradle.substring(start, end))?[1];
}

void main() {
  group('ADS-8: test IDs everywhere but a release build', () {
    test('this (debug) build asks with Google test IDs on Android', () {
      expect(kReleaseMode, isFalse);
      expect(defaultTargetPlatform, TargetPlatform.android);
      expect(AdIds.current, AdIds.androidTest);
      expect(GoogleAdService().bannerUnit, AdIds.androidTest.bannerUnit);
      expect(GoogleAdService().bannerUnit, startsWith(googleTestPublisher));
    });

    test('a release build asks with ours, and only on Android', () {
      expect(AdIds.releaseFor(TargetPlatform.android), AdIds.androidRelease);
      // No iOS ad unit of our own until Phase 6: an iOS release asks for no
      // ads at all rather than Google's test ones.
      expect(AdIds.releaseFor(TargetPlatform.iOS), isNull);
      expect(AdIds.testFor(TargetPlatform.iOS), AdIds.iosTest);
    });

    test('test IDs are all Google\'s, and real ones all ours', () {
      for (final ids in [AdIds.androidTest, AdIds.iosTest]) {
        expect(ids.appId, startsWith('$googleTestPublisher~'));
        expect(ids.bannerUnit, startsWith('$googleTestPublisher/'));
      }
      expect(AdIds.androidRelease.appId, startsWith('$ourPublisher~'));
      expect(AdIds.androidRelease.bannerUnit, startsWith('$ourPublisher/'));
    });

    test('the real IDs are the ones docs/RELEASING.md records', () {
      final releasing = read('docs/RELEASING.md');
      expect(releasing, contains('`${AdIds.androidRelease.appId}`'));
      expect(releasing, contains('`${AdIds.androidRelease.bannerUnit}`'));
    });

    test('Gradle puts the real app ID in release only, the test one in '
        'debug and profile', () {
      final gradle = read('android/app/build.gradle.kts');
      expect(placeholderIn(gradle, 'defaultConfig {'), AdIds.androidTest.appId);
      expect(placeholderIn(gradle, 'release {'), AdIds.androidRelease.appId);
      // Nothing else sets it: debug and profile inherit defaultConfig's.
      expect(
        RegExp(r'manifestPlaceholders\["admobAppId"\]').allMatches(gradle),
        hasLength(2),
      );
      expect(ourPublisher.allMatches(gradle), hasLength(1));
    });

    test('the manifest takes the app ID from Gradle, never a literal', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest,
        matches(
          RegExp(
            r'android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"'
            r'\s*android:value="\$\{admobAppId\}"',
          ),
        ),
      );
      for (final path in [
        'android/app/src/main/AndroidManifest.xml',
        'android/app/src/debug/AndroidManifest.xml',
        'android/app/src/profile/AndroidManifest.xml',
      ]) {
        expect(read(path), isNot(contains('ca-app-pub-')), reason: path);
      }
    });

    test('iOS carries Google\'s test app ID until Phase 6', () {
      final plist = read('ios/Runner/Info.plist');
      expect(
        plist,
        matches(
          RegExp(
            '<key>GADApplicationIdentifier</key>\\s*'
            '<string>${RegExp.escape(AdIds.iosTest.appId)}</string>',
          ),
        ),
      );
    });

    test('lib/ has one copy of the IDs: lib/services/ads.dart', () {
      final holders = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              f.readAsStringSync().contains('ca-app-pub-'))
            f.path.replaceAll(r'\', '/'),
      ];
      expect(holders, ['lib/services/ads.dart']);
    });

    test('the release workflow checks the built APK for both', () {
      final workflow = read('.github/workflows/release.yml');
      expect(workflow, contains(AdIds.androidRelease.appId));
      expect(workflow, contains(AdIds.androidRelease.bannerUnit));
      expect(workflow, contains(googleTestPublisher));
    });
  });

  test('ADS-7: a banner request hands the SDK nothing from the app', () {
    const r = GoogleAdService.request;
    expect(r.keywords, isNull);
    expect(r.contentUrl, isNull);
    expect(r.neighboringContentUrls, isNull);
    expect(r.extras, isNull);
    expect(r.mediationExtras, isNull);
    // Personalisation follows the consent form's answer (ADS-5), never a
    // flag the app sets.
    expect(r.nonPersonalizedAds, isNull);
  });
}
