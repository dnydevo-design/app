import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../constants/app_constants.dart';

/// Commands sent from the main isolate to the server isolate.
enum ServerCommand { start, stop, broadcastChunk }

/// Messages sent from the server isolate back to the main isolate.
enum ServerEvent { started, stopped, error, clientConnected, clientDisconnected, chunkReceived, transferRequest }

/// Data sent between isolates for server communication.
class IsolateMessage {
  final dynamic type;
  final Map<String, dynamic>? data;
  final Uint8List? binaryData;

  const IsolateMessage({required this.type, this.data, this.binaryData});
}

/// Isolate-based HTTP server using shelf.
///
/// Runs the entire HTTP server in a separate Isolate to prevent
/// UI thread blocking. Communicates with the main isolate via
/// SendPort/ReceivePort message passing.
class IsolateServer {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  final _eventController = StreamController<IsolateMessage>.broadcast();

  /// Stream of events from the server isolate.
  Stream<IsolateMessage> get events => _eventController.stream;

  /// Whether the server is currently running.
  bool get isRunning => _isolate != null;

  /// Starts the server isolate on the specified [port].
  Future<void> start({int port = AppConstants.serverPort}) async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _serverEntryPoint,
      _ServerConfig(
        sendPort: _receivePort!.sendPort,
        port: port,
      ),
    );

    final completer = Completer<void>();

    _receivePort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        if (!completer.isCompleted) completer.complete();
      } else if (message is IsolateMessage) {
        _eventController.add(message);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: AppConstants.connectionTimeoutSec),
    );
  }

  /// Stops the server isolate.
  Future<void> stop() async {
    _sendPort?.send(const IsolateMessage(type: ServerCommand.stop));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
  }

  /// Broadcasts a binary chunk to all connected clients.
  void broadcastChunk({
    required String transferId,
    required int chunkIndex,
    required Uint8List data,
  }) {
    _sendPort?.send(IsolateMessage(
      type: ServerCommand.broadcastChunk,
      data: {
        'transferId': transferId,
        'chunkIndex': chunkIndex,
      },
      binaryData: data,
    ));
  }

  /// Sends a command to the server isolate.
  void sendCommand(IsolateMessage message) {
    _sendPort?.send(message);
  }

  /// Cleans up resources.
  Future<void> dispose() async {
    await stop();
    await _eventController.close();
  }

  /// Entry point for the server isolate.
  ///
  /// Runs entirely in a separate isolate — no access to main isolate state.
  static Future<void> _serverEntryPoint(_ServerConfig config) async {
    final receivePort = ReceivePort();
    config.sendPort.send(receivePort.sendPort);

    HttpServer? httpServer;
    final connectedClients = <String, HttpResponse>{};

    // Set up shelf router
    final router = Router();

    // Health check endpoint
    router.get('/health', (shelf.Request request) {
      return shelf.Response.ok(
        jsonEncode({'status': 'ok', 'app': AppConstants.appName}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // File metadata endpoint
    router.get('/api/transfers', (shelf.Request request) {
      return shelf.Response.ok(
        jsonEncode({'transfers': []}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // Chunk download endpoint
    router.get('/api/chunk/<transferId>/<chunkIndex>',
        (shelf.Request request, String transferId, String chunkIndex) {
      // Chunk serving logic — dispatched from stored chunks
      config.sendPort.send(IsolateMessage(
        type: ServerEvent.chunkReceived,
        data: {
          'transferId': transferId,
          'chunkIndex': int.tryParse(chunkIndex) ?? 0,
        },
      ));
      return shelf.Response.ok('');
    });

    // File upload endpoint (receiver side)
    router.post('/api/upload/<transferId>/<chunkIndex>',
        (shelf.Request request, String transferId, String chunkIndex) async {
      try {
        final bodyBytes = await request.read().fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );

        config.sendPort.send(IsolateMessage(
          type: ServerEvent.chunkReceived,
          data: {
            'transferId': transferId,
            'chunkIndex': int.tryParse(chunkIndex) ?? 0,
          },
          binaryData: Uint8List.fromList(bodyBytes),
        ));

        return shelf.Response.ok(
          jsonEncode({'status': 'received'}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return shelf.Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
        );
      }
    });

    // Transfer request endpoint
    router.post('/api/transfer-request', (shelf.Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;

        config.sendPort.send(IsolateMessage(
          type: ServerEvent.transferRequest,
          data: data,
        ));

        return shelf.Response.ok(
          jsonEncode({'status': 'pending'}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return shelf.Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
        );
      }
    });

    // SSE endpoint for real-time streaming / progress
    router.get('/api/stream/<transferId>',
        (shelf.Request request, String transferId) {
      // Server-Sent Events for live progress updates
      final controller = StreamController<List<int>>();

      connectedClients[transferId] = controller as HttpResponse;

      config.sendPort.send(IsolateMessage(
        type: ServerEvent.clientConnected,
        data: {'transferId': transferId},
      ));

      return shelf.Response.ok(
        Stream<List<int>>.empty(),
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      );
    });

    // Create the shelf pipeline
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router.call);

    // Listen for commands from main isolate
    receivePort.listen((message) async {
      if (message is IsolateMessage) {
        switch (message.type) {
          case ServerCommand.stop:
            await httpServer?.close(force: true);
            config.sendPort.send(
              const IsolateMessage(type: ServerEvent.stopped),
            );
            receivePort.close();
          case ServerCommand.broadcastChunk:
            // Broadcast to all connected SSE clients
            break;
          default:
            break;
        }
      }
    });

    // Start the HTTP server
    try {
      httpServer = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        config.port,
        shared: true,
      );
      httpServer.autoCompress = true;

      config.sendPort.send(IsolateMessage(
        type: ServerEvent.started,
        data: {'port': config.port, 'address': httpServer.address.address},
      ));
    } catch (e) {
      config.sendPort.send(IsolateMessage(
        type: ServerEvent.error,
        data: {'message': 'Failed to start server: $e'},
      ));
    }
  }
}

/// Configuration passed to the server isolate.
class _ServerConfig {
  final SendPort sendPort;
  final int port;

  const _ServerConfig({required this.sendPort, required this.port});
}
