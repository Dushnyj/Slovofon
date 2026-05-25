class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.bookVersionId,
    required this.chapterId,
    required this.positionMs,
    required this.title,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String bookVersionId;
  final String chapterId;
  final int positionMs;
  final String title;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
