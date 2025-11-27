import 'package:flutter/material.dart';
import 'dart:io';
import 'server/mouse_server.dart';

void main() {
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

class _ServerHomePageState extends State<ServerHomePage> {
  MouseServer? _server;
  bool _isRunning = false;
  final List<String> _logs = [];
  String _localIP = 'Loading...';

  @override
  void initState() {
    super.initState();
    _getLocalIP();
  }

  Future<void> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            setState(() {
              _localIP = addr.address;
            });
            return;
          }
        }
      }
      setState(() {
        _localIP = 'No IP found';
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

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouse Touch Server'),
        backgroundColor: _isRunning ? Colors.green : Colors.grey,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                _isRunning ? 'RUNNING' : 'STOPPED',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
            const Text(
              'Server Logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
