import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../constants/app_constants.dart';
import '../utils/crc32_util.dart';

/// Events sent from the download isolate to the main isolate.
enum DownloadEvent { progress, chunkComplete, complete, error, paused, resumed }

/// Progress data from the download isolate.
class DownloadProgress {
  final String transferId;
  final int chunkIndex;
  final int totalChunks;
  final int bytesReceived;
  final int totalBytes;
  final double speedBytesPerSec;
  final DownloadEvent event;
  final String? errorMessage;
  final Uint8List? chunkData;

  const DownloadProgress({
    required this.transferId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.bytesReceived,
    required this.totalBytes,
    required this.speedBytesPerSec,
    required this.event,
    this.errorMessage,
    this.chunkData,
  });

  double get progressFraction =>
      totalBytes > 0 ? bytesReceived / totalBytes : 0.0;
}

/// Configuration for the download isolate.
class DownloadConfig {
  final SendPort sendPort;
  final String transferId;
  final String serverHost;
  final int serverPort;
  final int totalChunks;
  final int totalBytes;
  final int chunkSize;
  final int startChunk;
  final Map<int, int> expectedChecksums;

  const DownloadConfig({
    required this.sendPort,
    required this.transferId,
    required this.serverHost,
    required this.serverPort,
    required this.totalChunks,
    required this.totalBytes,
    required this.chunkSize,
    this.startChunk = 0,
    this.expectedChecksums = const {},
  });
}

/// Isolate-based file download client.
///
/// Runs file chunk downloads in a separate isolate to avoid
/// blocking the UI thread. Supports pause/resume, CRC32 verification,
/// and speed measurement.
class IsolateClient {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _commandPort;

  final _progressController = StreamController<DownloadProgress>.broadcast();

  /// Stream of download progress updates.
  Stream<DownloadProgress> get progress => _progressController.stream;

  /// Whether a download is active.
  bool get isActive => _isolate != null;

  /// Starts downloading chunks from the [serverHost] in a separate isolate.
  ///
  /// [startChunk] allows resuming from a specific chunk offset.
  Future<void> startDownload({
    required String transferId,
    required String serverHost,
    int serverPort = AppConstants.serverPort,
    required int totalChunks,
    required int totalBytes,
    int chunkSize = AppConstants.chunkSize,
    int startChunk = 0,
    Map<int, int> expectedChecksums = const {},
  }) async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _downloadEntryPoint,
      DownloadConfig(
        sendPort: _receivePort!.sendPort,
        transferId: transferId,
        serverHost: serverHost,
        serverPort: serverPort,
        totalChunks: totalChunks,
        totalBytes: totalBytes,
        chunkSize: chunkSize,
        startChunk: startChunk,
        expectedChecksums: expectedChecksums,
      ),
    );

    _receivePort!.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
      } else if (message is DownloadProgress) {
        _progressController.add(message);
      }
    });
  }

  /// Pauses the current download.
  void pause() {
    _commandPort?.send('pause');
  }

  /// Resumes the current download.
  void resume() {
    _commandPort?.send('resume');
  }

  /// Cancels and cleans up the download isolate.
  Future<void> cancel() async {
    _commandPort?.send('cancel');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _cleanup();
  }

  void _cleanup() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _commandPort = null;
  }

  /// Disposes all resources.
  Future<void> dispose() async {
    await cancel();
    await _progressController.close();
  }

  /// Entry point for the download isolate.
  static Future<void> _downloadEntryPoint(DownloadConfig config) async {
    final commandPort = ReceivePort();
    config.sendPort.send(commandPort.sendPort);

    var isPaused = false;
    var isCancelled = false;

    // Listen for pause/resume/cancel commands
    commandPort.listen((message) {
      if (message == 'pause') isPaused = true;
      if (message == 'resume') isPaused = false;
      if (message == 'cancel') isCancelled = true;
    });

    final httpClient = HttpClient();
    httpClient.connectionTimeout =
        const Duration(seconds: AppConstants.connectionTimeoutSec);

    var totalBytesReceived = 0;
    final stopwatch = Stopwatch()..start();

    for (var chunkIndex = config.startChunk;
        chunkIndex < config.totalChunks;
        chunkIndex++) {
      if (isCancelled) break;

      // Wait while paused
      while (isPaused && !isCancelled) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (isCancelled) break;

      var retries = 0;
      var chunkSuccess = false;

      while (retries < AppConstants.maxRetries && !chunkSuccess) {
        try {
          final url = Uri.parse(
            'http://${config.serverHost}:${config.serverPort}'
            '/api/chunk/${config.transferId}/$chunkIndex',
          );

          final request = await httpClient.getUrl(url);
          final response = await request.close();

          if (response.statusCode == 200) {
            final chunkBytes = <int>[];
            await for (final bytes in response) {
              chunkBytes.addAll(bytes);
            }

            final chunkData = Uint8List.fromList(chunkBytes);

            // CRC32 verification
            if (config.expectedChecksums.containsKey(chunkIndex)) {
              final expectedCrc = config.expectedChecksums[chunkIndex]!;
              final actualCrc = Crc32Util.compute(chunkData);
              if (actualCrc != expectedCrc) {
                retries++;
                if (retries >= AppConstants.maxRetries) {
                  config.sendPort.send(DownloadProgress(
                    transferId: config.transferId,
                    chunkIndex: chunkIndex,
                    totalChunks: config.totalChunks,
                    bytesReceived: totalBytesReceived,
                    totalBytes: config.totalBytes,
                    speedBytesPerSec: 0,
                    event: DownloadEvent.error,
                    errorMessage:
                        'CRC32 mismatch on chunk $chunkIndex after $retries retries',
                  ));
                }
                continue;
              }
            }

            totalBytesReceived += chunkData.length;
            final elapsedSec = stopwatch.elapsedMilliseconds / 1000;
            final speed = elapsedSec > 0 ? totalBytesReceived / elapsedSec : 0;

            config.sendPort.send(DownloadProgress(
              transferId: config.transferId,
              chunkIndex: chunkIndex,
              totalChunks: config.totalChunks,
              bytesReceived: totalBytesReceived,
              totalBytes: config.totalBytes,
              speedBytesPerSec: speed.toDouble(),
              event: DownloadEvent.chunkComplete,
              chunkData: chunkData,
            ));

            chunkSuccess = true;
          } else {
            retries++;
            await Future<void>.delayed(
              const Duration(milliseconds: AppConstants.retryDelayMs),
            );
          }
        } on SocketException catch (e) {
          retries++;
          if (retries >= AppConstants.maxRetries) {
            config.sendPort.send(DownloadProgress(
              transferId: config.transferId,
              chunkIndex: chunkIndex,
              totalChunks: config.totalChunks,
              bytesReceived: totalBytesReceived,
              totalBytes: config.totalBytes,
              speedBytesPerSec: 0,
              event: DownloadEvent.error,
              errorMessage: 'Connection failed on chunk $chunkIndex: $e',
            ));
          }
          await Future<void>.delayed(
            const Duration(milliseconds: AppConstants.retryDelayMs),
          );
        } catch (e) {
          retries++;
          if (retries >= AppConstants.maxRetries) {
            config.sendPort.send(DownloadProgress(
              transferId: config.transferId,
              chunkIndex: chunkIndex,
              totalChunks: config.totalChunks,
              bytesReceived: totalBytesReceived,
              totalBytes: config.totalBytes,
              speedBytesPerSec: 0,
              event: DownloadEvent.error,
              errorMessage: 'Unexpected error on chunk $chunkIndex: $e',
            ));
          }
          await Future<void>.delayed(
            const Duration(milliseconds: AppConstants.retryDelayMs),
          );
        }
      }
    }

    if (!isCancelled) {
      config.sendPort.send(DownloadProgress(
        transferId: config.transferId,
        chunkIndex: config.totalChunks - 1,
        totalChunks: config.totalChunks,
        bytesReceived: totalBytesReceived,
        totalBytes: config.totalBytes,
        speedBytesPerSec: 0,
        event: DownloadEvent.complete,
      ));
    }

    stopwatch.stop();
    httpClient.close();
    commandPort.close();
  }
}
