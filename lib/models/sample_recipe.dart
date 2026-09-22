import 'recipe.dart';

/// The built-in sample recipe (RUN-6): offered once on a phone with no
/// recipes at all, so the first screen shows what a saved recipe looks
/// like. Fixed IDs (REC-2) so the same default matches across devices, and
/// it behaves like any other recipe once saved.
Recipe sampleRecipe({required bool arabic, required DateTime now}) {
  final id = arabic ? 'sample-ar-lentil-soup' : 'sample-en-lentil-soup';
  final groupId = '$id-g1';
  final stepGroupId = '$id-sg1';
  String lineId(int n) => '$id-i$n';
  String stepId(int n) => '$id-s$n';

  const arIngredients = [
    '1 كوب عدس أحمر',
    '½ بصلة مفرومة',
    '٢ فص ثوم',
    '½ كوب جزر مقطع',
    '2 ملعقة كبيرة زيت زيتون',
    '1 ملعقة صغيرة كمون',
    'ربع ملعقة صغيرة كركم',
    '5 أكواب ماء',
    'ملح حسب الذوق',
    '½ ليمونة معصورة',
  ];
  const enIngredients = [
    '1 cup red lentils',
    '½ onion, chopped',
    '2 cloves garlic',
    '½ cup diced carrot',
    '2 tbsp olive oil',
    '1 tsp cumin',
    '¼ tsp turmeric',
    '5 cups water',
    'salt to taste',
    '½ lemon, juiced',
  ];
  const arSteps = [
    'يُغسل العدس جيدًا ويُصفّى.',
    'يُقلى البصل والثوم في الزيت لمدة 5 دقائق حتى يذبل.',
    'يُضاف العدس والجزر والماء والكمون والكركم، ويُترك على نار هادئة لمدة 25 دقيقة.',
    'تُهرس الشوربة بالخلاط، ثم يُضاف الملح وعصير الليمون.',
  ];
  const enSteps = [
    'Rinse the lentils well and drain them.',
    'Fry the onion and garlic in the oil for 5 minutes, until soft.',
    'Add the lentils, carrot, water, cumin and turmeric, and simmer '
        'for 25 minutes.',
    'Blend the soup smooth, then add the salt and lemon juice.',
  ];
  const arNotes =
      'وصفة تجريبية لتتعرّف على التطبيق: غيّر عدد الحصص، أو ابدأ الطبخ '
      'خطوة بخطوة، ثم احذفها متى شئت.';
  const enNotes =
      'A sample recipe to show you around: change the servings, or start '
      'cooking step by step, then delete it whenever you like.';

  final ingredientTexts = arabic ? arIngredients : enIngredients;
  final stepTexts = arabic ? arSteps : enSteps;

  return Recipe(
    id: id,
    title: arabic ? 'شوربة عدس' : 'Red lentil soup',
    sourceType: SourceType.written,
    servings: 4,
    prepMinutes: 10,
    cookMinutes: 30,
    notes: arabic ? arNotes : enNotes,
    ingredients: [
      Section(
        id: groupId,
        items: [
          for (final (i, text) in ingredientTexts.indexed)
            IngredientLine.parse(lineId(i + 1), text),
        ],
      ),
    ],
    steps: [
      Section(
        id: stepGroupId,
        items: [
          for (final (i, text) in stepTexts.indexed)
            RecipeStep(id: stepId(i + 1), text: text),
        ],
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}
