import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wasfati/models/recipe_translation.dart';
import 'package:wasfati/services/ai_import.dart';

// http.Response's plain String constructor defaults to Latin-1 for
// bodyBytes, which mangles Arabic — encode to UTF-8 bytes ourselves so the
// fakes behave like the real server (which always answers UTF-8 JSON).
http.Client jsonClient(int status, Object body) => MockClient(
  (request) async => http.Response.bytes(utf8.encode(jsonEncode(body)), status),
);

void main() {
  group('DeviceAiImportClient: the request (SRV-1)', () {
    test('sends install_id and url, never both url and text', () async {
      http.Request? sent;
      final client = DeviceAiImportClient(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'recipe': {
                'title': 'ت',
                'ingredient_groups': [],
                'step_groups': [],
              },
              'model': 'haiku',
              'prompt_version': '1',
              'cached': false,
            }),
            200,
          );
        }),
      );
      await client.import(installId: 'inst-1', url: 'https://tiktok.com/@a/1');
      final body = jsonDecode(sent!.body) as Map<String, Object?>;
      expect(body, {'install_id': 'inst-1', 'url': 'https://tiktok.com/@a/1'});
    });

    test('sends text, not url, for pasted text', () async {
      http.Request? sent;
      final client = DeviceAiImportClient(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'recipe': {
                'title': 'ت',
                'ingredient_groups': [],
                'step_groups': [],
              },
              'model': 'haiku',
              'prompt_version': '1',
              'cached': false,
            }),
            200,
          );
        }),
      );
      await client.import(installId: 'inst-1', text: 'شوربة عدس');
      final body = jsonDecode(sent!.body) as Map<String, Object?>;
      expect(body, {'install_id': 'inst-1', 'text': 'شوربة عدس'});
    });
  });

  test('a photo import sends install_id and base64 images, never a url or '
      'text (IMP-10)', () async {
    http.Request? sent;
    final client = DeviceAiImportClient(
      MockClient((request) async {
        sent = request;
        final answer = {
          'recipe': {'title': 'ت', 'ingredient_groups': [], 'step_groups': []},
          'model': 'haiku',
          'prompt_version': '1',
        };
        return http.Response.bytes(utf8.encode(jsonEncode(answer)), 200);
      }),
    );
    final page1 = Uint8List.fromList(const [0xFF, 0xD8, 1, 2]);
    final page2 = Uint8List.fromList(const [0xFF, 0xD8, 3, 4]);
    final result = await client.import(
      installId: 'inst-1',
      images: [page1, page2],
    );
    expect(result, isA<AiImportSuccess>());
    final body = jsonDecode(sent!.body) as Map<String, Object?>;
    // Plain base64 with no `data:` prefix, in the order picked, and no
    // url or text key at all (the contract makes them exclusive).
    expect(body, {
      'install_id': 'inst-1',
      'images': [base64Encode(page1), base64Encode(page2)],
    });
    expect(sent!.url.path, '/v1/import');
  });

  group('DeviceAiImportClient: success (SRV-1, IMP-6)', () {
    test('a realistic Arabic response round-trips to ImportedRecipe, still '
        'unparsed for the device\'s own parser (Decision 17)', () async {
      final client = DeviceAiImportClient(
        jsonClient(200, {
          'recipe': {
            'title': 'شوربة عدس',
            'servings': 4,
            'prep_minutes': 10,
            'cook_minutes': 30,
            'ingredient_groups': [
              {
                'name': null,
                'lines': [
                  {'original_text': '٢ كوب دقيق', 'note': null},
                  {'original_text': '١ كيلو دجاج', 'note': null},
                  {'original_text': 'ملح حسب الذوق', 'note': null},
                ],
              },
            ],
            'step_groups': [
              {
                'name': null,
                'steps': ['يُغسل العدس جيدًا.', 'يُطهى على نار هادئة.'],
              },
            ],
          },
          'model': 'claude-haiku-4-5',
          'prompt_version': 'v3',
          'cached': true,
        }),
      );
      final result = await client.import(installId: 'inst-1', text: 'x');
      final success = result as AiImportSuccess;
      expect(success.model, 'claude-haiku-4-5');
      expect(success.promptVersion, 'v3');
      expect(success.cached, isTrue);
      final r = success.recipe;
      expect(r.title, 'شوربة عدس');
      expect((r.servings, r.prepMinutes, r.cookMinutes), (4, 10, 30));
      // Still verbatim source text — no amount, unit or note read yet
      // (that is Importer.fromAi's job, through QTY-1).
      expect(r.ingredients.single.$2, [
        '٢ كوب دقيق',
        '١ كيلو دجاج',
        'ملح حسب الذوق',
      ]);
      expect(r.steps.single.$2, ['يُغسل العدس جيدًا.', 'يُطهى على نار هادئة.']);
    });

    test('named ingredient and step groups are kept', () async {
      final client = DeviceAiImportClient(
        jsonClient(200, {
          'recipe': {
            'title': 'كبسة',
            'ingredient_groups': [
              {
                'name': 'للدقوس',
                'lines': [
                  {'original_text': '2 حبة طماطم'},
                ],
              },
            ],
            'step_groups': [
              {
                'name': 'التحضير',
                'steps': ['يحمر اللحم.'],
              },
            ],
          },
          'model': 'm',
          'prompt_version': '1',
          'cached': false,
        }),
      );
      final result = await client.import(installId: 'i', text: 'x');
      final r = (result as AiImportSuccess).recipe;
      expect(r.ingredients.single.$1, 'للدقوس');
      expect(r.steps.single.$1, 'التحضير');
    });

    test('a step over 400 characters is split at sentence ends, losing no '
        'text (IMP-6, must-fix, review)', () async {
      // 25 sentences of 20 Arabic characters each (plus the separating
      // space), well past the 400-character threshold.
      final longStep = List.generate(
        25,
        (i) => 'يُطهى الطعام على نار هادئة جدا.',
      ).join(' ');
      final client = DeviceAiImportClient(
        jsonClient(200, {
          'recipe': {
            'title': 'ت',
            'ingredient_groups': [],
            'step_groups': [
              {
                'name': null,
                'steps': [longStep, 'خطوة قصيرة'],
              },
            ],
          },
          'model': 'm',
          'prompt_version': '1',
          'cached': false,
        }),
      );
      final result = await client.import(installId: 'i', text: 'x');
      final r = (result as AiImportSuccess).recipe;
      final steps = r.steps.single.$2;
      // The long step became several pieces, each well under the 2,000
      // character field limit that would otherwise silently truncate it
      // later; the short one passed through untouched.
      expect(steps.length, greaterThan(2));
      expect(steps.last, 'خطوة قصيرة');
      for (final s in steps.sublist(0, steps.length - 1)) {
        expect(s.length, lessThan(400));
      }
      // No text was lost: every Arabic letter of the original survives
      // somewhere (punctuation may be renormalized at a rejoin, IMP-6).
      String letters(String s) => s.replaceAll(RegExp('[^ء-ي]'), '');
      expect(
        letters(steps.sublist(0, steps.length - 1).join()),
        letters(longStep),
      );
    });

    test(
      'an empty line or step is dropped, an empty group is dropped',
      () async {
        final client = DeviceAiImportClient(
          jsonClient(200, {
            'recipe': {
              'title': 'ت',
              'ingredient_groups': [
                {
                  'name': null,
                  'lines': [
                    {'original_text': '  '},
                    {'original_text': '2 بصل'},
                  ],
                },
                {'name': 'فارغة', 'lines': <Object?>[]},
              ],
              'step_groups': [
                {
                  'name': null,
                  'steps': ['', 'خطوة واحدة'],
                },
              ],
            },
            'model': 'm',
            'prompt_version': '1',
            'cached': false,
          }),
        );
        final result = await client.import(installId: 'i', text: 'x');
        final r = (result as AiImportSuccess).recipe;
        expect(r.ingredients.single.$2, ['2 بصل']);
        expect(r.steps.single.$2, ['خطوة واحدة']);
      },
    );
  });

  group('DeviceAiImportClient: every server error maps to its own kind '
      '(SRV-7)', () {
    final cases = {
      (400, 'bad_request'): AiImportErrorKind.badRequest,
      (403, 'invalid_integrity_token'): AiImportErrorKind.invalidToken,
      (422, 'unreachable'): AiImportErrorKind.unreachable,
      (422, 'private_post'): AiImportErrorKind.privatePost,
      (422, 'not_a_recipe'): AiImportErrorKind.notARecipe,
      (429, 'limit_reached'): AiImportErrorKind.limitReached,
      (503, 'busy'): AiImportErrorKind.busy,
      (503, 'misconfigured'): AiImportErrorKind.misconfigured,
      (413, 'too_large'): AiImportErrorKind.tooLarge,
    };
    for (final MapEntry(key: (int, String) k, value: AiImportErrorKind kind)
        in cases.entries) {
      final (status, code) = k;
      test('$status $code -> $kind', () async {
        final client = DeviceAiImportClient(
          jsonClient(status, {'error': code, 'message': 'nope'}),
        );
        final result = await client.import(installId: 'i', text: 'x');
        expect(result, isA<AiImportError>());
        expect((result as AiImportError).kind, kind);
        expect(result.message, 'nope');
      });
    }

    test('an error code this build has never seen maps to unknown, not '
        'network (forward compatible)', () async {
      final client = DeviceAiImportClient(
        jsonClient(500, {'error': 'a_future_code', 'message': 'm'}),
      );
      final result = await client.import(installId: 'i', text: 'x');
      expect((result as AiImportError).kind, AiImportErrorKind.unknown);
    });
  });

  group('DeviceAiImportClient: never throws for a bad connection (SRV-7)', () {
    test('the client throwing (no connection) maps to network', () async {
      final client = DeviceAiImportClient(
        MockClient((_) => throw const SocketExceptionStub()),
      );
      final result = await client.import(installId: 'i', text: 'x');
      expect((result as AiImportError).kind, AiImportErrorKind.network);
    });

    test(
      'a non-JSON body (e.g. a gateway error page) maps to network',
      () async {
        final client = DeviceAiImportClient(
          MockClient((_) async => http.Response('<html>502</html>', 502)),
        );
        final result = await client.import(installId: 'i', text: 'x');
        expect((result as AiImportError).kind, AiImportErrorKind.network);
      },
    );

    test('a 413 with no JSON of its own (Cloudflare\'s) is still too large, '
        'not a dropped connection (IMP-10)', () async {
      final client = DeviceAiImportClient(
        MockClient((_) async => http.Response('<html>413</html>', 413)),
      );
      final result = await client.import(
        installId: 'i',
        images: [
          Uint8List.fromList(const [0xFF, 0xD8]),
        ],
      );
      expect((result as AiImportError).kind, AiImportErrorKind.tooLarge);
    });

    test('a 200 with no usable recipe shape maps to network', () async {
      final client = DeviceAiImportClient(
        jsonClient(200, {
          'recipe': {'servings': 4}, // no title
          'model': 'm',
          'prompt_version': '1',
          'cached': false,
        }),
      );
      final result = await client.import(installId: 'i', text: 'x');
      expect((result as AiImportError).kind, AiImportErrorKind.network);
    });
  });

  group('NoopAiImportClient: the test fake', () {
    test('records every request and replays nextResult', () async {
      final fake = NoopAiImportClient()
        ..nextResult = const AiImportError(AiImportErrorKind.limitReached);
      final result = await fake.import(installId: 'i', url: 'https://a.com');
      expect((result as AiImportError).kind, AiImportErrorKind.limitReached);
      expect(fake.requests.single.installId, 'i');
      expect(fake.requests.single.url, 'https://a.com');
      expect(fake.requests.single.text, isNull);
    });

    test('queue is consumed in order, then falls back to nextResult', () async {
      final fake = NoopAiImportClient()
        ..queue.add(const AiImportError(AiImportErrorKind.busy))
        ..nextResult = const AiImportError(AiImportErrorKind.network);
      expect(
        ((await fake.import(installId: 'i', text: 't')) as AiImportError).kind,
        AiImportErrorKind.busy,
      );
      expect(
        ((await fake.import(installId: 'i', text: 't')) as AiImportError).kind,
        AiImportErrorKind.network,
      );
    });
  });

  group('DeviceAiImportClient.translate (SRV-11, IMP-15)', () {
    const items = <TranslationItem>[
      (id: 't', text: 'Chicken kabsa'),
      (id: 'n0', text: 'basmati rice'),
      (id: 's0', text: 'Soak for 30 minutes.'),
    ];

    test('posts install_id, the target and the items to /v1/translate, and '
        'reads every item back exactly as sent', () async {
      http.Request? sent;
      final client = DeviceAiImportClient(
        MockClient((request) async {
          sent = request;
          final answer = {
            'items': [
              {'id': 't', 'text': 'كبسة دجاج'},
              {'id': 'n0', 'text': 'أرز بسمتي'},
              {'id': 's0', 'text': 'انقعيه 30 دقيقة.'},
              {'id': 's0', 'text': 'مكرر'}, // kept: the app checks, not this
            ],
            'model': 'haiku',
            'prompt_version': 't1',
          };
          return http.Response.bytes(utf8.encode(jsonEncode(answer)), 200);
        }),
      );
      final result = await client.translate(
        installId: 'inst-1',
        target: 'ar',
        items: items,
      );
      expect(sent!.url.toString(), '$aiImportServerUrl/v1/translate');
      expect(jsonDecode(sent!.body), {
        'install_id': 'inst-1',
        'target': 'ar',
        'items': [
          {'id': 't', 'text': 'Chicken kabsa'},
          {'id': 'n0', 'text': 'basmati rice'},
          {'id': 's0', 'text': 'Soak for 30 minutes.'},
        ],
      });
      final ok = result as AiTranslateSuccess;
      expect(ok.items.map((i) => (i.id, i.text)), [
        ('t', 'كبسة دجاج'),
        ('n0', 'أرز بسمتي'),
        ('s0', 'انقعيه 30 دقيقة.'),
        ('s0', 'مكرر'),
      ]);
      expect(ok.model, 'haiku');
      expect(ok.promptVersion, 't1');
    });

    final cases = {
      (502, 'bad_translation'): AiImportErrorKind.badTranslation,
      (413, 'too_large'): AiImportErrorKind.tooLarge,
      (400, 'bad_request'): AiImportErrorKind.badRequest,
      (429, 'limit_reached'): AiImportErrorKind.limitReached,
      (503, 'busy'): AiImportErrorKind.busy,
      (503, 'misconfigured'): AiImportErrorKind.misconfigured,
    };
    for (final MapEntry(key: (int, String) k, value: AiImportErrorKind kind)
        in cases.entries) {
      final (status, code) = k;
      test('$status $code -> $kind', () async {
        final client = DeviceAiImportClient(
          jsonClient(status, {'error': code, 'message': 'nope'}),
        );
        final result = await client.translate(
          installId: 'i',
          target: 'en',
          items: items,
        );
        expect((result as AiTranslateError).kind, kind);
        expect(result.message, 'nope');
      });
    }

    test("a 200 whose items can't be matched is an incomplete translation, "
        'never half used', () async {
      for (final bad in [
        {'items': 'nope'},
        {
          'items': [
            {'id': 't'}, // no text
          ],
        },
        {
          'items': [
            {'id': 1, 'text': 'x'},
          ],
        },
      ]) {
        final client = DeviceAiImportClient(jsonClient(200, bad));
        final result = await client.translate(
          installId: 'i',
          target: 'ar',
          items: items,
        );
        expect(
          (result as AiTranslateError).kind,
          AiImportErrorKind.badTranslation,
          reason: '$bad',
        );
      }
    });

    test("no connection is network; Cloudflare's own 413 page is still too "
        'large', () async {
      final offline = DeviceAiImportClient(
        MockClient((_) => throw const SocketExceptionStub()),
      );
      expect(
        ((await offline.translate(
          installId: 'i',
          target: 'ar',
          items: items,
        )) as AiTranslateError).kind,
        AiImportErrorKind.network,
      );
      final big = DeviceAiImportClient(
        MockClient((_) async => http.Response('<html>413</html>', 413)),
      );
      expect(
        ((await big.translate(
          installId: 'i',
          target: 'ar',
          items: items,
        )) as AiTranslateError).kind,
        AiImportErrorKind.tooLarge,
      );
    });

    test('the fake records every translate request and answers with its '
        'translator', () async {
      final fake = NoopAiImportClient()
        ..translator = (r) => AiTranslateSuccess(
          [for (final i in r.items) (id: i.id, text: '${i.text}!')],
          model: 'm',
          promptVersion: 'p',
        );
      final result = await fake.translate(
        installId: 'i',
        target: 'en',
        items: items,
      );
      expect((result as AiTranslateSuccess).items.first.text, 'Chicken kabsa!');
      expect(fake.translateRequests.single.target, 'en');
      expect(fake.requests, isEmpty);
    });
  });
}

/// A stand-in for a real `SocketException` without importing `dart:io` into
/// a test that otherwise never touches it.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
