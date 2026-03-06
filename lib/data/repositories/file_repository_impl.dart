import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/utils/file_utils.dart';
import '../../domain/entities/file_item.dart';
import '../../domain/repositories/file_repository.dart';

/// Implementation of [FileRepository] for device file browsing and categorization.
class FileRepositoryImpl implements FileRepository {
  @override
  Future<List<FileItem>> getFilesByCategory(FileCategory category) async {
    final allFiles = await _scanStorageFiles();
    return allFiles
        .where((f) => FileUtils.categorize(f.path) == category)
        .toList();
  }

  @override
  Future<List<FileItem>> getInstalledApks() async {
    return getFilesByCategory(FileCategory.apk);
  }

  @override
  Future<List<FileItem>> getMediaFiles() async {
    final allFiles = await _scanStorageFiles();
    return allFiles.where((f) {
      final cat = FileUtils.categorize(f.path);
      return cat == FileCategory.image ||
          cat == FileCategory.video ||
          cat == FileCategory.audio;
    }).toList();
  }

  @override
  Future<List<FileItem>> getDocuments() async {
    return getFilesByCategory(FileCategory.document);
  }

  @override
  Future<List<FileItem>> searchFiles(String query) async {
    final allFiles = await _scanStorageFiles();
    final lowerQuery = query.toLowerCase();
    return allFiles
        .where((f) => f.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  @override
  Future<String> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir.path;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  @override
  Future<String?> generateThumbnail(String filePath) async {
    // Thumbnail generation would use platform-specific APIs
    // or packages like video_thumbnail / image
    // Returning null signals the UI to use a generic icon
    return null;
  }

  /// Scans common storage directories for files.
  Future<List<FileItem>> _scanStorageFiles() async {
    final files = <FileItem>[];
    final dirs = <String>[];

    if (Platform.isAndroid) {
      dirs.addAll([
        '/storage/emulated/0/Download',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Pictures',
      ]);
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dirs.add(docDir.path);
    }

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              files.add(FileItem(
                path: entity.path,
                name: FileUtils.getFileName(entity.path),
                size: stat.size,
                category: FileUtils.categorize(entity.path),
                mimeType: FileUtils.getMimeType(entity.path),
                modifiedAt: stat.modified,
              ));
            } catch (_) {
              // Skip files we can't access
            }
          }
        }
      } catch (_) {
        // Skip directories we can't access
      }
    }

    // Sort by modification time (newest first)
    files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }
}
