import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:path_provider/path_provider.dart';
import 'server/mouse_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MouseTouchServerApp());
}

class MouseTouchServerApp extends StatelessWidget {
  const MouseTouchServerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mouse Touch Server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ServerHomePage(),
    );
  }
}

class ServerHomePage extends StatefulWidget {
  const ServerHomePage({super.key});

  @override
  State<ServerHomePage> createState() => _ServerHomePageState();
}

class _ServerHomePageState extends State<ServerHomePage> with WindowListener {
  MouseServer? _server;
  bool _isRunning = false;
  final List<String> _logs = [];
  String _localIP = 'Loading...';
  bool _showLogs = true;

  final SystemTray _systemTray = SystemTray();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    _initSystemTray();
    _getLocalIP();
  }

  Future<void> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? localIP;

      // Filter out virtual adapters and prioritize real network interfaces
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();

        // Skip virtual adapters
        if (name.contains('virtualbox') ||
            name.contains('vmware') ||
            name.contains('hyper-v') ||
            name.contains('vethernet') ||
            name.contains('vboxnet') ||
            name.contains('radmin') ||
            name.contains('vpn') ||
            name.contains('docker')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            // Prefer 192.168.x.x or 10.x.x.x addresses
            if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
              localIP = ip;
              break;
            } else {
              localIP ??= ip;
            }
          }
        }
        if (localIP != null &&
            (localIP.startsWith('192.168.') || localIP.startsWith('10.'))) {
          break;
        }
      }

      setState(() {
        _localIP = localIP ?? 'No IP found';
      });
    } catch (e) {
      setState(() {
        _localIP = 'Error: $e';
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(
        0,
        '[${DateTime.now().toString().substring(11, 19)}] $message',
      );
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _startServer() async {
    try {
      _server = MouseServer(onLog: _addLog);
      await _server!.start();
      setState(() {
        _isRunning = true;
      });
      _addLog('Server started successfully');
    } catch (e) {
      _addLog('Failed to start server: $e');
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _stopServer() async {
    try {
      await _server?.stop();
      setState(() {
        _isRunning = false;
      });
      _addLog('Server stopped');
    } catch (e) {
      _addLog('Error stopping server: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _server?.stop();
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    final iconPath = await _prepareSystemTrayIcon();
    if (iconPath == null) {
      debugPrint('System tray icon could not be prepared');
      return;
    }

    await _systemTray.initSystemTray(
      title: "Mouse Touch Server",
      iconPath: iconPath,
    );

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show',
        onClicked: (menuItem) => windowManager.show(),
      ),
      MenuItemLabel(
        label: 'Hide',
        onClicked: (menuItem) => windowManager.hide(),
      ),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) async {
          await windowManager.setPreventClose(false);
          await windowManager.close();
        },
      ),
    ]);

    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint("SystemTray event: $eventName");
      if (eventName == kSystemTrayEventClick) {
        Platform.isWindows
            ? windowManager.show()
            : _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        Platform.isWindows
            ? _systemTray.popUpContextMenu()
            : windowManager.show();
      }
    });
  }

  Future<String?> _prepareSystemTrayIcon() async {
    try {
      final byteData = await rootBundle.load(
        'windows/runner/resources/app_icon.ico',
      );
      final supportDir = await getApplicationSupportDirectory();
      final iconFile = File('${supportDir.path}/mouse_touch_tray.ico');
      await iconFile.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        flush: true,
      );
      return iconFile.path.replaceAll('\\', '/');
    } catch (e) {
      debugPrint('Failed to load tray icon: $e');
      return null;
    }
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Server Remote',
          style: TextStyle(
            fontSize: 12,
            color: _isRunning ? Colors.green : Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: _isRunning ? Colors.green : Colors.black,
            width: 5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                _isRunning ? 'RUNNING' : 'STOPPED',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: _isRunning ? Colors.green : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.computer, size: 20),
                        const SizedBox(width: 8),
                        const Text('IP Address: '),
                        Text(
                          _localIP,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.settings_ethernet, size: 20),
                        const SizedBox(width: 8),
                        const Text('Port: '),
                        const Text(
                          '8989',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 20),
                        const SizedBox(width: 8),
                        const Text('Connected Clients: '),
                        Text(
                          '${_server?.clientCount ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _startServer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? _stopServer : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Logs Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Server Logs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showLogs
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                      ),
                      onPressed: () {
                        setState(() {
                          _showLogs = !_showLogs;
                        });
                      },
                      tooltip: _showLogs ? 'Minimize Logs' : 'Show Logs',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cleaning_services_rounded),
                      onPressed: _clearLogs,
                      tooltip: 'Clear Logs',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_showLogs)
              Expanded(
                child: Card(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black87,
                    child: ListView.builder(
                      reverse: false,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
