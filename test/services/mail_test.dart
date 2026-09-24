import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/services/mail.dart';

void main() {
  test('the only address the app writes to is the support one (CLAUDE.md)', () {
    expect(supportEmail, 'oasisforge.support@gmail.com');
  });

  group('mistakeReportBody (IMP-8, Decision 19): the link and the note, '
      'nothing else', () {
    test('a link import: the link, a blank line, then the note', () {
      expect(
        mistakeReportBody(
          sourceUrl: 'https://tiktok.com/@a/video/1',
          note: '  الكمية خاطئة\n',
        ),
        'https://tiktok.com/@a/video/1\n\nالكمية خاطئة',
      );
    });

    test('a photo or pasted-text import has no link: just the note', () {
      expect(
        mistakeReportBody(note: 'الخطوة الثالثة ناقصة'),
        'الخطوة الثالثة ناقصة',
      );
    });

    test('no note: just the link', () {
      expect(
        mistakeReportBody(sourceUrl: 'https://site.com/kabsa', note: '   '),
        'https://site.com/kabsa',
      );
    });

    test('a photo import with no note sends an empty body', () {
      expect(mistakeReportBody(), '');
    });
  });

  test('NoopMailComposer records each draft and answers as told', () async {
    final mail = NoopMailComposer(opens: false);
    final opened = await mail.compose(to: 'a', subject: 's', body: 'b');
    expect(opened, isFalse);
    expect(mail.drafts.single, (to: 'a', subject: 's', body: 'b'));
  });
}
