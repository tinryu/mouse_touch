# Quick Start Guide - Screen Remote Server

## Start Server

**Windows:**
```bash
cd d:\flutter\mouse_touch\remote_server
start_server.bat
```

**Or:**
```bash
npm start
```

## Server Info

- **WebSocket Port**: 9090
- **UDP Discovery Port**: 9091
- **Server IP**: Check console output

## Test the Server

Open `test_client.html` in your browser to test streaming.

## Connect from Flutter

```dart
// 1. UDP Discovery
final discoveryMessage = jsonEncode({'type': 'discover'});
await udpClient.send(
  discoveryMessage.codeUnits,
  Endpoint.broadcast(port: const Port(9091)),
);

// 2. WebSocket Connection
final channel = WebSocketChannel.connect(
  Uri.parse('ws://SERVER_IP:9090')
);

// 3. Start Streaming
channel.sink.add(jsonEncode({
  'type': 'start_stream',
  'fps': 10,
  'quality': 70,
  'monitor': 0
}));

// 4. Receive Frames
channel.stream.listen((data) {
  if (data is String) {
    final msg = jsonDecode(data);
    if (msg['type'] == 'frame_meta') {
      // Next message will be binary frame data
    }
  } else {
    // Binary JPEG image data
    final image = Image.memory(data);
  }
});
```

## Configuration

Edit `config.js` to change:
- Frame rate (5-30 FPS)
- Image quality (40-90%)
- Ports
- Resolution scaling

## Performance Settings

| Use Case | FPS | Quality | Bandwidth |
|----------|-----|---------|-----------|
| Low bandwidth | 5 | 50% | ~250 KB/s |
| Balanced | 10 | 70% | ~1 MB/s |
| High quality | 20 | 85% | ~3-4 MB/s |
