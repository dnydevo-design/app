import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PcWebServer {
  HttpServer? _server;
  final int port = 8080;
  String _pinCode = "123"; 

  String get currentPin => _pinCode;

  // Broadcast channel for screen stream
  final List<WebSocketChannel> _clients = [];

  Future<String?> start() async {
    _pinCode = (Random().nextInt(900) + 100).toString(); // Generates 100-999
    
    final router = Router();

    // Serve HTML Dashboard
    router.get('/', _dashboardHandler);

    // Authentication
    router.post('/auth', _authHandler);

    // File Management
    router.get('/files', _getFilesHandler);
    router.post('/files', _uploadHandler);
    router.delete('/files/<filename>', _deleteFileHandler);
    router.get('/download/<filename>', _downloadHandler);

    // Control Events (Mouse/Keyboard)
    router.post('/control', _controlHandler);

    // WebSocket Stream
    router.get('/stream', webSocketHandler((webSocket) {
      _clients.add(webSocket);
      webSocket.stream.listen(
        (message) {
          // Handle incoming WS messages if necessary
        },
        onDone: () => _clients.remove(webSocket),
        onError: (e) => _clients.remove(webSocket),
      );
    }));

    // Start server pipeline
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_authMiddleware())
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
    for (var client in _clients) {
      client.sink.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  // A method to push new screen frames to connected web sockets
  void broadcastFrame(List<int> frameData) {
    for (var client in _clients) {
      client.sink.add(frameData);
    }
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

  Middleware _authMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.url.path == '' || request.url.path == 'auth') {
          return innerHandler(request); // Allow dashboard and auth endpoint
        }
        
        // Basic check for authenticated header
        final authHeader = request.headers['authorization'];
        if (authHeader != 'Bearer $_pinCode') {
          return Response.forbidden('Unauthorized');
        }
        
        return innerHandler(request);
      };
    };
  }

  Future<Response> _authHandler(Request request) async {
    final payload = await request.readAsString();
    try {
      final json = jsonDecode(payload);
      if (json['pin'] == _pinCode) {
        return Response.ok(jsonEncode({'token': _pinCode}), headers: {'Content-Type': 'application/json'});
      }
    } catch (_) {}
    return Response.forbidden('Invalid PIN');
  }

  Future<Response> _getFilesHandler(Request request) async {
    // Dummy implementation for files
    final files = [
      {'name': 'IMG_2023.jpg', 'type': 'photo', 'size': '2.4 MB'},
      {'name': 'VID_001.mp4', 'type': 'video', 'size': '45 MB'},
      {'name': 'com.myapp.apk', 'type': 'app', 'size': '15 MB'},
    ];
    return Response.ok(jsonEncode(files), headers: {'Content-Type': 'application/json'});
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

  Future<Response> _deleteFileHandler(Request request) async {
    // Dummy implementation
    return Response.ok('Deleted');
  }

  Future<Response> _downloadHandler(Request request) async {
    final fileName = request.params['filename'];
    return Response.ok('Dummy content for $fileName', 
      headers: {
      'Content-Disposition': 'attachment; filename="$fileName"',
      'Content-Type': 'application/octet-stream',
    });
  }

  Future<Response> _controlHandler(Request request) async {
    // Process incoming control events (mouse/keyboard)
    // final payload = await request.readAsString();
    // Pass event to AccessibilityService/Platform Channel
    return Response.ok('Event Received');
  }

  Response _dashboardHandler(Request request) {
    const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SwiftBolt Web Control</title>
<style>
  :root {
    --bg: #000000;
    --surface: #121212;
    --surface-hover: #1e1e1e;
    --primary: #8E2DE2;
    --primary-gradient: linear-gradient(135deg, #8E2DE2, #4A00E0);
    --text: #ffffff;
    --text-dim: #a0a0a0;
    --danger: #ef4444;
  }
  
  * { box-sizing: border-box; font-family: 'Inter', -apple-system, sans-serif; }
  
  body {
    background-color: var(--bg);
    color: var(--text);
    margin: 0;
    padding: 0;
    height: 100vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  /* PIN Overlay */
  #authOverlay {
    position: fixed; top: 0; left: 0; width: 100%; height: 100%;
    background: rgba(0,0,0,0.9); backdrop-filter: blur(10px);
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    z-index: 1000;
  }
  
  .auth-box {
    background: var(--surface); padding: 40px; border-radius: 20px;
    text-align: center; border: 1px solid #333;
  }

  input[type="password"] {
    background: #000; color: white; border: 1px solid #333;
    padding: 12px 20px; border-radius: 10px; font-size: 1.2rem;
    margin: 20px 0; outline: none; text-align: center; letter-spacing: 5px;
  }

  button.btn {
    background: var(--primary-gradient); color: white; border: none;
    padding: 12px 24px; border-radius: 10px; font-weight: 600; cursor: pointer;
    transition: opacity 0.2s;
  }
  button.btn:hover { opacity: 0.9; }

  /* Main Layout */
  header {
    background: var(--surface); padding: 15px 30px; display: flex; 
    justify-content: space-between; align-items: center;
    border-bottom: 1px solid #222;
  }
  
  .logo { font-size: 1.5rem; font-weight: 700; background: var(--primary-gradient); -webkit-background-clip: text; color: transparent; }
  
  .container { display: flex; flex: 1; overflow: hidden; }

  /* Left Panel - File Manager */
  .left-panel {
    flex: 1; padding: 20px; display: flex; flex-direction: column;
    border-right: 1px solid #222; overflow-y: auto;
  }

  .drop-zone {
    border: 2px dashed #333; border-radius: 15px; padding: 40px;
    text-align: center; color: var(--text-dim); margin-bottom: 20px;
    transition: border-color 0.2s, background 0.2s;
  }
  .drop-zone.dragover { border-color: var(--primary); background: rgba(142,45,226,0.1); }

  .file-filters {
    display: flex; gap: 10px; margin-bottom: 20px;
  }
  
  .filter-btn {
    background: #000; border: 1px solid #333; color: var(--text-dim);
    padding: 8px 16px; border-radius: 20px; cursor: pointer; transition: 0.2s;
  }
  .filter-btn.active { background: var(--primary-gradient); color: white; border-color: transparent; }

  .file-grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 15px;
  }
  
  .file-item {
    background: var(--surface); border: 1px solid #222; border-radius: 12px;
    padding: 15px; text-align: center; position: relative;
  }
  
  .file-item:hover { background: var(--surface-hover); }
  .file-icon { font-size: 2rem; margin-bottom: 10px; }
  .file-name { font-size: 0.9rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .file-actions { display: flex; justify-content: center; gap: 10px; margin-top: 10px; }
  .btn-icon { background: none; border: none; cursor: pointer; font-size: 1.2rem; transition: transform 0.2s; }
  .btn-icon:hover { transform: scale(1.1); }

  /* Right Panel - Remote Control */
  .right-panel {
    width: 350px; background: #000; display: flex; flex-direction: column;
  }

  .stream-container {
    flex: 1; border-bottom: 1px solid #222; display: flex; align-items: center; justify-content: center;
    position: relative; overflow: hidden; background: #080808;
  }
  
  #screenCanvas {
    max-width: 100%; max-height: 100%; object-fit: contain;
  }

  .control-panel { padding: 20px; background: var(--surface); }
  .status-indicator { display: flex; align-items: center; gap: 8px; font-size: 0.9rem; color: var(--text-dim); margin-bottom: 15px; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--danger); }
  .dot.connected { background: #10b981; }

  .nav-buttons { display: flex; justify-content: space-around; background: #000; border-radius: 12px; padding: 10px; }
  .nav-btn { background: none; border: none; font-size: 1.5rem; color: var(--text-dim); cursor: pointer; }
  .nav-btn:hover { color: white; }

</style>
</head>
<body>

  <!-- Auth Overlay -->
  <div id="authOverlay">
    <div class="auth-box">
      <h2>Device Locked</h2>
      <p style="color: var(--text-dim)">Enter PIN to access SwiftBolt Dashboard</p>
      <input type="password" id="pinInput" placeholder="•••" maxlength="3"><br>
      <button class="btn" onclick="authenticate()">Unlock</button>
      <p id="authError" style="color: var(--danger); display:none; margin-top: 10px;">Invalid PIN</p>
    </div>
  </div>

  <header>
    <div class="logo">SwiftBolt Dashboard</div>
    <button class="btn" onclick="logout()">Disconnect</button>
  </header>

  <div class="container">
    
    <!-- Left Panel: File Manager -->
    <div class="left-panel">
      <div class="drop-zone" id="dropZone">
        <h3>Drag & Drop Files Here</h3>
        <p>or click to browse</p>
        <input type="file" id="fileInput" style="display:none">
      </div>
      
      <div class="file-filters">
        <button class="filter-btn active">All</button>
        <button class="filter-btn">Photos</button>
        <button class="filter-btn">Videos</button>
        <button class="filter-btn">Apps</button>
      </div>

      <div class="file-grid" id="fileGrid">
        <!-- Files populated via JS -->
      </div>
    </div>

    <!-- Right Panel: Remote Control & Stream -->
    <div class="right-panel">
      <div class="stream-container" id="streamContainer">
        <canvas id="screenCanvas"></canvas>
      </div>
      <div class="control-panel">
        <div class="status-indicator">
          <div class="dot" id="wsStatus"></div>
          <span id="wsText">Stream Disconnected</span>
        </div>
        <div class="nav-buttons">
          <button class="nav-btn" onclick="sendControl('back')">◀</button>
          <button class="nav-btn" onclick="sendControl('home')">⏺</button>
          <button class="nav-btn" onclick="sendControl('recent')">⬛</button>
        </div>
        <p style="font-size: 0.8rem; color: #555; text-align: center; margin-top: 15px;">
          Click and drag on the screen above to send touch events. Type to send keyboard input.
        </p>
      </div>
    </div>

  </div>

  <script>
    let token = '';
    let ws = null;
    let canvas = document.getElementById('screenCanvas');
    let ctx = canvas.getContext('2d');

    // Authentication
    async function authenticate() {
      const pin = document.getElementById('pinInput').value;
      const res = await fetch('/auth', { method: 'POST', body: JSON.stringify({pin}) });
      if(res.ok) {
        const data = await res.json();
        token = data.token;
        document.getElementById('authOverlay').style.display = 'none';
        loadFiles();
        connectWebSocket();
      } else {
        document.getElementById('authError').style.display = 'block';
      }
    }

    function logout() { location.reload(); }

    // API Header helper
    function getHeaders() { return { 'Authorization': 'Bearer ' + token }; }

    // Drag & Drop Upload
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');

    dropZone.addEventListener('click', () => fileInput.click());
    dropZone.addEventListener('dragover', (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
    dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
    dropZone.addEventListener('drop', (e) => {
      e.preventDefault(); dropZone.classList.remove('dragover');
      if(e.dataTransfer.files.length) uploadFile(e.dataTransfer.files[0]);
    });
    fileInput.addEventListener('change', (e) => {
      if(e.target.files.length) uploadFile(e.target.files[0]);
    });

    async function uploadFile(file) {
      dropZone.innerHTML = `<h3>Uploading \${file.name}...</h3>`;
      try {
        await fetch('/files', {
          method: 'POST',
          headers: { ...getHeaders(), 'File-Name': encodeURIComponent(file.name) },
          body: file
        });
        setTimeout(() => loadFiles(), 500);
      } catch(e) { console.error('Upload failed', e); }
      dropZone.innerHTML = `<h3>Drag & Drop Files Here</h3><p>or click to browse</p>`;
    }

    // File Manager
    async function loadFiles() {
      const res = await fetch('/files', { headers: getHeaders() });
      if(!res.ok) return;
      const files = await res.json();
      const grid = document.getElementById('fileGrid');
      grid.innerHTML = files.map(f => {
        let icon = f.type==='photo'?'🖼️':f.type==='video'?'🎬':'📱';
        return `
          <div class="file-item">
            <div class="file-icon">\${icon}</div>
            <div class="file-name" title="\${f.name}">\${f.name}</div>
            <div style="font-size:0.8rem; color:#666">\${f.size}</div>
            <div class="file-actions">
              <button class="btn-icon" onclick="downloadFile('\${f.name}')">⬇️</button>
              <button class="btn-icon" onclick="deleteFile('\${f.name}')">🗑️</button>
            </div>
          </div>
        `;
      }).join('');
    }

    function downloadFile(name) {
      window.open('/download/' + encodeURIComponent(name));
    }

    async function deleteFile(name) {
      if(confirm('Delete ' + name + '?')) {
        await fetch('/files/' + encodeURIComponent(name), { method: 'DELETE', headers: getHeaders() });
        loadFiles();
      }
    }

    // WebSocket Stream
    function connectWebSocket() {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = protocol + '//' + window.location.host + '/stream';
      
      ws = new WebSocket(wsUrl);
      ws.binaryType = "blob";

      ws.onopen = () => {
        document.getElementById('wsStatus').classList.add('connected');
        document.getElementById('wsText').innerText = 'Stream Live';
      };

      ws.onmessage = async (event) => {
        // Draw binary frame to canvas
        const blob = event.data;
        const bitmap = await createImageBitmap(blob);
        canvas.width = bitmap.width;
        canvas.height = bitmap.height;
        ctx.drawImage(bitmap, 0, 0);
      };

      ws.onclose = () => {
        document.getElementById('wsStatus').classList.remove('connected');
        document.getElementById('wsText').innerText = 'Stream Disconnected';
        setTimeout(connectWebSocket, 3000); // Auto reconnect
      };
    }

    // Remote Control Listeners
    async function sendControl(action, data={}) {
      if(!token) return;
      await fetch('/control', {
        method: 'POST',
        headers: { ...getHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, ...data })
      });
    }

    const streamContainer = document.getElementById('streamContainer');
    let isDragging = false;

    streamContainer.addEventListener('mousedown', (e) => {
      isDragging = true;
      sendMouse('down', e);
    });
    streamContainer.addEventListener('mousemove', (e) => {
      if(isDragging) sendMouse('move', e);
    });
    streamContainer.addEventListener('mouseup', (e) => {
      isDragging = false;
      sendMouse('up', e);
    });

    function sendMouse(type, e) {
      const rect = streamContainer.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width;
      const y = (e.clientY - rect.top) / rect.height;
      sendControl('mouse', { type, x, y });
    }

    document.addEventListener('keydown', (e) => {
      // Don't capture typing in the PIN box
      if(e.target.tagName !== 'INPUT') {
        sendControl('keyboard', { key: e.key, code: e.code });
      }
    });

  </script>
</body>
</html>
    ''';
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  }
}
