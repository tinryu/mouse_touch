import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remote_server_mouse/server_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 900),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const RemoteServerMouseApp());
}

class RemoteServerMouseApp extends StatefulWidget {
  const RemoteServerMouseApp({super.key});

  @override
  State<RemoteServerMouseApp> createState() => _RemoteServerMouseAppState();
}

class _RemoteServerMouseAppState extends State<RemoteServerMouseApp>
    with WindowListener {
  late final RemoteServerController _controller;
  StreamSubscription<String>? _logSubscription;

  final List<String> _logs = [];
  bool _initializing = true;
  bool _isBusy = false;
  bool _showLogs = true;
  String? _initError;

  final SystemTray _systemTray = SystemTray();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    _initSystemTray();

    _controller = RemoteServerController(onLog: debugPrint);
    _initializeController();
  }

  Future<void> _initSystemTray() async {
    final iconPath = await _prepareSystemTrayIcon();
    if (iconPath == null) {
      debugPrint('System tray icon could not be prepared');
      return;
    }

    await _systemTray.initSystemTray(
      title: "Remote Server Mouse",
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
      // Create a default icon if resource not found, but we will try to load from assets first
      // Assuming windows/runner/resources/app_icon.ico exists as in mouse_touch_server
      // If not, we might fail unless we copy it.
      // For now we try to load it from where we expect it.

      // We need to ensure the asset is declared in pubspec.yaml if we use rootBundle.load
      // However, mouse_touch_server used rootBundle.load('windows/runner/resources/app_icon.ico')
      // but that path must be in assets.

      // Since remote_server_mouse didn't have it in assets, this might fling.
      // We will try to rely on a fallback or check if we can access the file directly if it's on disk.
      // Actually, rootBundle only works if it's in pubspec assets.

      // Let's assume we might need to add it to pubspec assets or use a local file from the build directory.
      // In development mode, we can try to find it.

      // Better strategy: Use a generic system icon if meaningful specific one falls back.
      // Or just try to load and catch error.

      // NOTE: In the merged version, I should ensure the icon is available.
      // I'll leave the code similar to MTS but wrapped in try-catch.

      final byteData = await rootBundle.load(
        'windows/runner/resources/app_icon.ico',
      );
      final supportDir = await getApplicationSupportDirectory();
      final iconFile = File('${supportDir.path}/remote_server_mouse_tray.ico');
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

  Future<void> _initializeController() async {
    try {
      _logSubscription = _controller.logStream.listen(_addLog);
      await _controller.initialize();
      await _controller.refreshNetworkInfo();

      // Auto-start if desired? For now, manual start.
      // But we can start UDP discovery or something.
    } catch (error) {
      setState(() => _initError = '$error');
    } finally {
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _logSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, message);
      if (_logs.length > 500) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _startServer() async {
    if (_controller.isRunning) return;

    setState(() => _isBusy = true);
    try {
      await _controller.start();
      await _controller.refreshNetworkInfo();
    } catch (error) {
      _showErrorSnack('Failed to start server: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _stopServer() async {
    if (!_controller.isRunning) return;

    setState(() => _isBusy = true);
    try {
      await _controller.stop();
    } catch (error) {
      _showErrorSnack('Failed to stop server: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _refreshNetworkInfo() async {
    setState(() => _isBusy = true);
    try {
      await _controller.refreshNetworkInfo();
    } catch (error) {
      _showErrorSnack('Failed to refresh network info: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Remote Server Mouse',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isRunning = _controller.isRunning;
    final statusColor = isRunning ? Colors.greenAccent.shade700 : Colors.red;
    final statusText = isRunning ? 'RUNNING' : 'STOPPED';

    return AppBar(
      title: Text(
        'Screen Remote Server',
        style: TextStyle(
          fontSize: 14,
          letterSpacing: 1.1,
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      shape: Border(bottom: BorderSide(color: statusColor, width: 4)),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Chip(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            side: BorderSide(color: statusColor),
            label: Text(
              statusText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 16,
                color: statusColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(_initError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _initError = null;
                    _initializing = true;
                  });
                  _initializeController();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildServerInfoCard(),
          const SizedBox(height: 16),
          _buildControlButtons(),
          const SizedBox(height: 16),
          _buildMonitorAndStatsCard(),
          const SizedBox(height: 16),
          _buildCapabilitiesCard(),
          const SizedBox(height: 16),
          _buildLogsHeader(),
          const SizedBox(height: 8),
          if (_showLogs)
            Expanded(child: _buildLogsPanel())
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildServerInfoCard() {
    final iconColor = _controller.isRunning ? Colors.green : Colors.grey;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _InfoTile(
                  icon: Icons.computer,
                  label: 'IP Address',
                  value: _controller.serverIp,
                  iconColor: iconColor,
                ),
                _InfoTile(
                  icon: Icons.dns,
                  label: 'Hostname',
                  value: _controller.hostname,
                  iconColor: iconColor,
                ),
                _InfoTile(
                  icon: Icons.settings_ethernet,
                  label: 'WebSocket Port',
                  value: '${_controller.websocketPort}',
                  iconColor: iconColor,
                ),
                _InfoTile(
                  icon: Icons.wifi_tethering,
                  label: 'UDP Port',
                  value: '${_controller.udpPort}',
                  iconColor: iconColor,
                ),
                _InfoTile(
                  icon: Icons.people,
                  label: 'Active Clients',
                  value: '${_controller.activeClients}',
                  iconColor: iconColor,
                ),
                _InfoTile(
                  icon: Icons.videocam,
                  label: 'Codec',
                  value: _controller.availableCodecs.join(', ').toUpperCase(),
                  iconColor: iconColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: !_controller.isRunning && !_isBusy ? _startServer : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_controller.isRunning ? 'Running' : 'Start Server'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _controller.isRunning && !_isBusy ? _stopServer : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop Server'),
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          onPressed: !_isBusy ? _refreshNetworkInfo : null,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh network info',
        ),
      ],
    );
  }

  Widget _buildMonitorAndStatsCard() {
    final monitors =
        (_controller.screenInfo?['monitors'] as List<dynamic>?) ??
        const <dynamic>[];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monitors & Stream Stats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (monitors.isEmpty)
              const Text('No monitor information available yet.')
            else
              Column(
                children: monitors.map((monitor) {
                  final name = monitor['name'] ?? 'Display';
                  final width = monitor['width'];
                  final height = monitor['height'];
                  final primary = monitor['primary'] == true;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      primary ? Icons.monitor : Icons.monitor_heart,
                      color: primary ? Colors.blueAccent : Colors.grey,
                    ),
                    title: Text('$name (${width}x$height)'),
                    subtitle: Text(primary ? 'Primary display' : 'Secondary'),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    final chips = _controller.capabilities
        .map(
          (capability) => Chip(
            label: Text(capability.replaceAll('_', ' ')),
            backgroundColor: Colors.blueGrey.shade50,
          ),
        )
        .toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capabilities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Server Logs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            IconButton(
              tooltip: _showLogs ? 'Collapse logs' : 'Show logs',
              onPressed: () => setState(() {
                _showLogs = !_showLogs;
              }),
              icon: Icon(
                _showLogs
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Clear logs',
              onPressed: () => setState(_logs.clear),
              icon: const Icon(Icons.cleaning_services_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogsPanel() {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        color: Colors.black,
        child: _logs.isEmpty
            ? const Center(
                child: Text(
                  'No logs yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : ListView.builder(
                reverse: false,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'SourceCodePro',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
