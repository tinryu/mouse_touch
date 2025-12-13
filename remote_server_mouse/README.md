# Remote Server Mouse (Dart)

Merged implementation of Remote Desktop Server and Mouse Touch Server.
Combines screen streaming, mouse/keyboard control, and system tray integration into a single Flutter Windows application.

## Features

- ✅ **Unified Server** - Combines `mouse_touch_server` and `remote_server_mouse`
- ✅ **Mouse & Keyboard Control** - Using FFI & Win32 API (Move, Click, Scroll, Zoom, Type)
- ✅ **Screen Capture** - High-performance GDI-based capture
- ✅ **System Tray** - Minimize to tray, run in background
- ✅ **WebSocket Server** - Using `shelf` and `shelf_web_socket` (Port 8989)
- ✅ **UDP Discovery** - Automatic server detection (Port 8988)
- ✅ **Network Monitoring** - Quality tracking and adaptive streaming

## Configuration

Server settings in `lib/config.dart`:
- WebSocket port: **8989**
- UDP port: **8988**
- Default FPS: **10**
- Default Quality: **70%**

## Supported Clients

- **Screen Remote Client**: Supports screen streaming and full control.
- **Mouse Touch Client**: Legacy client support (Mouse/Keyboard only).

## Building

```bash
flutter pub get
flutter run -d windows
```

To build a release executable:
```bash
flutter build windows
```

