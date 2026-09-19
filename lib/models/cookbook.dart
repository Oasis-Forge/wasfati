/// A user-named cookbook (ORG-1). A recipe can be in any number of them;
/// deleting a cookbook never deletes its recipes.
class Cookbook {
  const Cookbook({
    required this.id,
    required this.name,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  static const maxName = 60; // ORG-1

  final String id;
  final String name;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'position': position,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  factory Cookbook.fromMap(Map<String, Object?> m) => Cookbook(
    id: m['id']! as String,
    name: m['name']! as String,
    position: m['position']! as int,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deletedAt: _date(m['deleted_at']),
  );
}

/// A free-text tag (ORG-2): 1–30 characters, up to 20 per recipe.
class Tag {
  const Tag({required this.id, required this.name});
  static const maxName = 30;
  static const maxPerRecipe = 20;
  final String id;
  final String name;
}

DateTime? _date(Object? ms) => ms == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
