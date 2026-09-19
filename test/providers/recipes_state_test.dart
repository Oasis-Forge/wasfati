import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/providers/recipes_state.dart';

import '../helpers.dart';

void main() {
  test('save writes first, then shows the recipe', () async {
    final (repo, _, _) = await testRepo();
    final state = RecipesState(repo);
    await state.load();
    expect(state.recipes, isEmpty);

    final saved = await state.save(kabsa(repo));
    expect(saved, isNotNull);
    expect(state.recipes.map((r) => r.title), ['كبسة لحم']);
    expect(state.lastError, isNull);
  });

  test('a failed write keeps the list as it was and reports it', () async {
    final (repo, _, _) = await testRepo();
    final state = RecipesState(repo);
    await state.save(kabsa(repo));

    final result = await state.save(kabsa(repo, title: '')); // REC-3 refuses
    expect(result, isNull);
    expect(state.recipes.length, 1);
    expect(state.lastError, isA<ArgumentError>());

    state.clearError();
    expect(state.lastError, isNull);
  });

  test('delete and undo (DEL-1, DEL-2)', () async {
    final (repo, _, _) = await testRepo();
    final state = RecipesState(repo);
    final r = (await state.save(kabsa(repo)))!;

    expect(await state.delete(r.id), isTrue);
    expect(state.recipes, isEmpty);
    expect(await state.restore(r.id), isTrue);
    expect(state.recipes.single.id, r.id);

    expect(await state.delete('missing'), isFalse);
    expect(state.lastError, isA<StateError>());
    expect(state.recipes.length, 1);
  });
}
