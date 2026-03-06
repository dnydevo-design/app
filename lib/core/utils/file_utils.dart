import 'dart:io';

import 'package:mime/mime.dart';

/// File utility functions for categorization, formatting, and MIME detection.
abstract final class FileUtils {
  /// Formats [bytes] into a human-readable string (e.g., "1.5 GB").
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Returns the MIME type for the given [filePath].
  static String getMimeType(String filePath) {
    return lookupMimeType(filePath) ?? 'application/octet-stream';
  }

  /// Determines the category of a file based on its extension.
  static FileCategory categorize(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();

    if (ext == 'apk' || ext == 'xapk' || ext == 'aab') {
      return FileCategory.apk;
    }

    if (_imageExtensions.contains(ext)) return FileCategory.image;
    if (_videoExtensions.contains(ext)) return FileCategory.video;
    if (_audioExtensions.contains(ext)) return FileCategory.audio;
    if (_documentExtensions.contains(ext)) return FileCategory.document;

    return FileCategory.other;
  }

  /// Checks if a file exists at [path].
  static Future<bool> fileExists(String path) => File(path).exists();

  /// Gets file size in bytes.
  static Future<int> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  /// Calculates total chunk count for a file of [totalBytes].
  static int calculateChunkCount(int totalBytes, int chunkSize) {
    return (totalBytes + chunkSize - 1) ~/ chunkSize;
  }

  /// Returns the file name from a full path.
  static String getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }

  /// Returns the file extension without the dot.
  static String getExtension(String filePath) {
    final parts = filePath.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  static const _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'heic', 'heif',
  };

  static const _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp',
  };

  static const _audioExtensions = {
    'mp3', 'wav', 'aac', 'ogg', 'flac', 'wma', 'm4a', 'opus',
  };

  static const _documentExtensions = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt',
    'csv', 'rtf', 'odt', 'ods', 'odp',
  };
}

/// File category types for the file browser.
enum FileCategory {
  apk,
  image,
  video,
  audio,
  document,
  other,
}
