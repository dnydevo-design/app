import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoConverterService {
  /// Converts a given video file to a high-quality MP3 format.
  /// 
  /// Returns the path of the generated MP3 file, or throws an exception on failure.
  Future<String> convertToMp3(File videoFile) async {
    try {
      final inputPath = videoFile.path;
      final fileNameWithoutExt = p.basenameWithoutExtension(inputPath);
      
      final documentsDir = await getApplicationDocumentsDirectory();
      // In a real app, we might want to save to external storage so the user can see it
      // Let's create an "ExtractedAudio" folder in the app's document dir
      final outputDir = Directory(p.join(documentsDir.path, 'ExtractedAudio'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      final outputPath = p.join(outputDir.path, '$fileNameWithoutExt.mp3');

      // If file already exists from a previous run, remove it
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      // High Quality MP3 Command:
      // -i : input file
      // -vn : strip video (no video)
      // -acodec libmp3lame : use mp3 encoder
      // -q:a 2 : high quality VBR (variable bit rate) ~190 kbps
      final command = '-i "$inputPath" -vn -acodec libmp3lame -q:a 2 "$outputPath"';

      debugPrint('Executing FFmpeg command: $command');

      final session = await FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('FFmpeg SUCCESS');
        } else if (ReturnCode.isCancel(returnCode)) {
          debugPrint('FFmpeg CANCEL');
        } else {
          final failStackTrace = await session.getFailStackTrace();
          debugPrint('FFmpeg ERROR: $failStackTrace');
        }
      });

      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      } else {
        throw Exception('FFmpeg failed with return code $returnCode');
      }
    } catch (e) {
      debugPrint('VideoConverterService Error: $e');
      rethrow;
    }
  }

  /// Cancels any ongoing FFmpeg operations
  Future<void> cancelConversions() async {
    await FFmpegKit.cancel();
  }
}
