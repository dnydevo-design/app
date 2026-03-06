import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PcBridgeService {
  HttpServer? _server;
  final int port = 8080;

  Future<String?> start() async {
    final router = Router();

    // Serve HTML Dashboard
    router.get('/', _dashboardHandler);

    // Upload Endpoint
    router.post('/upload', _uploadHandler);

    // Download Endpoint
    router.get('/download/<filename>', _downloadHandler);

    // Stream Endpoint (Placeholder for Gallery/Camera Live Stream)
    router.get('/stream', _streamHandler);

    // Start server pipeline
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, port);
      final ip = await _getLocalIpAddress();
      return 'http://$ip:$port';
    } catch (e) {
      return null;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<String> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Response _dashboardHandler(Request request) {
    const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SwiftBolt PC Bridge</title>
<style>
  :root { --bg: #0f172a; --card: #1e293b; --primary: #3b82f6; --text: #f8fafc; }
  body { font-family: 'Segoe UI', system-ui, sans-serif; text-align: center; background: var(--bg); color: var(--text); margin: 0; padding: 20px; }
  h1 { font-weight: 600; letter-spacing: -0.5px; margin-bottom: 30px; }
  .grid { display: flex; flex-wrap: wrap; justify-content: center; gap: 20px; }
  .card { background: var(--card); padding: 24px; border-radius: 16px; width: 320px; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); }
  h3 { margin-top: 0; color: #94a3b8; font-size: 1.1rem; }
  button { padding: 12px 24px; border-radius: 8px; border: none; background: var(--primary); color: white; font-weight: 600; cursor: pointer; transition: opacity 0.2s; width: 100%; margin-top: 10px; }
  button:hover { opacity: 0.9; }
  input[type="file"] { margin: 15px 0; width: 100%; padding: 10px; background: rgba(255,255,255,0.05); border-radius: 8px; }
  #stream-box { width: 100%; height: 200px; background: #000; border-radius: 8px; display:flex; align-items:center; justify-content:center; overflow:hidden; margin-top: 15px;}
  #uploadStatus { margin-top: 15px; font-size: 0.9em; color: #34d399; }
</style>
</head>
<body>
  <h1>⚡ SwiftBolt Dashboard</h1>
  <div class="grid">
    <div class="card">
      <h3>📤 Send to Phone</h3>
      <input type="file" id="filePicker">
      <button onclick="uploadFile()">Upload File</button>
      <div id="uploadStatus"></div>
    </div>
    <div class="card">
       <h3>📥 Download from Phone</h3>
       <button onclick="window.location.href='/download/sample.txt'">Download Sample</button>
       <p style="font-size: 0.8em; color: #64748b; margin-top: 15px;">Files in the transfer queue will appear here.</p>
    </div>
    <div class="card">
       <h3>🎥 Live Stream (Gallery/Camera)</h3>
       <div id="stream-box">
         <img id="livestream" src="/stream" style="width: 100%; height: 100%; object-fit: cover;" alt="Awaiting Stream..."/>
       </div>
    </div>
  </div>

  <script>
    async function uploadFile() {
      const fileInput = document.getElementById('filePicker');
      if (!fileInput.files.length) return;
      const file = fileInput.files[0];
      const status = document.getElementById('uploadStatus');
      status.style.color = '#fbbf24';
      status.innerText = "Uploading " + file.name + "...";

      try {
        const res = await fetch('/upload', {
          method: 'POST',
          headers: { 'File-Name': encodeURIComponent(file.name) },
          body: file
        });
        if (res.ok) {
          status.style.color = '#34d399';
          status.innerText = "✅ Uploaded successfully!";
        } else {
          throw new Error('Server error');
        }
      } catch (err) {
        status.style.color = '#f87171';
        status.innerText = "❌ Upload failed.";
      }
    }
  </script>
</body>
</html>
    ''';
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  }

  Future<Response> _uploadHandler(Request request) async {
    try {
      final headerName = request.headers['file-name'];
      final fileName = headerName != null ? Uri.decodeComponent(headerName) : 'upload_${DateTime.now().millisecondsSinceEpoch}';
      
      final directory = await getApplicationDocumentsDirectory();
      final filePath = p.join(directory.path, fileName);
      
      final file = File(filePath);
      final sink = file.openWrite();
      await request.read().pipe(sink);
      await sink.close();
      
      return Response.ok('Success');
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _downloadHandler(Request request) async {
    final fileName = request.params['filename'];
    return Response.ok('Welcome to SwiftBolt!\nThis is a dummy test file transferred via PC Bridge.', 
      headers: {
      'Content-Disposition': 'attachment; filename="$fileName"',
      'Content-Type': 'text/plain',
    });
  }

  Response _streamHandler(Request request) {
    // A placeholder representing a video/camera frame buffer
    return Response.ok('Stream Placeholder', headers: {'Content-Type': 'text/plain'});
  }
}
