# Server-Blu-Remote

A Dart WebSocket server that receives Bluetooth signals from a Flutter remote mouse app and controls the Windows mouse accordingly.

## Features

- 🖱️ **Full Mouse Control**: Move cursor, click, double-click, scroll
- 🔌 **WebSocket Communication**: Real-time bidirectional communication
- 🪟 **Windows Native**: Uses Win32 API for precise mouse control
- 📡 **Remote Ready**: Works with Flutter app via Bluetooth → WebSocket bridge

## Architecture

```
[Remote Device] --Bluetooth--> [Flutter App] --WebSocket--> [Dart Server] --Win32 API--> [Windows Mouse]
```

The Flutter app handles Bluetooth communication with the remote device and forwards mouse commands to this server via WebSocket.

## Installation

1. **Install Dart SDK** (if not already installed):
   - Download from [dart.dev](https://dart.dev/get-dart)
   - Or use Chocolatey: `choco install dart-sdk`

2. **Clone/Navigate to project**:
   ```bash
   cd server-blu-remote
   ```

3. **Install dependencies**:
   ```bash
   dart pub get
   ```

## Usage

### Starting the Server

```bash
dart run bin/server.dart
```

The server will start on `ws://0.0.0.0:8080` by default.

To use a custom port:
```bash
set PORT=9090
dart run bin/server.dart
```

### Connecting from Flutter App

Connect to the WebSocket server using the computer's IP address:

```dart
final channel = WebSocketChannel.connect(
  Uri.parse('ws://192.168.1.100:8080'),
);
```

## Protocol Specification

### Message Format

All messages are JSON-encoded strings.

### Client → Server (Mouse Events)

```json
{
  "type": "move",
  "deltaX": 10.5,
  "deltaY": -5.2
}
```

#### Event Types

| Type | Description | Required Fields |
|------|-------------|----------------|
| `move` | Move cursor by delta | `deltaX`, `deltaY` |
| `leftClick` | Left mouse click | - |
| `rightClick` | Right mouse click | - |
| `doubleClick` | Double click | - |
| `scroll` | Scroll wheel | `scrollAmount` |
| `leftDown` | Press left button | - |
| `leftUp` | Release left button | - |
| `rightDown` | Press right button | - |
| `rightUp` | Release right button | - |

#### Examples

**Move Mouse:**
```json
{
  "type": "move",
  "deltaX": 15.0,
  "deltaY": -10.0
}
```

**Left Click:**
```json
{
  "type": "leftClick"
}
```

**Scroll:**
```json
{
  "type": "scroll",
  "scrollAmount": 2.0
}
```

### Server → Client (Responses)

**Success:**
```json
{
  "status": "success",
  "message": "Event processed",
  "event": { ... }
}
```

**Error:**
```json
{
  "status": "error",
  "message": "Failed to process event: ..."
}
```

**Connection:**
```json
{
  "status": "connected",
  "message": "Connected to server-blu-remote"
}
```

## Project Structure

```
server-blu-remote/
├── bin/
│   └── server.dart              # Main server entry point
├── lib/
│   ├── models/
│   │   └── mouse_event.dart     # Mouse event data models
│   ├── mouse_controller.dart    # Windows mouse control via Win32
│   └── signal_handler.dart      # WebSocket message processing
├── pubspec.yaml                 # Dependencies
└── README.md                    # This file
```

## Dependencies

- **shelf**: Web server framework
- **shelf_web_socket**: WebSocket support
- **win32**: Windows API bindings for mouse control
- **ffi**: Foreign Function Interface for native calls

## Development

### Testing with WebSocket Client

You can test the server using a WebSocket client like [websocat](https://github.com/vi/websocat):

```bash
websocat ws://localhost:8080
```

Then send test messages:
```json
{"type":"move","deltaX":50,"deltaY":0}
{"type":"leftClick"}
```

### Debugging

The server logs all incoming messages and actions to the console. Check the output for connection status and event processing.

## Troubleshooting

**Server won't start:**
- Check if port 8080 is already in use
- Try a different port using the `PORT` environment variable

**Mouse not moving:**
- Ensure the server is running with proper permissions
- Check that the Win32 API calls are working (Windows only)

**Connection refused:**
- Verify the IP address and port
- Check firewall settings
- Ensure both devices are on the same network

## License

This project is open source and available for personal and commercial use.

## Contributing

Feel free to submit issues and enhancement requests!
