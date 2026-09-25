import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/app.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/library.dart';
import 'package:wasfati/models/ramadan.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_import.dart' show ImportedRecipe;
import 'package:wasfati/models/recipe_translation.dart' show TranslationItem;
import 'package:wasfati/models/recipe_share.dart' show wasfatiPlayStoreUrl;
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/db/grocery_repository.dart';
import 'package:wasfati/db/plan_repository.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/providers/ads_state.dart';
import 'package:wasfati/providers/backup_state.dart';
import 'package:wasfati/providers/grocery_state.dart';
import 'package:wasfati/providers/plan_state.dart';
import 'package:wasfati/providers/purchases_state.dart';
import 'package:wasfati/providers/recipes_state.dart';
import 'package:wasfati/providers/review_prompt_state.dart';
import 'package:wasfati/providers/settings_state.dart';
import 'package:wasfati/providers/timers_state.dart';

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/services/ai_import.dart';
import 'package:wasfati/services/backup.dart';
import 'package:wasfati/services/backup_files.dart';
import 'package:wasfati/services/cook_services.dart';
import 'package:wasfati/services/importer.dart';
import 'package:wasfati/services/import_photos.dart';
import 'package:wasfati/services/mail.dart';
import 'package:wasfati/services/photo_store.dart';
import 'package:wasfati/services/recipe_pages.dart';
import 'package:wasfati/services/sharer.dart';
import 'package:wasfati/services/store.dart';
import 'package:wasfati/services/store_review.dart';
import 'package:wasfati/services/web_import.dart';

import '../services/importer_test.dart' show FakeFetcher, kabsaPage;

import '../helpers.dart';

/// Lets database work (ffi, real async) finish, then settles the UI.
Future<void> settle(WidgetTester tester) async {
  // Pumps frames instead of pumpAndSettle (a loading spinner never
  // settles), until nothing is loading and no route is moving.
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (i > 3 &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame) {
      break;
    }
  }
  await tester.pump(const Duration(seconds: 1)); // route transitions
}

/// The timers and their fake alerts from the last [pumpApp].
late TimersState timers;
late NoopTimerAlerts alerts;

/// The meal plan from the last [pumpApp] (PLAN-1).
late PlanState plan;

/// The clock behind [plan] and the recipe repository, so a test can move
/// "today" (DATE-1) without restarting the app.
late FakeClock clock;

/// The grocery list from the last [pumpApp] (GRO-1).
late GroceryState groceries;

/// What the last [pumpApp] shared (GRO-6, SHARE-1–SHARE-4).
late NoopSharer sharer;

/// Where the last [pumpApp] would render share images (SHARE-3): a temp
/// directory the test owns, deleted again when the test ends.
late FakeShareStorage shareStorage;

/// Shares sent into the app during a test (IMP-1).
late StreamController<String> shares;

/// The backup engine (BAK-1–BAK-10) from the last [pumpApp], over the same
/// database, clock and IDs as [plan] and [groceries].
late BackupService backup;

/// The save/open dialogs the last [pumpApp] would use (BAK-6, BAK-7,
/// BAK-10): records every save, and returns [NoopBackupFiles.nextOpen] for
/// the next "open".
late NoopBackupFiles backupFiles;

/// The backup/restore/export flow state (BAK-1–BAK-10) from the last
/// [pumpApp], over [backup], [backupFiles] (or a test's own override),
/// [sharer] and [shareStorage].
late BackupState backupState;

/// The mail drafts the last [pumpApp] opened (IMP-8, Decision 19).
late NoopMailComposer mail;

/// The camera and photo picker of the last [pumpApp] (IMP-1, IMP-10): set
/// its `next` before tapping a photo button.
late NoopImportPhotoPicker importPhotos;

/// The store of the last [pumpApp] (PAY-1–PAY-11): sells and owns nothing
/// unless the test passed its own.
late NoopPurchaseStore store;

/// Pro and Premium from the last [pumpApp], over [store].
late PurchasesState purchases;

/// The ad network of the last [pumpApp]: no consent, so no banner, unless
/// the test passed its own (ADS-1–ADS-9).
late NoopAdService adService;

/// The banner slots' state from the last [pumpApp].
late AdsState ads;

/// The recipe photo store of the last [pumpApp]: records deletes (REC-8).
late RecordingPhotoStore photoStore;

/// The store's review prompt of the last [pumpApp] (RUN-5): counts every
/// time the store was asked.
late NoopStoreReview storeReview;

/// RUN-5's decision over [storeReview], from the last [pumpApp].
late ReviewPrompt reviewPrompt;

/// Like [NoopPhotoStore], but records every photo it was asked to delete,
/// so a test can see a removed or discarded import photo go (IMP-10), and
/// every copy it made — each one a new path, `<path>.copy-<recipeId>`, so
/// a test can tell a translated copy's photo from the original's (IMP-14).
class RecordingPhotoStore implements PhotoStore {
  final deleted = <String>[];
  final copies = <String>[];

  @override
  Future<String?> pickFromGallery(String recipeId) async => null;
  @override
  Future<void> delete(String path) async => deleted.add(path);
  @override
  Future<String?> copy(String path, String recipeId) async {
    final copy = '$path.copy-$recipeId';
    copies.add(copy);
    return copy;
  }

  @override
  Future<bool> exists(String path) async => true;
}

class FakeShareInbox implements ShareInbox {
  FakeShareInbox(this.stream);
  final Stream<String> stream;
  int resets = 0;
  @override
  Future<String?> initial() async => null;
  @override
  Stream<String> get incoming => stream;
  @override
  Future<void> reset() async => resets++;
}

/// An AI client whose response is held open until [complete] is called, so
/// a test can inspect the screen while a request is still in flight (IMP-3,
/// IMP-4) — [NoopAiImportClient] resolves too fast to observe that state.
class _ControlledAiImportClient implements AiImportClient {
  final _completer = Completer<AiImportResult>();
  final requests = <AiImportRequest>[];

  @override
  Future<AiImportResult> import({
    required String installId,
    String? url,
    String? text,
    List<Uint8List>? images,
  }) {
    requests.add((installId: installId, url: url, text: text, images: images));
    return _completer.future;
  }

  void complete(AiImportResult result) => _completer.complete(result);

  @override
  Future<AiTranslateResult> translate({
    required String installId,
    required String target,
    required List<TranslationItem> items,
  }) async => const AiTranslateError(AiImportErrorKind.network);
}

Future<(RecipesState, SettingsState)> pumpApp(
  WidgetTester tester, {
  LanguagePref language = LanguagePref.ar,
  DigitStyle digits = DigitStyle.western,
  double textScale = 1,
  bool withRecipe = false,
  bool ramadanMode = false,
  // A Ramadan positioned relative to the FakeClock date, so Ramadan mode's
  // tests don't depend on the real, built-in calendar's dates (RAM-2).
  List<RamadanMonth>? ramadanMonths,
  // A test that needs a [BackupFiles] or [Sharer] that fails on purpose
  // (must-fix, platform review: save/share/export used to have no error
  // path at all) passes one here instead of the usual no-op fake. The
  // global [backupFiles]/[sharer] stay the plain fakes either way, so
  // every other test's `backupFiles.saved`/`sharer.texts` keeps working.
  BackupFiles? backupFilesOverride,
  Sharer? sharerOverride,
  AiImportClient? aiClient,
  // IMP-10: where an imported photo lands. The default saves nothing, so a
  // draft has no photo unless a test asks for one.
  Future<String?> Function(String id, Uint8List bytes)? savePhoto,
  // More made-up recipe pages for website import (IMP-2), beside the kabsa.
  Map<String, String> pages = const {},
  // PAY-1–PAY-11 and ADS-1–ADS-9: a store and an ad network a test drives.
  // The defaults sell and own nothing, and never show a banner.
  NoopPurchaseStore? storeOverride,
  NoopAdService? adServiceOverride,
  // RUN-3, RUN-4: every other test starts past the first run, in the
  // library. A first-run test passes false.
  bool firstRunComplete = true,
  // RUN-4: an existing database (an upgraded install, or a fresh one). Its
  // stored settings load as they are, with the test's device locales, the
  // way `main.dart` loads them, instead of the ones above.
  Database? existingDb,
  // RUN-4: the device's reduce-motion setting.
  bool disableAnimations = false,
}) async {
  late RecipesState recipes;
  late SettingsState settings;
  late Importer importer;
  late CountingIds ids;
  late RecipeRepository repository;
  photoStore = RecordingPhotoStore();
  await tester.runAsync(() async {
    final (repo, fakeClock, idSource) = existingDb == null
        ? await testRepo()
        : _repoOn(existingDb);
    repository = repo;
    ids = idSource;
    clock = fakeClock;
    plan = PlanState(
      PlanRepository(repo.db, clock: clock.call, ids: ids.call),
      ramadanMonths: ramadanMonths ?? ramadanTable,
    );
    groceries = GroceryState(
      GroceryRepository(repo.db, clock: clock.call, ids: ids.call),
    );
    await groceries.load();
    settings = SettingsState(repo.db);
    if (existingDb != null) {
      await settings.load(deviceLocales: tester.platformDispatcher.locales);
    } else {
      await settings.update(
        AppSettings(
          language: language,
          digits: digits,
          ramadanMode: ramadanMode,
          firstRunComplete: firstRunComplete,
        ),
      );
    }
    recipes = RecipesState(repo);
    importer = Importer(
      FakeFetcher({'https://site.com/kabsa': kabsaPage, ...pages}),
      repo,
      savePhoto: savePhoto ?? (_, _) async => null,
      aiClient: aiClient,
      photos: photoStore,
    );
    if (withRecipe) await recipes.save(kabsa(repo));
    await recipes.load();
  });
  alerts = NoopTimerAlerts();
  shares = StreamController<String>();
  addTearDown(shares.close);
  timers = TimersState(alerts, autoTick: false);
  addTearDown(timers.dispose);
  sharer = NoopSharer();
  final shareDir = Directory.systemTemp.createTempSync('wasfati_share_test');
  addTearDown(() {
    if (shareDir.existsSync()) shareDir.deleteSync(recursive: true);
  });
  shareStorage = FakeShareStorage(shareDir);
  final backupRoot = Directory.systemTemp.createTempSync('wasfati_backup_test');
  addTearDown(() {
    if (backupRoot.existsSync()) backupRoot.deleteSync(recursive: true);
  });
  backup = BackupService(
    repository.db,
    factory: databaseFactoryFfi,
    photosDir: Directory(p.join(backupRoot.path, 'photos')),
    backupsDir: Directory(p.join(backupRoot.path, 'backups')),
    appVersion: 'test',
    clock: clock.call,
    ids: ids.call,
  );
  backupFiles = NoopBackupFiles();
  mail = NoopMailComposer();
  importPhotos = NoopImportPhotoPicker();
  storeReview = NoopStoreReview();
  reviewPrompt = ReviewPrompt(
    store: storeReview,
    settings: settings,
    recipes: recipes,
    clock: clock.call,
  );
  backupState = BackupState(
    backup: backup,
    files: backupFilesOverride ?? backupFiles,
    sharer: sharerOverride ?? sharer,
    shareStorage: shareStorage,
    settings: settings,
  );
  store = storeOverride ?? NoopPurchaseStore();
  adService = adServiceOverride ?? NoopAdService();
  purchases = PurchasesState(store);
  addTearDown(purchases.dispose);
  ads = AdsState(adService, purchases);
  addTearDown(ads.dispose);
  await tester.runAsync(purchases.start);
  tester.view.physicalSize = const Size(1080, 2400); // a phone (LANG-6)
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: WasfatiApp(
        recipes: recipes,
        plan: plan,
        groceries: groceries,
        settings: settings,
        timers: timers,
        importer: importer,
        shareInbox: FakeShareInbox(shares.stream),
        sharer: sharerOverride ?? sharer,
        shareStorage: shareStorage,
        backup: backup,
        backupFiles: backupFilesOverride ?? backupFiles,
        backupState: backupState,
        mail: mail,
        importPhotos: importPhotos,
        photos: photoStore,
        purchases: purchases,
        ads: ads,
        reviewPrompt: reviewPrompt,
      ),
    ),
  );
  // Not pumpAndSettle: the plan's loading spinner never settles.
  await settle(tester);
  return (recipes, settings);
}

(RecipeRepository, FakeClock, CountingIds) _repoOn(Database db) {
  final clock = FakeClock();
  final ids = CountingIds();
  return (RecipeRepository(db, clock: clock.call, ids: ids.call), clock, ids);
}

final _isolates = RegExp(
  '[${String.fromCharCode(0x2066)}-${String.fromCharCode(0x2069)}]',
);

/// Text as the user reads it: without the invisible left-to-right isolates
/// that wrap amounts inside Arabic lines (QTY-5). Matches a plain `Text`
/// (`.data`) or `AmountLine`'s `Text.rich` (LOOK-4: it colours the amount
/// span in a separate `TextSpan`, so `.data` is null there — `.toPlainText`
/// flattens the spans back to the same string `formatLine` produced).
Finder shown(String text) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final raw = w.data ?? w.textSpan?.toPlainText() ?? '';
  return raw.replaceAll(_isolates, '').contains(text);
});

TextDirection dirOf(WidgetTester tester, Finder f) =>
    Directionality.of(tester.element(f.first));

void main() {
  testWidgets('Arabic: right to left, empty state (LANG-5, RUN-1)', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('وصفاتي'), findsOneWidget);
    expect(find.text('لا توجد وصفات بعد'), findsOneWidget);
    expect(dirOf(tester, find.text('وصفاتي')), TextDirection.rtl);
  });

  testWidgets('English: left to right', (tester) async {
    await pumpApp(tester, language: LanguagePref.en);
    expect(find.text('No recipes yet'), findsOneWidget);
    expect(dirOf(tester, find.text('Wasfati')), TextDirection.ltr);
  });

  testWidgets('add a recipe: groups, parsed lines, numbered steps', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('أضف وصفة'));
    await settle(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'كبسة دجاج');
    await tester.enterText(fields.at(1), '4');
    await tester.enterText(
      fields.at(4),
      '١ ك دجاج\nكوبين ارز\n\nللدقوس:\n2 حبة طماطم',
    );
    await tester.enterText(fields.at(5), '1. يحمر الدجاج\n2. يضاف الأرز');
    await tester.tap(find.text('حفظ'));
    await settle(tester);

    // The recipe page.
    expect(find.text('كبسة دجاج'), findsOneWidget);
    expect(find.text('4 حصص'), findsOneWidget); // REC-7, Arabic plural
    expect(find.text('للدقوس'), findsOneWidget); // REC-4 group heading
    expect(shown('1 كيلو دجاج'), findsOneWidget); // "١ ك" → 1 kg
    expect(shown('2 كوبان ارز'), findsOneWidget); // dual → 2 cups
    expect(find.text('يحمر الدجاج'), findsOneWidget); // numbering removed
    expect(find.text('2'), findsWidgets); // step 2's number

    await tester.binding.handlePopRoute(); // system Back
    await settle(tester);
    expect(find.text('كبسة دجاج'), findsOneWidget); // in the list
  });

  testWidgets('each line reads in its own direction (LANG-5, QTY-5)', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester);
    await tester.runAsync(() async {
      final repo = recipes.repository;
      final now = repo.now();
      await recipes.save(
        Recipe(
          id: repo.newId(),
          title: 'Mixed',
          ingredients: [
            Section(
              id: repo.newId(),
              items: [
                IngredientLine.parse(repo.newId(), '1 kg chicken'),
                IngredientLine.parse(repo.newId(), '٣ كوب رز'),
              ],
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    await settle(tester);
    await tester.tap(find.text('Mixed'));
    await settle(tester);

    Text line(String part) => tester.widget<Text>(shown(part).last);
    // The competitor bug seen on the emulator: "kg chicken 1". An English
    // line in the Arabic app reads left to right, amount first.
    expect(line('kg chicken').textDirection, TextDirection.ltr);
    expect(line('3 أكواب رز').textDirection, TextDirection.rtl); // QTY-6
    // Both line up with the app's reading edge (right, in Arabic).
    expect(line('kg chicken').textAlign, TextAlign.right);
  });

  testWidgets('search finds a recipe by ingredient and says so (ORG-3)', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.enterText(find.byType(SearchBar), 'طماطم');
    await settle(tester);
    expect(find.text('كبسة لحم'), findsOneWidget);
    expect(find.textContaining('يحتوي: طماطم'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'بيتزا');
    await settle(tester);
    expect(find.text('لا توجد وصفات مطابقة'), findsOneWidget);
    await tester.tap(find.text('مسح عوامل التصفية'));
    await settle(tester);
    expect(find.text('كبسة لحم'), findsOneWidget);
  });

  testWidgets(
    'a recipe drops off the "بصورة" filter once its photo file is found '
    'missing and the sweep runs (ORG-6, BAK-9, test-coverage gap)',
    (tester) async {
      final (recipes, _) = await pumpApp(tester);
      const photoPath = '/p/gone-after-device-restore.jpg';
      // Both real database calls: saving needs tester.runAsync itself
      // (helpers.dart's own convention), and so does the sweep+reload pair
      // below — this repo's real (non-fake-timer) I/O never resolves
      // inside the test's fake-clock zone otherwise.
      await tester.runAsync(() async {
        final repo = recipes.repository;
        await recipes.save(kabsa(repo).copyWith(photoPath: photoPath));
      });
      await settle(tester);

      // The photo chip sits last in the filter bar's own horizontal list,
      // past the sort/cookbook/tag/source/time ones, so it needs scrolling
      // into view first (dragging positive-x brings later chips into view
      // here, under Arabic's right-to-left layout), then ensureVisible so
      // the tap's hit test lands on it rather than the row's own clip edge.
      final photoChip = find.widgetWithText(FilterChip, 'بصورة');
      final filterBar = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      );
      for (var i = 0; i < 20 && photoChip.evaluate().isEmpty; i++) {
        await tester.drag(filterBar, const Offset(200, 0));
        await tester.pump();
      }
      await tester.ensureVisible(photoChip);
      await tester.pump();
      await tester.tap(photoChip);
      await settle(tester);
      expect(shown('كبسة لحم'), findsOneWidget); // it does have a photo

      // ORG-6, BAK-9: the sweep (run from main.dart at every app start,
      // which no test reaches) clears a photo_path whose file didn't
      // survive a device backup restore — this recipe's own is deleted out
      // from under it here to stand in for that.
      await tester.runAsync(() async {
        await recipes.repository.forgetMissingPhotos(
          const NoopPhotoStore(missing: {photoPath}),
        );
        await recipes.load();
      });
      await settle(tester);
      expect(shown('كبسة لحم'), findsNothing); // no longer "بصورة"

      await tester.tap(photoChip); // clear the filter
      await settle(tester);
      expect(shown('كبسة لحم'), findsOneWidget); // the recipe itself is fine
    },
  );

  testWidgets('create a cookbook and put a recipe in it (ORG-1)', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كتب الطبخ'));
    await settle(tester);
    await tester.tap(find.text('كتاب طبخ جديد'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField), 'رمضان');
    await tester.tap(find.text('إنشاء'));
    await settle(tester);
    expect(find.text('رمضان'), findsOneWidget);
    expect(find.text('لا وصفات'), findsOneWidget);

    // Put the recipe in it from the editor.
    await tester.tap(find.text('كل الوصفات'));
    await settle(tester);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.byTooltip('تعديل'));
    await settle(tester);
    await tester.scrollUntilVisible(
      scrollable: find.byType(Scrollable).first, // the form, not a text box
      find.widgetWithText(FilterChip, 'رمضان'),
      200,
    );
    await tester.tap(find.widgetWithText(FilterChip, 'رمضان'));
    await tester.pump();
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(find.widgetWithText(Chip, 'رمضان'), findsOneWidget); // on the page

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('كتب الطبخ'));
    await settle(tester);
    expect(find.text('وصفة واحدة'), findsOneWidget);
  });

  testWidgets('sort and grid view are remembered (ORG-5)', (tester) async {
    final (_, settings) = await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('الأحدث إضافة'));
    await settle(tester);
    await tester.tap(find.text('أ–ي'));
    await settle(tester);
    expect(settings.settings.sort, LibrarySort.az);

    await tester.tap(find.byTooltip('عرض شبكي'));
    await settle(tester);
    expect(settings.settings.grid, isTrue);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('scale ×2 and by servings; to-taste marked (SCALE-2–4)', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    expect(find.text('6 حصص'), findsWidgets);

    await tester.tap(find.text('×2'));
    await settle(tester);
    // "×" stays before the number in right-to-left (seen as "2×" on the
    // emulator before this was fixed).
    expect(
      tester.widget<Text>(find.text('×2')).textDirection,
      TextDirection.ltr,
    );
    expect(find.text('12 حصة'), findsOneWidget); // the stepper shows servings
    expect(shown('2 كيلو لحم ضأن'), findsOneWidget);
    expect(shown('6 أكواب ارز بسمتي'), findsOneWidget); // Eastern digits scaled
    expect(find.text('لم يُعدَّل'), findsOneWidget); // "ملح حسب الذوق"
    expect(find.text('مكوّن واحد لم يُعدَّل'), findsOneWidget);

    await tester.tap(find.byTooltip('حصص أقل'));
    await settle(tester);
    expect(find.text('11 حصة'), findsOneWidget);
    expect(shown('1.83 كيلو لحم ضأن'), findsOneWidget); // 11/6 kg

    await tester.tap(find.text('إعادة'));
    await settle(tester);
    expect(shown('1 كيلو لحم ضأن'), findsOneWidget);
    expect(find.text('لم يُعدَّل'), findsNothing);
  });

  testWidgets('conversion view is remembered per recipe (SCALE-5)', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.text('غ / مل'));
    await settle(tester);
    expect(shown('555 غرامًا ارز بسمتي'), findsOneWidget); // 3 cups × 185 g
    expect(shown('1 كيلو لحم ضأن'), findsOneWidget); // already metric

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    expect(shown('555 غرامًا ارز بسمتي'), findsOneWidget);
    expect(recipes.lastError, isNull);
  });

  testWidgets('SHARE-1/2: مشاركة → كنص shares the page as text', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);

    await tester.tap(find.byTooltip('مشاركة'));
    await settle(tester);
    await tester.tap(find.text('كنص'));
    await settle(tester);

    expect(sharer.texts, isNotEmpty);
    expect(sharer.texts.last, startsWith('كبسة لحم'));
    expect(sharer.texts.last, contains('المقادير'));
    expect(sharer.texts.last, contains(wasfatiPlayStoreUrl));
  });

  testWidgets('SHARE-1/3: مشاركة → كصورة renders and shares pages', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);

    await tester.tap(find.byTooltip('مشاركة'));
    await settle(tester);
    await tester.tap(find.text('كصورة'));
    await settle(tester); // the render itself is real async (dart:ui)

    expect(sharer.filePaths, isNotEmpty);
    expect(sharer.filePaths.last, isNotEmpty);
    for (final path in sharer.filePaths.last) {
      expect(File(path).existsSync(), isTrue);
    }
  });

  testWidgets(
    'SHARE-1/3: system Back during rendering does not close the recipe '
    'page or fire a second share (must-fix, adversarial review)',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);

      await tester.tap(find.byTooltip('مشاركة'));
      await settle(tester);
      await tester.tap(find.text('كصورة'));
      await tester.pump(); // the progress dialog appears
      expect(find.byType(AlertDialog), findsOneWidget);

      // PopScope(canPop: false): Back must not dismiss the dialog while
      // rendering is in flight — it used to, leaving the recipe page
      // popped once the render's own unconditional pop later fired.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('كبسة لحم'), findsOneWidget);

      await settle(tester); // let the render finish for real
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('كبسة لحم'), findsOneWidget); // still on the page
      expect(sharer.filePaths, hasLength(1)); // exactly one share, not two
    },
  );

  testWidgets('SHARE-3: a too-long recipe offers to share as text instead '
      '(should-fix, adversarial review)', (tester) async {
    final (recipes, _) = await pumpApp(tester);
    await tester.runAsync(() async {
      final repo = recipes.repository;
      final now = repo.now();
      await recipes.save(
        Recipe(
          id: repo.newId(),
          title: 'وصفة طويلة جدًا',
          steps: [
            Section(
              id: repo.newId(),
              items: [
                for (var i = 0; i < 40; i++)
                  RecipeStep(id: repo.newId(), text: 'خطوة ' * 200),
              ],
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    await settle(tester);
    await tester.tap(find.text('وصفة طويلة جدًا'));
    await settle(tester);

    await tester.tap(find.byTooltip('مشاركة'));
    await settle(tester);
    await tester.tap(find.text('كصورة'));
    await settle(tester); // rendering fails "too long" before any dialog

    expect(
      find.text('هذه الوصفة طويلة جدًا لتُشارك كصور. شاركها كنص بدلاً من ذلك.'),
      findsOneWidget,
    );
    expect(sharer.filePaths, isEmpty);

    await tester.tap(find.text('كنص')); // the SnackBarAction
    await settle(tester);
    expect(sharer.texts, isNotEmpty);
    expect(sharer.texts.last, startsWith('وصفة طويلة جدًا'));
  });

  testWidgets('cook mode: steps, a timer from the text, mark as cooked', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.text('×2')); // SCALE-6: the scale goes along
    await settle(tester);
    // LOOK-6: RailHeading's own rail adds a little height to "المقادير"/
    // "الطريقة", so a fixed-delta scroll no longer reliably lands the
    // button's centre on screen — ensureVisible scrolls it fully into
    // view instead of just into the tree (a plain ListView, so it's
    // already built either way).
    await tester.ensureVisible(find.text('ابدأ الطبخ'));
    await settle(tester);
    await tester.tap(find.text('ابدأ الطبخ'));
    await settle(tester);

    expect(find.text('الخطوة 1 من 2'), findsWidgets);
    expect(find.text('يحمر اللحم في الزبدة.'), findsOneWidget);

    // The ingredients sheet shows the ×2 amounts, with checkboxes.
    await tester.tap(find.byTooltip('المكونات'));
    await settle(tester);
    expect(shown('2 كيلو لحم ضأن'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);
    await tester.tapAt(const Offset(20, 20)); // close the sheet
    await settle(tester);

    await tester.tap(find.text('التالي'));
    await settle(tester);
    expect(find.text('يضاف الأرز ويترك 15 دقيقة.'), findsOneWidget);
    await tester.tap(find.text('15:00')); // COOK-4: found in the text
    await settle(tester);
    expect(timers.running.single.total, const Duration(minutes: 15));
    expect(alerts.asked, 1); // asked at the first timer (COOK-5)
    expect(alerts.scheduled, hasLength(1));

    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.text('تم طبخها'));
    await settle(tester);
    expect(find.text('سُجّلت كوصفة مطبوخة'), findsOneWidget);
    expect(recipes.recipes.single.cookedCount, 1);
  });

  testWidgets('English lines keep 123 with Arabic digits on (QTY-5)', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester, digits: DigitStyle.arabic);
    await tester.runAsync(() async {
      final repo = recipes.repository;
      final now = repo.now();
      await recipes.save(
        Recipe(
          id: repo.newId(),
          title: 'Mixed',
          servings: 4,
          ingredients: [
            Section(
              id: repo.newId(),
              items: [
                IngredientLine.parse(repo.newId(), '2 cups flour'),
                IngredientLine.parse(repo.newId(), '3 كوب رز'),
              ],
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    await settle(tester);
    await tester.tap(find.text('Mixed'));
    await settle(tester);
    expect(shown('2 cups flour'), findsOneWidget); // never "٢ cups flour"
    expect(shown('٣ أكواب رز'), findsOneWidget);
    expect(find.text('٤ حصص'), findsOneWidget); // the app's own text
  });

  testWidgets('import a link: preview, save, then a duplicate (IMP-2/5/9)', (
    tester,
  ) async {
    final (recipes, settings) = await pumpApp(tester);
    await tester.tap(find.text('استيراد من رابط'));
    await settle(tester);
    // IMP-3: a website import parsed on the device never shows a cost
    // line, because it never touches the AI quota.
    expect(find.textContaining('استيراد ذكي واحد'), findsNothing);
    await tester.enterText(find.byType(TextField), 'https://site.com/kabsa');
    await tester.tap(find.text('استيراد'));
    await settle(tester);

    // The preview is the editor, prefilled; nothing is saved yet (IMP-5).
    expect(find.text('راجع واحفظ'), findsOneWidget);
    expect(find.text('كبسة دجاج'), findsOneWidget);
    expect(recipes.recipes, isEmpty);
    expect(find.textContaining('استيراد ذكي واحد'), findsNothing);
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(shown('1 كيلو دجاج'), findsOneWidget); // "١ ك دجاج" parsed
    expect(find.text('من site.com'), findsOneWidget);
    expect(settings.aiImportsUsed, 0); // a free website import spends nothing
    expect(settings.settings.importSaved, isTrue); // RUN-5: an import saved

    // The same page again offers the saved one (IMP-9).
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.byTooltip('استيراد من رابط'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'https://site.com/kabsa/');
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    expect(find.text('محفوظة مسبقًا'), findsOneWidget);
    await tester.tap(find.text('افتح المحفوظة'));
    await settle(tester);
    expect(find.text('كبسة دجاج'), findsOneWidget);
    expect(recipes.recipes.length, 1);
  });

  testWidgets(
    'a link without recipe data goes to AI import (IMP-3), and offers by '
    'hand when that finds no recipe either',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportError(AiImportErrorKind.notARecipe);
      await pumpApp(tester, aiClient: ai);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'https://down.com/x');
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(
        find.text('لم يجد التطبيق وصفة في هذا المحتوى. يمكنك إضافتها بنفسك.'),
        findsOneWidget,
      );
      expect(ai.requests.single.url, 'https://down.com/x');

      await tester.tap(find.text('أضفها بنفسك'));
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);
    },
  );

  testWidgets('a link the device could not fetch at all also goes to AI import '
      '(IMP-3)', (tester) async {
    final ai = NoopAiImportClient()
      ..nextResult = const AiImportError(AiImportErrorKind.network);
    await pumpApp(tester, aiClient: ai);
    await tester.tap(find.text('استيراد من رابط'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'https://down.com/x');
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    expect(
      find.text('تعذّر الاتصال. تحقّق من الإنترنت وحاول مرة أخرى.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Arabic text shared from another app goes to AI import (IMP-3), not '
    'the offline heuristic, but only after the user confirms '
    '(should-fix, review)',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportSuccess(
          ImportedRecipe(
            title: 'كبسة لحم',
            ingredients: [
              (null, ['1 كيلو لحم', 'كوبين رز']),
            ],
            steps: [
              (null, ['يسلق اللحم ساعة']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        );
      final (recipes, settings) = await pumpApp(tester, aiClient: ai);
      shares.add(
        'كبسة لحم\nالمقادير:\n1 كيلو لحم\nكوبين رز\nالطريقة:\nيسلق اللحم ساعة',
      );
      await settle(tester);
      // A share reaches this screen with no tap at all: the cost line and a
      // real choice show first, and nothing is sent until "استيراد" here.
      expect(find.textContaining('سيُستخدم استيراد ذكي واحد'), findsOneWidget);
      expect(ai.requests, isEmpty);

      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);
      expect(ai.requests.single.text, contains('كبسة لحم'));
      expect(ai.requests.single.url, isNull);
      await tester.tap(find.text('حفظ'));
      await settle(tester);
      expect(find.text('كبسة لحم'), findsOneWidget);
      expect(shown('2 كوبان رز'), findsOneWidget);
      expect(recipes.recipes.single.title, 'كبسة لحم');
      expect(recipes.recipes.single.sourceType, SourceType.written);
      expect(settings.aiImportsUsed, 1); // IMP-7: saving spent one
      // RUN-5: an import saved, though its tag says written.
      expect(settings.settings.importSaved, isTrue);
    },
  );

  testWidgets('a shared caption can be declined instead, spending nothing '
      '(IMP-3, should-fix, review)', (tester) async {
    final ai = NoopAiImportClient();
    final (recipes, settings) = await pumpApp(tester, aiClient: ai);
    shares.add('نص عشوائي بلا وصفة');
    await settle(tester);
    expect(find.textContaining('سيُستخدم استيراد ذكي واحد'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await settle(tester);
    expect(ai.requests, isEmpty);
    expect(recipes.recipes, isEmpty);
    expect(settings.aiImportsUsed, 0);
    // Back to the plain import screen, link field enabled again.
    expect(find.text('استيراد'), findsOneWidget);
  });

  testWidgets(
    'an AI import shows the cost line and the count before the request '
    'completes (IMP-3, IMP-4)',
    (tester) async {
      final ai = _ControlledAiImportClient();
      final (recipes, _) = await pumpApp(tester, aiClient: ai);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.tiktok.com/@a/video/1',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester); // fromUrl fails locally, then AI is called

      expect(ai.requests.single.url, 'https://www.tiktok.com/@a/video/1');
      expect(find.textContaining('سيُستخدم استيراد ذكي واحد'), findsOneWidget);
      expect(find.textContaining('بقي 10 من 10'), findsWidgets);

      ai.complete(
        const AiImportSuccess(
          ImportedRecipe(
            title: 'ريل تيك توك',
            ingredients: [
              (null, ['كوب سكر']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        ),
      );
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);
      expect(find.text('ريل تيك توك'), findsOneWidget);
      expect(recipes.recipes, isEmpty); // still just the preview (IMP-5)
    },
  );

  testWidgets(
    "cancelling an AI import's preview leaves the quota untouched (IMP-4, "
    'IMP-7)',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportSuccess(
          ImportedRecipe(
            title: 'ريل تيك توك',
            ingredients: [
              (null, ['كوب سكر']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        );
      final (recipes, settings) = await pumpApp(tester, aiClient: ai);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.tiktok.com/@a/video/1',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);

      await tester.binding.handlePopRoute(); // system Back out of the preview
      await settle(tester);
      expect(find.text('تجاهل التعديلات؟'), findsOneWidget);
      await tester.tap(find.text('تجاهل'));
      await settle(tester);

      expect(recipes.recipes, isEmpty);
      expect(settings.aiImportsUsed, 0); // a cancelled preview spends nothing
    },
  );

  testWidgets('saving an AI import spends one (IMP-7)', (tester) async {
    final ai = NoopAiImportClient()
      ..nextResult = const AiImportSuccess(
        ImportedRecipe(
          title: 'ريل تيك توك',
          ingredients: [
            (null, ['كوب سكر']),
          ],
        ),
        model: 'haiku',
        promptVersion: '1',
        cached: false,
      );
    final (recipes, settings) = await pumpApp(tester, aiClient: ai);
    await tester.tap(find.text('استيراد من رابط'));
    await settle(tester);
    await tester.enterText(
      find.byType(TextField),
      'https://www.tiktok.com/@a/video/1',
    );
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    await tester.tap(find.text('حفظ'));
    await settle(tester);

    expect(recipes.recipes.single.title, 'ريل تيك توك');
    expect(settings.aiImportsUsed, 1);
    expect(settings.aiImportsLeft(), 9);

    // The header counter on the import screen reflects the new count too.
    await tester.binding.handlePopRoute(); // back from the recipe page
    await settle(tester);
    // The library has a recipe now, so it's the app bar's icon (not the
    // empty state's labelled FAB) that opens Import.
    await tester.tap(find.byTooltip('استيراد من رابط'));
    await settle(tester);
    expect(find.textContaining('بقي 9 من 10'), findsOneWidget);
  });

  testWidgets('out of AI imports: the screen says so, and website import still '
      'works (IMP-7)', (tester) async {
    final ai = NoopAiImportClient();
    final (_, settings) = await pumpApp(tester, aiClient: ai);
    await tester.runAsync(() async {
      for (var i = 0; i < 10; i++) {
        await settings.recordAiImportSaved();
      }
    });
    await tester.tap(find.text('استيراد من رابط'));
    await settle(tester);
    expect(
      find.text(
        'نفدت الاستيرادات الذكية هذا الشهر · تتجدد في الأول من كل شهر. '
        'استيراد صفحات المواقع يبقى مجانيًا وبلا حدود.',
      ),
      findsOneWidget,
    );

    // A link that would need AI isn't even attempted (IMP-7).
    await tester.enterText(
      find.byType(TextField),
      'https://www.tiktok.com/@a/video/1',
    );
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    expect(ai.requests, isEmpty);
    expect(find.text('أضفها بنفسك'), findsOneWidget);

    // A normal website import still works, free (IMP-2).
    await tester.enterText(find.byType(TextField), 'https://site.com/kabsa');
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    expect(find.text('راجع واحفظ'), findsOneWidget);
    expect(find.text('كبسة دجاج'), findsOneWidget);
  });

  testWidgets(
    'IMP-12: an unreadable link offers to paste the caption, read only on '
    'tap, and the original link stays the source',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportError(AiImportErrorKind.unreachable);
      final (recipes, _) = await pumpApp(tester, aiClient: ai);

      var clipboardReads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            clipboardReads++;
            return {'text': 'كبسة دجاج كوب رز'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.instagram.com/p/abc/',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester);

      expect(find.text('تعذّر قراءة محتوى هذا الرابط.'), findsOneWidget);
      expect(clipboardReads, 0); // reaching this screen reads nothing

      ai.nextResult = const AiImportSuccess(
        ImportedRecipe(
          title: 'كبسة دجاج',
          ingredients: [
            (null, ['كوب رز']),
          ],
        ),
        model: 'haiku',
        promptVersion: '1',
        cached: false,
      );
      await tester.tap(find.byIcon(Icons.content_paste).last);
      await settle(tester);
      expect(clipboardReads, 1); // read only now, on the tap
      expect(find.text('كبسة دجاج كوب رز'), findsOneWidget); // in the box

      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);
      expect(ai.requests.last.text, 'كبسة دجاج كوب رز');
      expect(ai.requests.last.url, isNull);

      await tester.tap(find.text('حفظ'));
      await settle(tester);
      // IMP-9/IMP-12: the original link stays as the source.
      expect(find.text('من instagram.com'), findsOneWidget);
      expect(recipes.recipes.single.sourceType, SourceType.social);
      await tester.runAsync(() async {
        expect(
          await recipes.repository.findBySourceUrl(
            'https://instagram.com/p/abc',
          ),
          recipes.recipes.single.id,
        );
      });
    },
  );

  testWidgets(
    'SRV-7 private_post also offers the paste-caption fallback, with the '
    'original link kept as the source (IMP-12, must-fix, review)',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportError(AiImportErrorKind.privatePost);
      final (recipes, _) = await pumpApp(tester, aiClient: ai);

      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.instagram.com/p/xyz/',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester);

      // The paste box shows, not the generic "unexpected error" message.
      expect(find.text('حدث خطأ غير متوقع. حاول مرة أخرى.'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2)); // link + caption

      ai.nextResult = const AiImportSuccess(
        ImportedRecipe(
          title: 'وصفة خاصة',
          ingredients: [
            (null, ['كوب سكر']),
          ],
        ),
        model: 'haiku',
        promptVersion: '1',
        cached: false,
      );
      await tester.enterText(find.byType(TextField).last, 'وصفة خاصة كوب سكر');
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);

      await tester.tap(find.text('حفظ'));
      await settle(tester);
      expect(find.text('من instagram.com'), findsOneWidget); // IMP-9/IMP-12
      expect(recipes.recipes.single.sourceType, SourceType.social);
    },
  );

  testWidgets(
    'a failed caption send keeps the paste box and the caption on screen, '
    'and a retry still saves with the original link (IMP-9, IMP-12, '
    'should-fix, review)',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportError(AiImportErrorKind.unreachable);
      final (recipes, _) = await pumpApp(tester, aiClient: ai);

      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.instagram.com/p/abc/',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(find.text('تعذّر قراءة محتوى هذا الرابط.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'كبسة دجاج كوب رز');
      // The caption send itself fails, e.g. Wi-Fi dropped for a second.
      ai.nextResult = const AiImportError(AiImportErrorKind.network);
      await tester.tap(find.text('استيراد'));
      await settle(tester);

      // The paste box and the pasted text must still be on screen — not
      // wiped out along with the (unrelated) original link.
      expect(
        find.text('تعذّر الاتصال. تحقّق من الإنترنت وحاول مرة أخرى.'),
        findsOneWidget,
      );
      expect(find.text('كبسة دجاج كوب رز'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));

      ai.nextResult = const AiImportSuccess(
        ImportedRecipe(
          title: 'كبسة دجاج',
          ingredients: [
            (null, ['كوب رز']),
          ],
        ),
        model: 'haiku',
        promptVersion: '1',
        cached: false,
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);

      await tester.tap(find.text('حفظ'));
      await settle(tester);
      // The original link, not the caption, is still the saved source.
      expect(find.text('من instagram.com'), findsOneWidget);
      expect(recipes.recipes.single.sourceType, SourceType.social);
    },
  );

  testWidgets(
    '"أضفها بنفسك" normalizes the link, so re-importing it later is still '
    'caught as a duplicate (IMP-9, should-fix, review)',
    (tester) async {
      final ai = NoopAiImportClient();
      final (recipes, settings) = await pumpApp(tester, aiClient: ai);
      await tester.runAsync(() async {
        for (var i = 0; i < 10; i++) {
          await settings.recordAiImportSaved();
        }
      });
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.tiktok.com/@a/video/9?is_from_webapp=1',
      );
      await tester.tap(find.text('استيراد')); // out of quota: no AI attempt
      await settle(tester);
      await tester.tap(find.text('أضفها بنفسك'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'ريل بلا حصة');
      await tester.tap(find.text('حفظ'));
      await settle(tester);
      // RUN-5: typed by hand, so no import saved, though tagged with a link.
      expect(recipes.recipes.single.sourceType, SourceType.website);
      expect(settings.settings.importSaved, isFalse);
      await tester.runAsync(() async {
        expect(
          await recipes.repository.findBySourceUrl(
            'https://tiktok.com/@a/video/9',
          ),
          recipes.recipes.single.id,
        );
      });
    },
  );

  testWidgets(
    'a double tap on Save before it settles spends the AI quota once, not '
    'twice (IMP-7, should-fix, review)',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportSuccess(
          ImportedRecipe(
            title: 'ريل تيك توك',
            ingredients: [
              (null, ['كوب سكر']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        );
      final (recipes, settings) = await pumpApp(tester, aiClient: ai);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.tiktok.com/@a/video/1',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester);

      // Two taps with nothing pumped in between, as a fast double tap
      // would land before the first one's own async work is done.
      await tester.tap(find.text('حفظ'));
      await tester.tap(find.text('حفظ'));
      await settle(tester);

      expect(recipes.recipes.single.title, 'ريل تيك توك');
      expect(recipes.recipes.length, 1); // one recipe, not a second copy
      expect(settings.aiImportsUsed, 1);
    },
  );

  testWidgets(
    'IMP-4: past 45 seconds, AI import offers "Keep waiting" or "Cancel"',
    (tester) async {
      final ai = _ControlledAiImportClient();
      await pumpApp(tester, aiClient: ai);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.tiktok.com/@a/video/1',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester); // fromUrl fails locally, then AI is called
      expect(find.text('جارٍ الاستيراد بالذكاء الاصطناعي…'), findsOneWidget);
      expect(find.text('متابعة الانتظار'), findsNothing);

      await tester.pump(const Duration(seconds: 46));
      expect(find.text('متابعة الانتظار'), findsOneWidget);
      expect(find.text('يستغرق هذا وقتًا أطول من المعتاد.'), findsOneWidget);

      // "Keep waiting" dismisses the prompt; the request is still in flight.
      await tester.tap(find.text('متابعة الانتظار'));
      await tester.pump();
      expect(find.text('متابعة الانتظار'), findsNothing);
      expect(ai.requests, hasLength(1)); // never re-sent

      ai.complete(
        const AiImportSuccess(
          ImportedRecipe(
            title: 'ريل تيك توك',
            ingredients: [
              (null, ['كوب سكر']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        ),
      );
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);
    },
  );

  testWidgets('the title is required (REC-3)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('أضف وصفة'));
    await settle(tester);
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(find.text('اكتب اسم الوصفة'), findsOneWidget);
  });

  testWidgets('leaving with changes asks first', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('أضف وصفة'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, 'شوربة');
    await tester.pump(); // the frame that arms the unsaved-changes guard
    await tester.binding.handlePopRoute(); // system Back
    await settle(tester);
    expect(find.text('تجاهل التعديلات؟'), findsOneWidget);
    await tester.tap(find.text('تجاهل'));
    await settle(tester);
    expect(find.text('لا توجد وصفات بعد'), findsOneWidget);
  });

  testWidgets('Arabic digits setting shows ١٢٣ (QTY-5, Decision 5)', (
    tester,
  ) async {
    await pumpApp(tester, digits: DigitStyle.arabic, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    expect(find.text('٦ حصص'), findsOneWidget);
    expect(shown('١ كيلو لحم ضأن'), findsOneWidget);
  });

  testWidgets('delete, then Undo brings it back (DEL-1, DEL-2)', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.byTooltip('حذف'));
    await settle(tester);
    expect(find.text('حُذفت الوصفة'), findsOneWidget);
    expect(find.text('كبسة لحم'), findsNothing);

    await tester.tap(find.text('تراجع'));
    await settle(tester);
    expect(find.text('كبسة لحم'), findsOneWidget);
  });

  testWidgets('a language change applies at once (LANG-1)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('الإعدادات'));
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(dirOf(tester, find.text('Settings')), TextDirection.ltr);
  });

  testWidgets(
    'the PHONE changing language applies at once too, on "حسب الجهاز" '
    '(LANG-1, must-fix, review)',
    (tester) async {
      // The device starts in Arabic; LanguagePref.system follows it.
      tester.platformDispatcher.localesTestValue = [const Locale('ar')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpApp(tester, language: LanguagePref.system);
      expect(find.text('وصفاتي'), findsOneWidget);

      // The device's language changes while the app stays open — no
      // restart, no Settings screen involved at all. Setting the test
      // value fires the platform dispatcher's own onLocaleChanged, exactly
      // as a real device language change would (didChangeLocales below).
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      await settle(tester);

      expect(find.text('Wasfati'), findsOneWidget);
      expect(dirOf(tester, find.text('Wasfati')), TextDirection.ltr);
    },
  );

  for (final lang in [LanguagePref.ar, LanguagePref.en]) {
    testWidgets('${lang.name} at 1.3× text size: no overflow (LANG-6)', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, textScale: 1.3, withRecipe: true);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
