class Book {
  final int id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final List<String> genres;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    this.genres = const [],
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json["id"],
      title: json["title"],
      author: json["author"],
      description: json["description"],
      coverUrl: json["coverUrl"],
      genres: (json["genres"] as List<dynamic>?)
              ?.map((e) => e["name"] as String)
              .toList() ??
          const [],
    );
  }
}
