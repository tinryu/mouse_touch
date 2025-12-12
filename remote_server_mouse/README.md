# Remote Server Mouse (Dart)

Pure Dart implementation of the remote desktop server, replacing the Node.js version.

## Features

- ✅ **Pure Dart** - No Node.js dependency
- ✅ **Mouse & Keyboard Control** - Using `bixat_key_mouse`
- ✅ **Screen Capture** - Using `screenshot` package
- ✅ **WebSocket Server** - Using `shelf` and `shelf_web_socket`
- ✅ **UDP Discovery** - Automatic server detection
- ✅ **Network Monitoring** - Quality tracking and adaptive streaming
- ✅ **Cross-platform** - Windows, macOS, Linux

## Requirements

- Dart SDK 3.9.2 or higher
- Flutter (for `bixat_key_mouse` package)

## Installation

```bash
# Install dependencies
dart pub get

# Or if using Flutter
flutter pub get
```

## Usage

### Start the headless CLI server

```bash
dart run
```

### Launch the Flutter desktop UI

The Flutter UI mirrors the visual design of the existing `mouse_touch_server`
desktop console, adding discovery data, codec details, and live logs.

```bash
# First ensure Flutter desktop tooling is enabled (only needs to be done once per machine)
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop

# Then run the UI (pick the platform available on your machine)
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

> **Note:** This repository already contains the Flutter `lib/main.dart` UI and
> logic. If you cloned the repo before these files existed, generate the missing
> platform scaffolding once via:
>
> ```bash
> flutter create --platforms=windows,macos,linux .
> ```
>
> This command only creates the `windows/`, `macos/`, and `linux/` runner
> folders. It will not overwrite existing Dart sources.

### Configuration

Edit `lib/config.dart` to change server settings:

- WebSocket port (default: 9090)
- UDP discovery port (default: 9091)
- FPS, quality, codec settings
- Network monitoring thresholds

## Comparison with Node.js Version

| Feature | Node.js | Dart | Status |
|---------|---------|------|--------|
| Mouse Control | ✅ robotjs | ✅ bixat_key_mouse | ✅ |
| Keyboard Control | ✅ robotjs | ✅ bixat_key_mouse | ✅ |
| Screen Capture | ✅ screenshot-desktop | ✅ screenshot | ✅ |
| Image Compression | ✅ sharp | ✅ image | ✅ |
| WebSocket Server | ✅ ws | ✅ shelf_web_socket | ✅ |
| UDP Discovery | ✅ dgram | ✅ dart:io | ✅ |
| Multi-codec | ✅ ffmpeg | ⏳ JPEG only | Partial |
| Adaptive Streaming | ✅ | ✅ | ✅ |
| Network Monitoring | ✅ | ✅ | ✅ |

## Protocol Compatibility

The Dart server uses the **same WebSocket protocol** as the Node.js version, so **no changes are needed** to the Flutter client.

## Building

### Compile to native executable

```bash
# Windows
dart compile exe bin/remote_server_mouse.dart -o remote_server_mouse.exe

# macOS/Linux
dart compile exe bin/remote_server_mouse.dart -o remote_server_mouse
```

## Troubleshooting

### bixat_key_mouse not working

Make sure you have Flutter installed, as `bixat_key_mouse` is a Flutter plugin:

```bash
flutter doctor
```

### Screenshot not capturing

On some systems, you may need to grant screen recording permissions:

- **macOS**: System Preferences → Security & Privacy → Screen Recording
- **Windows**: No special permissions needed
- **Linux**: May need X11 permissions

## Future Improvements

- [ ] Add VP8/VP9/H264 codec support
- [ ] Implement delta frame compression
- [ ] Add audio streaming
- [ ] Multi-monitor support improvements
- [ ] Hardware-accelerated encoding

## License

MIT
