import '../../core/utils/file_utils.dart';
import '../entities/file_item.dart';

/// Abstract repository contract for file management.
abstract class FileRepository {
  /// Gets all files categorized by type.
  Future<List<FileItem>> getFilesByCategory(FileCategory category);

  /// Gets all installed APKs (Android).
  Future<List<FileItem>> getInstalledApks();

  /// Gets all media files with thumbnails.
  Future<List<FileItem>> getMediaFiles();

  /// Gets all document files.
  Future<List<FileItem>> getDocuments();

  /// Searches files by name.
  Future<List<FileItem>> searchFiles(String query);

  /// Gets the download directory path.
  Future<String> getDownloadDirectory();

  /// Generates a thumbnail for a media file.
  Future<String?> generateThumbnail(String filePath);
}
