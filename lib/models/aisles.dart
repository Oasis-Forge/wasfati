import 'quantity/arabic_text.dart';

/// The grocery aisles, in the order of a walk through a store (GRO-4).
/// Stored by [Enum.name]; their labels are translated messages (DATA-1).
enum Aisle {
  produce, // خضار وفواكه
  meat, // لحوم ودواجن
  fish, // أسماك
  dairy, // ألبان وأجبان وبيض
  bakery, // خبز ومخبوزات
  grains, // أرز ومعكرونة وبقوليات
  spices, // بهارات
  pantry, // زيوت وصلصات ومعلبات
  baking, // مستلزمات الحلويات
  frozen, // مجمدات
  drinks, // مشروبات
  other, // أخرى
}

// Vegetables and fruit (خضار وفواكه). Plain "فلفل"/"بصل"/"ثوم"/"زيتون" mean
// the fresh vegetable; a spice or pantry phrase built on the same word
// (e.g. "فلفل أسود", "بصل مجفف", "زيت زيتون") is listed under that aisle
// instead and wins by being the longer phrase (GRO-4).
const _produceNames = <String>[
  'بصل', 'بصلة', 'بصل أبيض', 'بصل أحمر', 'بصل أخضر', 'بصلة خضراء',
  'ثوم', 'ثوم طازج', 'رأس ثوم',
  'طماطم', 'طماطم مقطعة', 'بندورة', 'بندورة مقطعة', 'طماط',
  'بطاطا', 'بطاطس', 'بطاطا حلوة', 'بطاطا مسلوقة',
  'خيار', 'خيارة', 'خيار لبناني',
  'جزر', 'جزرة', 'جزر مبشور',
  'فلفل', 'فلفل حار', 'فلفل رومي', 'فلفل حلو', 'فلفل أخضر', 'فلفل أحمر',
  'فلفل ألوان', 'فلفل بارد',
  'باذنجان', 'باذنجان صيني', 'باذنجان مقلي',
  'كوسا', 'كوسة', 'كوسا مفرغة',
  'ليمون', 'ليمون أخضر', 'حامض',
  'برتقال', 'برتقالة',
  'تفاح', 'تفاحة',
  'موز', 'موزة',
  'عنب', 'حبة عنب',
  'بطيخ', 'شمام',
  'رمان', 'رمان حب', 'حب رمان',
  'مانجو', 'مانجا',
  'فراولة', 'فريز',
  'خس', 'خس روماني',
  'كرنب', 'ملفوف', 'ملفوف أحمر',
  'سبانخ', 'سبانخ طازجة',
  'بقدونس', 'بقدوس', 'بقدونس مفروم',
  'كزبرة', 'كسبرة', 'كزبرة خضراء', 'كزبرة طازجة',
  'نعناع', 'نعناع طازج',
  'شبت', 'شبث',
  'سلق', 'ورقيات سلق',
  'بامية', 'بامية طازجة',
  'فاصوليا خضراء', 'لوبيا خضراء',
  'بازلاء', 'بسلة', 'بازلا',
  'ذرة', 'ذرة طازجة', 'كوز ذرة',
  'يقطين', 'قرع', 'قرع عسل',
  'فجل', 'فجل أحمر',
  'لفت',
  'شمندر', 'بنجر',
  'زنجبيل', 'زنجبيل طازج',
  'أفوكادو',
  'فطر', 'مشروم', 'فطر طازج',
  'كرفس', 'كراث',
  'خرشوف',
  'قرنبيط', 'زهرة',
  'بروكلي',
  'جرجير',
  'تمر', 'تمر مجدول',
  'مشمش', 'خوخ', 'برقوق', 'تين', 'كرز', 'إجاص', 'كمثرى',
  'أناناس', 'كيوي',
  'ورق عنب', 'ورق دوالي',
  'بصل شلوت', 'موالح',
  'كراث أخضر',
  // English.
  'onion', 'garlic', 'tomato', 'potato', 'cucumber', 'carrot', 'pepper',
  'bell pepper', 'green pepper', 'red pepper', 'eggplant', 'zucchini',
  'lemon', 'lime', 'orange', 'apple', 'banana', 'grape', 'watermelon',
  'melon', 'pomegranate', 'mango', 'strawberry', 'lettuce', 'cabbage',
  'spinach', 'parsley', 'cilantro', 'coriander', 'mint', 'dill', 'okra',
  'green beans', 'peas', 'corn', 'pumpkin', 'radish', 'turnip', 'beetroot',
  'ginger', 'avocado', 'mushroom', 'celery', 'leek', 'artichoke',
  'cauliflower', 'broccoli', 'arugula', 'sweet potato', 'dates', 'apricot',
  'peach', 'plum', 'fig', 'cherry', 'pear', 'pineapple', 'kiwi', 'shallot',
  'grape leaves', 'scallion', 'green onion',
];

// Meat and poultry (لحوم ودواجن). "دجاج مجمد"/"لحم مجمد" are overridden to
// frozen below, and "لحم مفروم" still matches meat via the single word.
const _meatNames = <String>[
  'لحم', 'لحمة', 'لحم ضأن', 'لحم غنم', 'لحم خروف', 'لحم بقر', 'لحم عجل',
  'لحم مفروم', 'لحم غنم مفروم', 'لحم بقري مفروم', 'لحم جمل', 'ريش غنم',
  'رقبة غنم', 'موزات', 'لسان بقري', 'طحال', 'شرحات لحم',
  'دجاج', 'دجاجة', 'صدر دجاج', 'فخذ دجاج', 'جناح دجاج', 'ورك دجاج',
  'دجاج مقطع', 'دجاج كامل', 'أرباع دجاج', 'دجاج بلدي',
  'ديك رومي', 'حبش',
  'كبدة', 'كبدة دجاج', 'كلاوي', 'قلب دجاج', 'قوانص',
  'نقانق', 'سجق', 'هوت دوج', 'كباب', 'كفتة', 'كفته', 'ستيك', 'بيف',
  'بط', 'بطة', 'أرانب',
  'بسطرمة', 'مرتديلا', 'لانشون',
  // English.
  'meat', 'chicken', 'chicken breast', 'chicken thigh', 'chicken wing',
  'chicken drumstick', 'whole chicken', 'beef', 'lamb', 'mutton', 'veal',
  'turkey', 'minced meat', 'ground beef', 'ground chicken', 'sausage',
  'steak', 'liver', 'kidney', 'kabab', 'kofta', 'duck', 'rabbit', 'bacon',
  'ham', 'pastrami',
];

// Fish and seafood (أسماك). "تونة معلبة" is overridden to pantry below.
const _fishNames = <String>[
  'سمك', 'سمكة', 'سمك هامور', 'سمك زبيدي', 'سمك سلمون', 'سمك بلطي',
  'سمك فيليه', 'سمك بوري', 'سمك شعم', 'سمك قاروص', 'سمك مقلي', 'سمك مسقوف',
  'فيليه سمك', 'تونة', 'روبيان', 'جمبري', 'قريدس', 'سلطعون', 'كابوريا',
  'حبار', 'استاكوزا', 'بلح البحر', 'محار', 'سردين', 'أنشوجة',
  'جراد البحر',
  // English.
  'fish', 'salmon', 'tuna', 'shrimp', 'prawns', 'crab', 'squid', 'lobster',
  'mussels', 'sardine', 'anchovy', 'cod', 'tilapia', 'fish fillet',
  'oyster', 'calamari',
];

// Dairy, cheese and eggs (ألبان وأجبان وبيض). "زبدة الفول السوداني" and the
// canned/powdered milk phrases are overridden to pantry below.
const _dairyNames = <String>[
  'حليب', 'حليب كامل الدسم', 'حليب قليل الدسم', 'حليب طازج',
  'لبن', 'لبن رائب', 'زبادي', 'لبن زبادي يوناني',
  'قشطة', 'كريمة', 'كريمة خفق', 'كريمة طبخ',
  'جبن', 'جبنة', 'جبن شيدر', 'جبن موزاريلا', 'جبن حلوم', 'جبن فيتا',
  'جبن كريمي', 'جبن رومي', 'جبنة قريش', 'جبن مبشور', 'جبن أبيض',
  'لبنة',
  'زبدة',
  'بيض', 'بيضة', 'صفار بيض', 'بياض بيض',
  // English.
  'milk', 'whole milk', 'yogurt', 'greek yogurt', 'cream',
  'whipping cream', 'cheese', 'cheddar', 'mozzarella', 'feta',
  'cream cheese', 'cottage cheese', 'halloumi', 'labneh', 'butter',
  'eggs', 'egg', 'egg yolk', 'egg white', 'buttermilk', 'sour cream',
  'ricotta', 'parmesan',
];

// Bread and bakery (خبز ومخبوزات).
const _bakeryNames = <String>[
  'خبز', 'خبز عربي', 'خبز رقاق', 'خبز توست', 'توست', 'خبز فرنسي', 'باغيت',
  'صامولي', 'كيزر', 'تورتيلا', 'خبز صاج', 'كماج', 'كعك', 'معجنات',
  'كرواسون', 'خبز أسمر', 'خبز أبيض', 'خبز بر', 'رغيف', 'رغيف خبز',
  'فطيرة', 'مناقيش', 'خبز برجر', 'خبز هوت دوج', 'خبز شعير',
  // English.
  'bread', 'pita bread', 'toast', 'baguette', 'bun', 'burger bun',
  'hot dog bun', 'tortilla', 'croissant', 'bagel', 'brown bread',
  'white bread', 'sourdough', 'roll',
];

// Rice, pasta, grains and pulses (أرز ومعكرونة وبقوليات).
const _grainsNames = <String>[
  'رز', 'أرز', 'ارز بسمتي', 'رز بسمتي', 'أرز مصري', 'أرز أبيض', 'أرز بني',
  'أرز طويل الحبة',
  'معكرونة', 'باستا', 'سباغيتي', 'شعيرية', 'مكرونة',
  'برغل', 'برغل ناعم', 'برغل خشن', 'برغل مجروش',
  'فريكة', 'كسكسي', 'كسكس', 'سميد', 'شوفان',
  'عدس', 'عدس أحمر', 'عدس أصفر', 'عدس أسود',
  'حمص', 'حمص حب', 'فول', 'فول مدمس',
  'فاصوليا بيضاء', 'فاصوليا حمراء', 'فاصوليا سوداء', 'لوبيا', 'ماش',
  'بازلاء يابسة', 'قمح', 'جريش', 'كينوا', 'شعير',
  'ذرة صفراء مطحونة',
  // English.
  'rice', 'basmati rice', 'brown rice', 'white rice', 'pasta', 'spaghetti',
  'macaroni', 'noodles', 'bulgur', 'freekeh', 'couscous', 'semolina',
  'oats', 'lentils', 'red lentils', 'chickpeas', 'fava beans',
  'white beans', 'kidney beans', 'black beans', 'split peas', 'wheat',
  'quinoa', 'barley',
];

// Spices (بهارات). The multi-word forms override the produce word they're
// built on, so "فلفل أسود" and "بصل مجفف" are spices, not produce.
const _spicesNames = <String>[
  'ملح', 'ملح خشن', 'ملح ناعم',
  'فلفل أسود', 'فلفل أبيض', 'فلفل أحمر مطحون', 'فلفل شطة',
  'كمون', 'كمون مطحون', 'كركم', 'كركم مطحون',
  'هال', 'حبهان',
  'قرفة', 'قرفة عيدان', 'قرفة مطحونة',
  'قرنفل', 'زعفران', 'بابريكا', 'بهارات مشكلة', 'بهار حلو', 'بهار مشكل',
  'جوزة الطيب', 'يانسون', 'حبة البركة', 'حبة سوداء', 'سماق', 'زعتر',
  'زعتر بري', 'شطة',
  'بودرة ثوم', 'مسحوق ثوم', 'ثوم مجفف',
  'بصل مجفف', 'بودرة بصل',
  'ورق غار',
  'لومي',
  'لومي مطحون',
  'ليمون أسود',
  'ليمون مجفف', // dried lime is a spice in the Gulf
  'بهارات كبسة', 'بهارات برياني', 'بهارات دجاج',
  'كزبرة مطحونة',
  // English.
  'salt', 'black pepper', 'white pepper', 'cumin', 'turmeric', 'cardamom',
  'cinnamon', 'cloves', 'saffron', 'paprika', 'mixed spices', 'allspice',
  'nutmeg', 'anise', 'black seed', 'sumac', 'thyme', 'zaatar',
  'chili powder', 'garlic powder', 'onion powder', 'bay leaf',
  'curry powder', 'garam masala', 'ground coriander', 'ground cumin',
];

// Oils, sauces and cans (زيوت وصلصات ومعلبات). These multi-word phrases
// override the produce/meat/dairy word they're built on: "معجون طماطم"
// (not the fresh tomato), "زيت زيتون" (not the fresh olive), "مرقة لحم"
// and "مرق دجاج" (broth, not the meat), "حليب جوز الهند"/"حليب مكثف"
// (canned/tinned, not fresh dairy), "زبدة الفول السوداني" (peanut butter,
// not dairy butter), "تونة معلبة" (canned, not the fresh fish aisle).
const _pantryNames = <String>[
  'زيت', 'زيت زيتون', 'زيت نباتي', 'زيت ذرة', 'زيت دوار الشمس',
  'زيت جوز الهند', 'زيت سمسم',
  'معجون طماطم', 'معجون بندورة', 'رب طماطم', 'رب بندورة',
  'صلصة طماطم', 'صلصة بندورة', 'طماطم معلبة',
  'دبس رمان', 'دبس تمر',
  'عسل', 'خل', 'خل تفاح', 'خل أبيض',
  'صويا صوص', 'صلصة الصويا', 'مايونيز', 'كاتشب', 'خردل',
  'طحينة',
  'زيتون', 'زيتون أسود', 'زيتون أخضر', 'مخلل', 'مخللات', 'مخلل خيار',
  'حليب جوز الهند', 'حليب مكثف', 'حليب مكثف محلى', 'حليب بودرة',
  'مرقة لحم', 'مرق لحم', 'مرقة دجاج', 'مرق دجاج', 'مكعبات مرقة',
  'مرقة خضار',
  'سمن', 'سمن بلدي',
  'زبدة الفول السوداني', 'فول سوداني مطحون',
  'مربى', 'مربى فراولة',
  'هريسة', 'صلصة حارة', 'صلصة باربكيو',
  'تونة معلبة', 'ذرة معلبة', 'فول معلب', 'فاصوليا معلبة',
  'صلصة سلطة',
  // English.
  'oil', 'olive oil', 'vegetable oil', 'corn oil', 'sunflower oil',
  'coconut oil', 'tomato paste', 'tomato sauce', 'pomegranate molasses',
  'date syrup', 'honey', 'vinegar', 'apple cider vinegar', 'soy sauce',
  'mayonnaise', 'ketchup', 'mustard', 'tahini', 'olives', 'pickles',
  'coconut milk', 'condensed milk', 'powdered milk', 'broth',
  'chicken broth', 'beef broth', 'bouillon cube', 'ghee', 'peanut butter',
  'jam', 'strawberry jam', 'hot sauce', 'barbecue sauce', 'canned tuna',
  'canned corn', 'canned beans', 'canned tomato', 'salad dressing',
  'hummus',
];

// Baking and sweets: flour, sugar, yeast, baking powder, chocolate,
// vanilla, rose water… (مستلزمات الحلويات).
const _bakingNames = <String>[
  'دقيق', 'طحين', 'دقيق أبيض', 'دقيق أسمر', 'دقيق القمح الكامل',
  'نشا', 'نشا ذرة', 'نشاء',
  'سكر', 'سكر أبيض', 'سكر بني', 'سكر بودرة', 'سكر ناعم',
  'خميرة', 'خميرة فورية',
  'بيكنج باودر', 'بيكنج صودا',
  'فانيليا', 'فانيلا',
  'شوكولاتة', 'شوكولاتة داكنة', 'كاكاو',
  'ماء الورد', 'ماء الزهر',
  'لوز', 'لوز مطحون', 'جوز', 'جوز مطحون', 'جوز الهند', 'جوز الهند المبشور',
  'فستق', 'صنوبر', 'زبيب', 'سمسم',
  'رقائق شوكولاتة', 'جيلاتين', 'كريمة الخفق البودرة',
  // English.
  'flour', 'white flour', 'brown flour', 'whole wheat flour', 'cornstarch',
  'sugar', 'white sugar', 'brown sugar', 'powdered sugar', 'yeast',
  'instant yeast', 'baking powder', 'baking soda', 'vanilla', 'chocolate',
  'dark chocolate', 'cocoa', 'rose water', 'orange blossom water',
  'almonds', 'ground almonds', 'walnuts', 'pistachios', 'pine nuts',
  'raisins', 'shredded coconut', 'sesame', 'chocolate chips', 'gelatin',
];

// Frozen (مجمدات).
const _frozenNames = <String>[
  'مجمد', 'مجمدة', 'خضار مجمدة', 'خضروات مشكلة مجمدة', 'بازلاء مجمدة',
  'ذرة مجمدة', 'بطاطا مجمدة', 'بطاطس مجمدة', 'بطاطا مقلية مجمدة',
  'فطائر مجمدة', 'سمبوسة مجمدة', 'دجاج مجمد', 'فراخ مجمدة', 'لحم مجمد',
  'سمك مجمد', 'آيس كريم', 'بوظة', 'فراولة مجمدة', 'عجينة مجمدة',
  'كبة مجمدة', 'برجر مجمد', 'ناجتس دجاج',
  // English.
  'frozen vegetables', 'frozen peas', 'frozen corn', 'frozen potatoes',
  'french fries', 'frozen pastry', 'frozen chicken', 'frozen meat',
  'frozen fish', 'ice cream', 'frozen strawberries', 'frozen dough',
  'frozen kibbeh', 'chicken nuggets', 'frozen burger',
];

// Drinks (مشروبات). "ماء الورد"/"ماء الزهر" above override plain "ماء".
const _drinksNames = <String>[
  'ماء', 'مياه', 'مياه معدنية',
  'عصير', 'عصير برتقال', 'عصير تفاح', 'عصير مانجو', 'عصير ليمون',
  'شاي', 'شاي أخضر', 'قهوة', 'قهوة عربية', 'نسكافيه', 'قهوة تركية',
  'مشروب غازي', 'كولا', 'ببسي', 'سفن أب', 'مياه غازية', 'مشروب طاقة',
  'شراب', 'تمر هندي', 'عرقسوس', 'كركديه', 'ليموناضة',
  // English.
  'water', 'mineral water', 'juice', 'orange juice', 'apple juice', 'tea',
  'green tea', 'coffee', 'turkish coffee', 'soda', 'cola',
  'sparkling water', 'energy drink', 'lemonade', 'hibiscus tea',
  'tamarind juice', 'licorice drink',
];

List<(String, Aisle)> _entries(Aisle aisle, List<String> names) => [
  for (final n in names) (n, aisle),
];

/// The built-in aisle table (GRO-4): Arabic (Gulf, Levantine, Egyptian and
/// Maghrebi spellings) and English ingredient names, at least one real
/// entry for every aisle. Built once from the `const` word lists above.
final List<(String, Aisle)> _table = [
  ..._entries(Aisle.produce, _produceNames),
  ..._entries(Aisle.meat, _meatNames),
  ..._entries(Aisle.fish, _fishNames),
  ..._entries(Aisle.dairy, _dairyNames),
  ..._entries(Aisle.bakery, _bakeryNames),
  ..._entries(Aisle.grains, _grainsNames),
  ..._entries(Aisle.spices, _spicesNames),
  ..._entries(Aisle.pantry, _pantryNames),
  ..._entries(Aisle.baking, _bakingNames),
  ..._entries(Aisle.frozen, _frozenNames),
  ..._entries(Aisle.drinks, _drinksNames),
];

/// Word-count → {phrase (its normalized words joined by one space): aisle},
/// built once from [_table] on first use (ORG-4, GRO-4). A name is matched
/// by the longest phrase it contains, so a multi-word entry is checked, and
/// wins, before the single words inside it.
final Map<int, Map<String, Aisle>> _index = () {
  final index = <int, Map<String, Aisle>>{};
  for (final (phrase, aisle) in _table) {
    final words = _normalizedWords(phrase);
    if (words.isEmpty) continue;
    (index[words.length] ??= {})[words.join(' ')] = aisle;
  }
  return index;
}();

final int _maxPhraseWords = _index.keys.isEmpty
    ? 0
    : _index.keys.reduce((a, b) => a > b ? a : b);

/// [name] split into matchable words (ORG-4): [normalizeArabic] (which also
/// lower-cases Latin), a leading "ال" dropped from each word, then split on
/// (and so collapsing) whitespace. Digits are left as-is: they never match
/// a known phrase, but don't stop the rest of the name from matching.
List<String> _normalizedWords(String name) =>
    normalizeArabic(name)
        .split(RegExp(r'\s+'))
        .map(_dropAl)
        .where((w) => w.isNotEmpty)
        .toList();

/// Drops a leading Arabic "ال" ("the"), never touching a Latin word that
/// merely starts with the letters a/l ("almonds").
String _dropAl(String word) =>
    word.startsWith('ال') && word.length > 2 ? word.substring(2) : word;

/// The aisle an ingredient goes in (GRO-4): the built-in table of Arabic
/// and English names, matched on the normalized name (ORG-4) by its longest
/// known phrase. Unknown names go to [Aisle.other].
Aisle aisleFor(String name) {
  final words = _normalizedWords(name);
  for (var len = _maxPhraseWords; len >= 1; len--) {
    final byPhrase = _index[len];
    if (byPhrase == null) continue;
    for (var i = 0; i + len <= words.length; i++) {
      final aisle = byPhrase[words.sublist(i, i + len).join(' ')];
      if (aisle != null) return aisle;
    }
  }
  return Aisle.other;
}
