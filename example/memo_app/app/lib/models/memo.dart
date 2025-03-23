/// Data model for memo
class Memo {
  /// Constructor
  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  /// Create Memo from JSON
  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Unique ID for the memo
  final String id;

  /// Memo title
  final String title;

  /// Memo content
  final String content;

  /// Creation date and time of the memo
  final DateTime createdAt;

  /// Convert Memo to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Clone Memo and change some properties
  Memo copyWith({String? title, String? content}) {
    return Memo(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }
}
