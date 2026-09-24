import 'library.dart';

/// RUN-5: the store's review prompt is asked for at most once in this long.
const reviewPromptInterval = Duration(days: 120);

/// RUN-5: whether cook mode closing from its last page may ask the store
/// for its review prompt. Every condition has to hold:
///
/// - the first run is over ([firstRunComplete]): never during setup or the
///   walkthrough;
/// - the user has saved an import ([savedImport], `AppSettings.importSaved`:
///   a fetched or AI draft saved from the import preview, never a recipe
///   typed by hand after a failed import) and marked a recipe as cooked
///   ([markedCooked], REC-9) — someone who has had what makes Wasfati
///   different;
/// - the store was never asked ([lastAskedAt] null), or at least
///   [reviewPromptInterval] has passed since it was. A [lastAskedAt] later
///   than [now] (the phone's clock was moved back) counts as recent, so a
///   clock change never makes the prompt come sooner.
///
/// The trigger itself — cook mode closing from its last page — is the only
/// caller, so a purchase is never under way when this runs. Nothing here
/// asks "Do you like Wasfati?" first: the answer goes straight to the
/// store's own prompt.
bool reviewPromptDue({
  required bool firstRunComplete,
  required bool savedImport,
  required bool markedCooked,
  required DateTime? lastAskedAt,
  required DateTime now,
}) {
  if (!firstRunComplete || !savedImport || !markedCooked) return false;
  if (lastAskedAt == null) return true;
  return !now.isBefore(lastAskedAt.add(reviewPromptInterval));
}

/// RUN-5, REC-9: a live recipe marked as cooked at least once.
bool hasMarkedCooked(Iterable<LibraryEntry> recipes) =>
    recipes.any((r) => r.cookedCount > 0);
