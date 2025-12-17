import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:udp/udp.dart';
import 'package:network_info_plus/network_info_plus.dart' as net_info;
import 'dart:io';

class ScreenRemoteScreen extends StatefulWidget {
  const ScreenRemoteScreen({super.key});

  @override
  State<ScreenRemoteScreen> createState() => _ScreenRemoteScreenState();
}

class _ScreenRemoteScreenState extends State<ScreenRemoteScreen> {
  WebSocketChannel? channel;
  bool isConnected = false;
  bool isStreaming = false;
  Timer? reconnectTimer;

  final TextEditingController _ipController = TextEditingController();
  static const int _defaultWebSocketPort = 9090;
  static const int _discoveryPort = 8989;

  double lastScale = 1.0;

  // Movement throttling - Improved for smoother movement
  DateTime? lastMoveTime;
  DateTime? lastScrollTime;
  static const movementThrottleMs = 8; // ~120 FPS for smoother movement
  double accumulatedDx = 0;
  double accumulatedDy = 0;
  double accumulatedScrollDx = 0;
  double accumulatedScrollDy = 0;

  // For touch mode relative movement
  Offset? lastTouchPosition;

  // Drag state
  bool isDragging = false;
  String dragButton = 'left';

  // UDP Discovery
  bool isDiscovering = false;
  bool _isServerListExpanded = false;
  List<Map<String, dynamic>> discoveredServers = [];
  UDP? udpClient;

  // Screen streaming
  Uint8List? currentFrame;
  int frameWidth = 0;
  int frameHeight = 0;
  int frameCount = 0;
  bool expectingFrameData = false;

  // Settings
  int fps = 10;
  int quality = 70;
  int selectedMonitor = 0;
  String selectedCodec = 'jpeg'; // NEW: Codec selection
  List<String> availableCodecs = ['jpeg']; // NEW: Available codecs from server
  String controlMode = 'cursor'; // NEW: 'cursor' or 'touch' mode

  // Network quality monitoring (NEW)
  String networkQuality = 'unknown'; // excellent, good, fair, poor, unknown
  double avgLatency = 0.0;
  int currentFps = 0;
  int currentQuality = 70;

  // UI state
  bool isFullscreen = false;
  Offset? cursorPosition; // Track cursor position for visual feedback

  // GlobalKey for image widget to get correct coordinates
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ipController.text = '172.168.99.143'; // Default IP
  }

  @override
  void dispose() {
    stopStream();
    channel?.sink.close();
    reconnectTimer?.cancel();
    _ipController.dispose();
    udpClient?.close();
    super.dispose();
  }

  Future<void> discoverServers() async {
    if (isDiscovering) return;

    setState(() {
      isDiscovering = true;
      discoveredServers.clear();
      _isServerListExpanded = true;
    });

    try {
      udpClient = await UDP.bind(Endpoint.any());

      udpClient!
          .asStream(timeout: const Duration(seconds: 5))
          .listen(
            (datagram) {
              if (datagram != null) {
                try {
                  final response = jsonDecode(
                    String.fromCharCodes(datagram.data),
                  );
                  if (response['type'] == 'server_info' &&
                      response['service'] == 'screen_remote') {
                    debugPrint(
                      '📡 Found screen remote server: ${response['ip']}',
                    );

                    final serverExists = discoveredServers.any(
                      (server) => server['ip'] == response['ip'],
                    );
                    if (!serverExists) {
                      setState(() {
                        discoveredServers.add(response);
                      });
                    }
                  }
                } catch (e) {
                  debugPrint('Error parsing discovery response: $e');
                }
              }
            },
            onDone: () {
              setState(() {
                isDiscovering = false;
                // Only collapse if no servers were found
                if (discoveredServers.isEmpty) {
                  _isServerListExpanded = false;
                }
              });
              udpClient?.close();

              if (discoveredServers.length == 1) {
                _ipController.text = discoveredServers[0]['ip'];
              }
            },
          );

      final discoveryMessage = jsonEncode({
        'type': 'discover',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final data = discoveryMessage.codeUnits;

      // 1. Send to global broadcast (255.255.255.255)
      await udpClient!.send(
        data,
        Endpoint.broadcast(port: const Port(_discoveryPort)),
      );

      // 2. Send to subnet directed broadcast (e.g. 192.168.1.255)
      // This is often required on Android where 255.255.255.255 might be blocked or not routed.
      try {
        final info = net_info.NetworkInfo();
        final wifiIp = await info.getWifiIP();
        final wifiSubnet = await info.getWifiSubmask();

        debugPrint('ℹ️ Client IP: $wifiIp, Subnet: $wifiSubnet');

        if (wifiIp != null && wifiSubnet != null) {
          final broadcastIp = _getBroadcastAddress(wifiIp, wifiSubnet);
          debugPrint('📡 Sending directed broadcast to $broadcastIp');
          await udpClient!.send(
            data,
            Endpoint.unicast(
              InternetAddress(broadcastIp),
              port: const Port(_discoveryPort),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error sending directed broadcast: $e');
      }

      debugPrint('📡 Sent discovery broadcast to port $_discoveryPort');

      Timer(const Duration(seconds: 5), () {
        if (mounted && isDiscovering) {
          setState(() => isDiscovering = false);
          udpClient?.close();

          if (discoveredServers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No screen remote servers found'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Discovery error: $e');
      setState(() => isDiscovering = false);
    }
  }

  String _getBroadcastAddress(String ip, String subnetMask) {
    List<int> ipParts = ip.split('.').map(int.parse).toList();
    List<int> maskParts = subnetMask.split('.').map(int.parse).toList();
    List<int> broadcastParts = [];

    for (int i = 0; i < 4; i++) {
      broadcastParts.add(ipParts[i] | (~maskParts[i] & 0xFF));
    }

    return broadcastParts.join('.');
  }

  void connectWebSocket() {
    try {
      channel?.sink.close();
      reconnectTimer?.cancel();

      final wsUrl = "ws://${_ipController.text}:$_defaultWebSocketPort";
      debugPrint("WS: Connecting to $wsUrl");

      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      Timer(const Duration(seconds: 5), () {
        if (!isConnected) {
          debugPrint("WS: Connection timeout");
          channel?.sink.close();
          if (mounted) setState(() => isConnected = false);
        }
      });

      channel!.stream.listen(
        (event) {
          if (event is String) {
            try {
              final msg = jsonDecode(event);
              handleMessage(msg);
            } catch (e) {
              debugPrint('Error parsing message: $e');
            }
          } else if (event is Uint8List) {
            // Binary frame data
            if (expectingFrameData) {
              setState(() {
                currentFrame = event;
                frameCount++;
                expectingFrameData = false;
              });
            }
          }
        },
        onError: (err) {
          debugPrint("WS ERROR: $err");
          if (mounted) setState(() => isConnected = false);
        },
        onDone: () {
          debugPrint("WS: Connection closed");
          if (mounted) setState(() => isConnected = false);
        },
      );
    } catch (e) {
      debugPrint("WS Exception: $e");
      if (mounted) setState(() => isConnected = false);
    }
  }

  void handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'connected':
        debugPrint(
          '✓ Connected to screen remote server v${msg['server']?['version'] ?? '1.0'}',
        );
        if (mounted) {
          setState(() {
            isConnected = true;
            // Get available codecs from server
            if (msg['availableCodecs'] != null) {
              availableCodecs = List<String>.from(msg['availableCodecs']);
            }
          });
        }
        break;

      case 'frame_meta':
        frameWidth = msg['width'];
        frameHeight = msg['height'];
        expectingFrameData = true;

        // Update network quality and stats from frame metadata
        if (msg['networkQuality'] != null) {
          setState(() {
            networkQuality = msg['networkQuality'];
          });
        }
        if (msg['quality'] != null) {
          currentQuality = msg['quality'];
        }
        if (msg['fps'] != null) {
          currentFps = msg['fps'];
        }
        break;

      case 'screen_info':
        debugPrint('Screen info: ${msg['monitors']}');
        break;

      case 'heartbeat':
        // Server is alive - update network stats
        if (msg['networkQuality'] != null) {
          setState(() {
            networkQuality = msg['networkQuality'];
          });
        }
        if (msg['avgLatency'] != null) {
          setState(() {
            avgLatency = msg['avgLatency'];
          });
        }
        break;
    }
  }

  void startStream() {
    if (channel != null && isConnected) {
      channel!.sink.add(
        jsonEncode({
          'type': 'start_stream',
          'fps': fps,
          'quality': quality,
          'codec': selectedCodec, // NEW: Send codec selection
          'monitor': selectedMonitor,
          'maxFps': 30, // NEW: Max FPS for adaptive streaming
        }),
      );

      setState(() => isStreaming = true);
      debugPrint('▶️ Started streaming with codec: $selectedCodec');
    }
  }

  void stopStream() {
    if (channel != null && isConnected) {
      channel!.sink.add(jsonEncode({'type': 'stop_stream'}));
    }

    setState(() {
      isStreaming = false;
      currentFrame = null;
    });
    debugPrint('⏹️ Stopped streaming');
  }

  void sendMouseControl(String action, {double? x, double? y, String? button}) {
    if (channel != null && isConnected) {
      final Map<String, dynamic> data = {'action': action};

      // For scroll actions, use dx/dy instead of x/y
      if (action == 'scroll') {
        if (x != null) data['dx'] = x;
        if (y != null) data['dy'] = y;
      } else {
        // For move/click actions, use x/y with normalized flag
        if (x != null) data['x'] = x;
        if (y != null) data['y'] = y;
        if (x != null && y != null && (action == 'move' || action == 'click')) {
          data['normalized'] = true;
        }
      }

      if (button != null) data['button'] = button;

      final message = jsonEncode({'type': 'mouse', 'data': data});

      channel!.sink.add(message);
      debugPrint(
        '🖱️ Mouse $action: ${action == 'scroll' ? 'dx=${x?.toStringAsFixed(1)}, dy=${y?.toStringAsFixed(1)}' : '(${x?.toStringAsFixed(3)}, ${y?.toStringAsFixed(3)})'} ${button != null ? 'button: $button' : ''}',
      );
    }
  }

  void sendDragStart(double x, double y, {String button = 'left'}) {
    if (channel != null && isConnected) {
      // First move to position
      sendMouseControl('move', x: x, y: y);

      // Then start drag
      final message = jsonEncode({
        'type': 'mouse',
        'data': {'action': 'drag_start', 'button': button},
      });

      channel!.sink.add(message);
      debugPrint(
        '🖱️ Drag start at (${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}) button: $button',
      );

      setState(() {
        isDragging = true;
        dragButton = button;
      });
    }
  }

  void sendDragEnd() {
    if (channel != null && isConnected && isDragging) {
      final message = jsonEncode({
        'type': 'mouse',
        'data': {'action': 'drag_end', 'button': dragButton},
      });

      channel!.sink.add(message);
      debugPrint('🖱️ Drag end');

      setState(() {
        isDragging = false;
      });
    }
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stream Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Control Mode Selection
                    const Text(
                      'Control Mode',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'cursor',
                          label: Text('Cursor'),
                          icon: Icon(Icons.mouse),
                        ),
                        ButtonSegment(
                          value: 'touch',
                          label: Text('Touch'),
                          icon: Icon(Icons.touch_app),
                        ),
                      ],
                      selected: {controlMode},
                      onSelectionChanged: (Set<String> newSelection) {
                        setModalState(() {
                          setState(() {
                            controlMode = newSelection.first;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controlMode == 'cursor'
                          ? '📍 Direct cursor positioning (like Chrome Remote Desktop)'
                          : '🖱️ Touchpad-style relative movement',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Codec Selection
                    const Text(
                      'Video Codec',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: selectedCodec,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: availableCodecs.map((codec) {
                        String displayName = codec.toUpperCase();
                        String description = '';
                        switch (codec) {
                          case 'jpeg':
                            description = 'Best compatibility';
                            break;
                          case 'vp8':
                            description = 'Good quality, low latency';
                            break;
                          case 'vp9':
                            description = 'Better compression';
                            break;
                          case 'h264':
                            description = 'Hardware accelerated';
                            break;
                        }
                        return DropdownMenuItem(
                          value: codec,
                          child: Text('$displayName - $description'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            setState(() {
                              selectedCodec = value;
                            });
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    Text('Frame Rate: $fps FPS'),
                    Slider(
                      value: fps.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 25,
                      label: '$fps FPS',
                      onChanged: (value) {
                        setModalState(() {
                          setState(() {
                            fps = value.toInt();
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text('Quality: $quality%'),
                    Slider(
                      value: quality.toDouble(),
                      min: 40,
                      max: 90,
                      divisions: 50,
                      label: '$quality%',
                      onChanged: (value) {
                        setModalState(() {
                          setState(() {
                            quality = value.toInt();
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (isStreaming)
                      ElevatedButton(
                        onPressed: () {
                          stopStream();
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 500), () {
                            startStream();
                          });
                        },
                        child: const Text('Apply Settings'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isFullscreen
          ? null
          : AppBar(
              backgroundColor: isConnected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              title: Text(
                isConnected
                    ? (isStreaming ? 'STREAMING' : 'CONNECTED')
                    : 'DISCONNECTED',
                style: TextStyle(
                  color: isConnected
                      ? Colors.green.shade400
                      : Colors.red.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
              centerTitle: true,
              actions: [
                if (isStreaming && currentFrame != null)
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      setState(() {
                        isFullscreen = true;
                      });
                    },
                    tooltip: 'Fullscreen',
                  ),
                isConnected
                    ? IconButton(
                        icon: const Icon(Icons.stop, color: Colors.white),
                        tooltip: 'Disconnect',
                        onPressed: () {
                          // Close the connection
                          channel?.sink.close();
                          setState(() {
                            isConnected = false;
                            isStreaming = false;
                          });
                        },
                      )
                    : SizedBox.shrink(),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettingsPanel,
                  tooltip: 'Stream Settings',
                ),
              ],
            ),
      body: isFullscreen ? _buildFullscreenView() : _buildNormalView(),
    );
  }

  Widget _buildFullscreenView() {
    return GestureDetector(
      onDoubleTap: () {
        setState(() {
          isFullscreen = false;
        });
      },
      child: Container(
        color: Colors.black,
        child: currentFrame != null
            ? _buildInteractiveScreen()
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildNormalView() {
    return Column(
      children: [
        // Connection controls
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: "Server IP",
                    hintText: "Enter server IP",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.computer),
                    suffixIcon: IconButton(
                      icon: isDiscovering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      onPressed: () {
                        if (discoveredServers.isNotEmpty &&
                            _isServerListExpanded) {
                          setState(() {
                            _isServerListExpanded = false;
                          });
                        } else {
                          discoverServers();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Server list (shown when servers are discovered)
        if (discoveredServers.isNotEmpty && _isServerListExpanded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discovered Servers',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _isServerListExpanded = false;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 1),
                ...discoveredServers.map(
                  (server) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      server['hostname'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${server['ip']}:${server['port'] ?? _defaultWebSocketPort}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    onTap: () {
                      _ipController.text = server['ip'];
                      setState(() {
                        _isServerListExpanded = false;
                      });
                      connectWebSocket();
                    },
                  ),
                ),
              ],
            ),
          ),

        // Stream controls
        if (isConnected)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isStreaming ? stopStream : startStream,
                  icon: Icon(isStreaming ? Icons.stop : Icons.play_arrow),
                  label: Text(isStreaming ? 'Stop' : 'Start Stream'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStreaming ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Frames: $frameCount'),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Screen display
        Expanded(
          child: Container(
            color: Colors.black,
            child: currentFrame != null
                ? _buildInteractiveScreen()
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.desktop_windows,
                          size: 80,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isConnected
                              ? 'Click "Start Stream" to begin'
                              : 'Connect to server first',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Enhanced Info bar with network quality
        if (currentFrame != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade900,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'Resolution: ${frameWidth}x$frameHeight',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    Row(
                      children: [
                        Icon(
                          controlMode == 'cursor'
                              ? Icons.mouse
                              : Icons.touch_app,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controlMode == 'cursor' ? 'CURSOR' : 'TOUCH',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Codec: ${selectedCodec.toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.signal_cellular_alt,
                          size: 14,
                          color: _getNetworkQualityColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          networkQuality.toUpperCase(),
                          style: TextStyle(
                            color: _getNetworkQualityColor(),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'FPS: $currentFps/$fps',
                      style: TextStyle(
                        color: currentFps < fps ? Colors.orange : Colors.white,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Quality: $currentQuality%/$quality%',
                      style: TextStyle(
                        color: currentQuality < quality
                            ? Colors.orange
                            : Colors.white,
                        fontSize: 11,
                      ),
                    ),
                    if (avgLatency > 0)
                      Text(
                        'Latency: ${avgLatency.toStringAsFixed(0)}ms',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper function to get network quality color
  Color _getNetworkQualityColor() {
    switch (networkQuality) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInteractiveScreen() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: GestureDetector(
        onScaleStart: (details) {
          lastScale = 1.0;
        },
        onScaleUpdate: (details) {
          final fingers = details.pointerCount;

          // Update cursor position for visual feedback
          setState(() {
            cursorPosition = details.focalPoint;
          });

          if (fingers == 1) {
            // Get the image widget's RenderBox
            final RenderBox? imageBox =
                _imageKey.currentContext?.findRenderObject() as RenderBox?;

            if (imageBox != null) {
              if (controlMode == 'cursor') {
                // CURSOR MODE: Absolute positioning (Chrome Remote Desktop style)
                // Convert global position to local position relative to image
                final localPosition = imageBox.globalToLocal(
                  details.focalPoint,
                );

                // Calculate normalized coordinates (0-1)
                final normalizedX = (localPosition.dx / imageBox.size.width)
                    .clamp(0.0, 1.0);
                final normalizedY = (localPosition.dy / imageBox.size.height)
                    .clamp(0.0, 1.0);

                // Throttle sending for smoother movement
                final now = DateTime.now();
                if (lastMoveTime == null ||
                    now.difference(lastMoveTime!).inMilliseconds >=
                        movementThrottleMs) {
                  sendMouseControl('move', x: normalizedX, y: normalizedY);
                  lastMoveTime = now;
                }
              } else {
                // TOUCH MODE: Relative movement (touchpad style)
                final currentPosition = details.focalPoint;

                if (lastTouchPosition != null) {
                  // Calculate delta movement
                  final dx = currentPosition.dx - lastTouchPosition!.dx;
                  final dy = currentPosition.dy - lastTouchPosition!.dy;

                  // Accumulate movement
                  accumulatedDx += dx;
                  accumulatedDy += dy;

                  // Throttle sending
                  final now = DateTime.now();
                  if (lastMoveTime == null ||
                      now.difference(lastMoveTime!).inMilliseconds >=
                          movementThrottleMs) {
                    if (accumulatedDx.abs() > 0.5 ||
                        accumulatedDy.abs() > 0.5) {
                      // Sensitivity multiplier for touch mode
                      final sensitivity = 1.2;
                      final moveDx = accumulatedDx * sensitivity;
                      final moveDy = accumulatedDy * sensitivity;

                      // Send relative movement (not normalized)
                      channel?.sink.add(
                        jsonEncode({
                          'type': 'mouse',
                          'data': {
                            'action': 'move',
                            'dx': moveDx,
                            'dy': moveDy,
                            'normalized': false, // Relative movement
                          },
                        }),
                      );

                      accumulatedDx = 0;
                      accumulatedDy = 0;
                      lastMoveTime = now;
                    }
                  }
                }

                lastTouchPosition = currentPosition;
              }
            }
            return;
          }

          if (fingers == 2) {
            final currentScale = details.scale;
            final scaleDelta = currentScale - lastScale;
            final totalScaleChange = (currentScale - 1.0).abs();

            // If scale hasn't changed much, treat as scroll
            // Made threshold more lenient to prefer scrolling over zooming
            if (totalScaleChange < 0.15 && scaleDelta.abs() < 0.08) {
              // Accumulate scroll
              accumulatedScrollDx += details.focalPointDelta.dx;
              accumulatedScrollDy += details.focalPointDelta.dy;

              // Throttle sending
              final now = DateTime.now();
              if (lastScrollTime == null ||
                  now.difference(lastScrollTime!).inMilliseconds >=
                      movementThrottleMs) {
                if (accumulatedScrollDx.abs() > 1.0 ||
                    accumulatedScrollDy.abs() > 1.0) {
                  // Increased sensitivity for better scrolling
                  // Negative Y = scroll up, Positive Y = scroll down
                  final scrollSensitivity = 1.5; // Increased from 0.5
                  final scrollDx = accumulatedScrollDx * scrollSensitivity;
                  final scrollDy = -accumulatedScrollDy * scrollSensitivity;

                  sendMouseControl('scroll', x: scrollDx, y: scrollDy);
                  accumulatedScrollDx = 0;
                  accumulatedScrollDy = 0;
                  lastScrollTime = now;
                }
              }
            } else {
              // Otherwise treat as zoom
              if (scaleDelta.abs() > 0.02) {
                sendMouseControl('zoom', x: scaleDelta, y: 0);
                lastScale = currentScale;
              }
            }
          }
        },
        onTapUp: (details) {
          // Get the image widget's RenderBox
          final RenderBox? imageBox =
              _imageKey.currentContext?.findRenderObject() as RenderBox?;

          if (imageBox != null) {
            // Convert global position to local position relative to image
            final localPosition = imageBox.globalToLocal(
              details.globalPosition,
            );

            // Calculate normalized coordinates (0-1)
            final normalizedX = (localPosition.dx / imageBox.size.width).clamp(
              0.0,
              1.0,
            );
            final normalizedY = (localPosition.dy / imageBox.size.height).clamp(
              0.0,
              1.0,
            );

            debugPrint(
              '👆 Tap at: (${localPosition.dx.toStringAsFixed(1)}, ${localPosition.dy.toStringAsFixed(1)}) '
              'normalized: (${normalizedX.toStringAsFixed(3)}, ${normalizedY.toStringAsFixed(3)})',
            );

            // Update cursor position
            setState(() {
              cursorPosition = details.globalPosition;
            });

            sendMouseControl(
              'click',
              x: normalizedX,
              y: normalizedY,
              button: 'left',
            );
          }
        },
        onLongPressStart: (details) {
          final RenderBox? imageBox =
              _imageKey.currentContext?.findRenderObject() as RenderBox?;

          if (imageBox != null) {
            final localPosition = imageBox.globalToLocal(
              details.globalPosition,
            );

            final normalizedX = (localPosition.dx / imageBox.size.width).clamp(
              0.0,
              1.0,
            );
            final normalizedY = (localPosition.dy / imageBox.size.height).clamp(
              0.0,
              1.0,
            );

            debugPrint(
              '👆 Long press start at: (${normalizedX.toStringAsFixed(3)}, ${normalizedY.toStringAsFixed(3)})',
            );

            // Update cursor position
            setState(() {
              cursorPosition = details.globalPosition;
            });

            // Start drag operation
            sendDragStart(normalizedX, normalizedY);
          }
        },
        onLongPressMoveUpdate: (details) {
          if (!isDragging) return;

          final RenderBox? imageBox =
              _imageKey.currentContext?.findRenderObject() as RenderBox?;

          if (imageBox != null) {
            final localPosition = imageBox.globalToLocal(
              details.globalPosition,
            );

            final normalizedX = (localPosition.dx / imageBox.size.width).clamp(
              0.0,
              1.0,
            );
            final normalizedY = (localPosition.dy / imageBox.size.height).clamp(
              0.0,
              1.0,
            );

            // Update cursor position
            setState(() {
              cursorPosition = details.globalPosition;
            });

            // Send move during drag
            final now = DateTime.now();
            if (lastMoveTime == null ||
                now.difference(lastMoveTime!).inMilliseconds >=
                    movementThrottleMs) {
              sendMouseControl('move', x: normalizedX, y: normalizedY);
              lastMoveTime = now;
            }
          }
        },
        onLongPressEnd: (details) {
          if (isDragging) {
            // End drag operation
            sendDragEnd();

            debugPrint('👆 Long press end - drag completed');
          } else {
            // Fallback to right-click if drag wasn't initiated
            final RenderBox? imageBox =
                _imageKey.currentContext?.findRenderObject() as RenderBox?;

            if (imageBox != null) {
              final localPosition = imageBox.globalToLocal(
                details.globalPosition,
              );

              final normalizedX = (localPosition.dx / imageBox.size.width)
                  .clamp(0.0, 1.0);
              final normalizedY = (localPosition.dy / imageBox.size.height)
                  .clamp(0.0, 1.0);

              debugPrint(
                '👆 Long press at: (${normalizedX.toStringAsFixed(3)}, ${normalizedY.toStringAsFixed(3)})',
              );

              // Update cursor position
              setState(() {
                cursorPosition = details.globalPosition;
              });

              sendMouseControl(
                'click',
                x: normalizedX,
                y: normalizedY,
                button: 'right',
              );
            }
          }
        },
        onScaleEnd: (details) {
          lastScale = 1.0;
          lastTouchPosition = null; // Reset touch position

          // End drag if still active
          if (isDragging) {
            sendDragEnd();
          }

          // Clear cursor position after gesture ends
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                cursorPosition = null;
              });
            }
          });
        },
        child: Stack(
          children: [
            Center(
              child: Image.memory(
                key: _imageKey,
                currentFrame!,
                gaplessPlayback: true,
                fit: BoxFit.contain,
              ),
            ),
            // Cursor indicator
            if (cursorPosition != null)
              Positioned(
                left: cursorPosition!.dx - 15,
                top: cursorPosition!.dy - 15,
                child: IgnorePointer(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDragging ? Colors.blue : Colors.red,
                        width: 2,
                      ),
                      color: isDragging
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Icon(
                        isDragging ? Icons.pan_tool : Icons.circle,
                        size: isDragging ? 16 : 8,
                        color: isDragging ? Colors.blue : Colors.red,
                      ),
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
