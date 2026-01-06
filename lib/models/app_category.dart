class AppCategory {
  final String id;
  final String name;
  final Set<String> paths;

  const AppCategory({
    required this.id,
    required this.name,
    required this.paths,
  });

  static const empty = AppCategory(
    id: '',
    name: '',
    paths: <String>{},
  );

  AppCategory copyWith({
    String? id,
    String? name,
    Set<String>? paths,
  }) {
    return AppCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      paths: paths ?? this.paths,
    );
  }
}
