# File Transfer App

A cross-platform file transfer application built with Flutter, supporting PC-to-PC, PC-to-Android, and Android-to-Android transfers.

## Features

✅ **Auto-Discovery**: Automatically discover devices on the same WiFi network using UDP broadcast  
✅ **Fast Transfers**: Optimized chunked transfer for large files (10MB chunks)  
✅ **Real-time Progress**: Live transfer progress with speed and ETA  
✅ **Transfer History**: SQLite database storing all transfer records  
✅ **Statistics**: Track total transfers, success rate, and data transferred  
✅ **Security**: Built-in encryption support (AES-256)  
✅ **Cross-Platform**: Works on Android and Windows (supports macOS and Linux)  
✅ **Modern UI**: Material Design 3 with clean interface  

## Architecture

### Client-Server Hybrid Model
Each device acts as both:
- **Server**: HTTP server (port 8080) to receive files
- **Client**: Sends files to other devices
- **Discovery**: UDP broadcast (port 8988) for device discovery

### Components

#### Services
- `DeviceDiscoveryService`: UDP-based device discovery
- `HttpServerService`: HTTP server for receiving files
- `TransferService`: File sending with progress tracking
- `DatabaseService`: SQLite for transfer history
- `EncryptionService`: Security and encryption utilities

#### UI Screens
- `HomeScreen`: Main dashboard with device discovery and active transfers
- `TransfersScreen`: View active, completed, and failed transfers
- `HistoryScreen`: Search and filter transfer history with statistics

#### Models
- `Device`: Represents a discovered device
- `Transfer`: Represents a file transfer with progress tracking

## Getting Started

### Prerequisites
- Flutter SDK 3.10.4 or higher
- For Android: Android SDK with API level 21+
- For Windows: Windows 10 or higher

### Installation

1. **Clone or navigate to the project**:
```bash
cd d:\flutter\mouse_touch\file_transfer_app
```

2. **Install dependencies**:
```bash
flutter pub get
```

3. **Run on Android**:
```bash
flutter run -d <device-id>
```

4. **Run on Windows**:
```bash
flutter run -d windows
```

### Build for Release

**Android APK**:
```bash
flutter build apk --release
```

**Windows Executable**:
```bash
flutter build windows --release
```

## Usage

### Sending Files

1. Ensure both devices are on the same WiFi network
2. Open the app on both devices
3. Wait for devices to appear in "Nearby Devices" list
4. Tap on a device or use the floating action button "Send File"
5. Select the file to send
6. Monitor transfer progress in real-time

### Receiving Files

Files are automatically received when another device sends to you. Received files are saved in:
- **Android**: `Documents/FileTransfer/Received/`
- **Windows**: `Documents/FileTransfer/Received/`

### Viewing History

- Tap the history icon in the app bar
- View statistics, search transfers, and filter by status
- Clear history using the delete sweep icon

## Network Configuration

### Firewall Rules (Windows)

You may need to allow the app through Windows Firewall:

```powershell
# Allow TCP port 8080 (HTTP server)
netsh advfirewall firewall add rule name="File Transfer App - TCP" dir=in action=allow protocol=TCP localport=8080

# Allow UDP port 8988 (Discovery)
netsh advfirewall firewall add rule name="File Transfer App - UDP" dir=in action=allow protocol=UDP localport=8988
```

## Technical Details

### Transfer Protocol

**Small Files (< 10MB)**:
- Single HTTP POST request
- Multipart form data
- Direct file upload

**Large Files (≥ 10MB)**:
- Chunked transfer (10MB per chunk)
- Multiple POST requests
- Resumable (future feature)

### Database Schema

```sql
CREATE TABLE transfers (
  id TEXT PRIMARY KEY,
  fileName TEXT NOT NULL,
  fileSize INTEGER NOT NULL,
  filePath TEXT,
  senderData TEXT,
  receiverData TEXT,
  status TEXT NOT NULL,
  bytesTransferred INTEGER DEFAULT 0,
  speed REAL DEFAULT 0.0,
  startTime TEXT NOT NULL,
  endTime TEXT,
  errorMessage TEXT
);
```

### Network Ports

- **TCP 8080**: HTTP server for file transfers
- **UDP 8988**: Device discovery broadcast

## Troubleshooting

### Devices Not Appearing

1. **Check WiFi**: Ensure both devices are on the same network
2. **Firewall**: Check firewall settings (especially on Windows)
3. **Network Type**: Some public WiFi networks block device-to-device communication
4. **Refresh**: Pull down to refresh the device list

### Transfer Failures

1. **Network Interruption**: Check WiFi signal strength
2. **Storage Space**: Ensure receiver has enough free space
3. **Permissions**: Grant all required storage permissions
4. **Retry**: Cancel and retry the transfer

### Permissions Issues (Android)

Go to **Settings → Apps → File Transfer → Permissions** and grant:
- Storage/Files permission
- Network access (automatically granted)

## Future Enhancements

- 🔄 Folder transfer support
- 📲 QR code pairing for easy connection
- 🔐 End-to-end encryption by default
- 🌐 Internet-based relay server for remote transfers
- ⏸️ Pause/resume transfer support
- 📁 Batch file selection
- 📱 iOS support
- 🗜️ File compression before transfer

## License

This project is open source and available for personal and commercial use.

## Credits

Developed with Flutter and ❤️
