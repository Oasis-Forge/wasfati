// REC-3, Decision 8: `sourceBadge`'s own label per source type/host branch
// (www-stripping, the three named social platforms, the generic social
// fallback, a website with no URL) and `sourceBadgeIcon`'s generic mark for
// each — plain unit tests, no widget tree needed.
import 'package:flutter/material.dart' show Icons, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/l10n/app_localizations.dart';
import 'package:wasfati/models/library.dart';
import 'package:wasfati/models/recipe.dart' show SourceType;
import 'package:wasfati/screens/library_view.dart';

LibraryEntry _entry({required SourceType source, String? url}) => LibraryEntry(
  id: 'r',
  title: 'وصفة',
  sourceType: source,
  sourceUrl: url,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('ar'));

  group('sourceBadge (REC-3, Decision 8)', () {
    test('written: the fixed label', () {
      expect(
        sourceBadge(l10n, _entry(source: SourceType.written)),
        l10n.sourceWritten,
      );
    });

    test('photo: the fixed label', () {
      expect(
        sourceBadge(l10n, _entry(source: SourceType.photo)),
        l10n.sourcePhoto,
      );
    });

    test('website: the host, with "www." stripped', () {
      expect(
        sourceBadge(
          l10n,
          _entry(
            source: SourceType.website,
            url: 'https://www.fatafeat.com/recipe/1632',
          ),
        ),
        'fatafeat.com',
      );
    });

    test('website with no "www." keeps the host as-is', () {
      expect(
        sourceBadge(
          l10n,
          _entry(source: SourceType.website, url: 'https://food.com/r/1'),
        ),
        'food.com',
      );
    });

    test('website with no URL: the generic label', () {
      expect(
        sourceBadge(l10n, _entry(source: SourceType.website)),
        l10n.sourceWebsite,
      );
    });

    test('social: tiktok.com', () {
      expect(
        sourceBadge(
          l10n,
          _entry(
            source: SourceType.social,
            url: 'https://www.tiktok.com/@a/video/1',
          ),
        ),
        l10n.sourceTiktok,
      );
    });

    test('social: instagram.com', () {
      expect(
        sourceBadge(
          l10n,
          _entry(
            source: SourceType.social,
            url: 'https://www.instagram.com/p/1',
          ),
        ),
        l10n.sourceInstagram,
      );
    });

    test('social: youtube.com', () {
      expect(
        sourceBadge(
          l10n,
          _entry(
            source: SourceType.social,
            url: 'https://www.youtube.com/watch?v=1',
          ),
        ),
        l10n.sourceYoutube,
      );
    });

    test('social: youtu.be', () {
      expect(
        sourceBadge(
          l10n,
          _entry(source: SourceType.social, url: 'https://youtu.be/abc'),
        ),
        l10n.sourceYoutube,
      );
    });

    test('social: an unrecognised host falls back to the generic label', () {
      expect(
        sourceBadge(
          l10n,
          _entry(source: SourceType.social, url: 'https://x.com/a/1'),
        ),
        l10n.sourceSocial,
      );
    });

    test('social with no URL: the generic label', () {
      expect(
        sourceBadge(l10n, _entry(source: SourceType.social)),
        l10n.sourceSocial,
      );
    });
  });

  group('sourceBadgeIcon (REC-3): a generic mark, never a platform logo', () {
    test('one icon per source type', () {
      expect(sourceBadgeIcon(SourceType.written), Icons.edit_outlined);
      expect(sourceBadgeIcon(SourceType.photo), Icons.photo_camera_outlined);
      expect(sourceBadgeIcon(SourceType.website), Icons.public);
      expect(sourceBadgeIcon(SourceType.social), Icons.play_circle_outline);
    });
  });
}
