import 'package:equatable/equatable.dart';

import '../../core/utils/file_utils.dart';

/// Represents a file item in the file browser.
class FileItem extends Equatable {
  final String path;
  final String name;
  final int size;
  final FileCategory category;
  final String mimeType;
  final DateTime modifiedAt;
  final String? thumbnailPath;

  const FileItem({
    required this.path,
    required this.name,
    required this.size,
    required this.category,
    required this.mimeType,
    required this.modifiedAt,
    this.thumbnailPath,
  });

  /// Human-readable file size string.
  String get formattedSize => FileUtils.formatFileSize(size);

  /// File extension without the dot.
  String get extension => FileUtils.getExtension(path);

  /// Whether this is a media file (image/video/audio).
  bool get isMedia =>
      category == FileCategory.image ||
      category == FileCategory.video ||
      category == FileCategory.audio;

  @override
  List<Object?> get props => [path, name, size];
}
