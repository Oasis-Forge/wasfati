import '../models/review_prompt.dart';
import '../services/ids.dart';
import '../services/store_review.dart';
import 'recipes_state.dart';
import 'settings_state.dart';

/// RUN-5: decides, when cook mode closes from its last page, whether to
/// ask the store for its review prompt, and remembers when it did. The
/// conditions are [reviewPromptDue]'s; the saved import and the cooked
/// recipe are read from the live library, the last time asked from
/// Settings (so a restored backup carries it, BAK-6).
class ReviewPrompt {
  ReviewPrompt({
    required this.store,
    required this.settings,
    required this.recipes,
    Clock? clock,
  }) : _clock = clock ?? systemClock;

  final StoreReview store;
  final SettingsState settings;
  final RecipesState recipes;
  final Clock _clock;
  bool _asking = false;

  /// Cook mode just closed from its last page, by "Done" or by "Mark as
  /// cooked" (which closes it too, COOK-6). Returns whether the store was
  /// asked. The time is written before the store is asked, so a crash or a
  /// second close while the prompt is up never asks twice.
  Future<bool> afterCooking() async {
    if (_asking) return false;
    final s = settings.settings;
    final now = _clock();
    final due = reviewPromptDue(
      firstRunComplete: s.firstRunComplete,
      savedImport: hasSavedImport(recipes.recipes),
      markedCooked: hasMarkedCooked(recipes.recipes),
      lastAskedAt: s.reviewAskedAt,
      now: now,
    );
    if (!due) return false;
    _asking = true;
    try {
      await settings.update(s.copyWith(reviewAskedAt: now));
      await store.request();
      return true;
    } on Exception {
      // A write that failed stored nothing: not asked, so a later close can
      // try again. Cook mode doesn't wait for this, so it must never throw.
      return false;
    } finally {
      _asking = false;
    }
  }
}
