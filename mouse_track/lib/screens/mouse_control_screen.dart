import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mouse_track/utils/helper.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:udp/udp.dart';

class MouseControlScreen extends StatefulWidget {
  const MouseControlScreen({super.key});
  @override
  State<MouseControlScreen> createState() => _MouseControlScreenState();
}

class _MouseControlScreenState extends State<MouseControlScreen> {
  WebSocketChannel? channel;
  bool isConnected = false;
  Timer? reconnectTimer;

  DateTime? lastMoveTime;
  DateTime? lastScrollTime;
  static const movementThrottleMs = 16;
  double accumulatedDx = 0;
  double accumulatedDy = 0;
  double accumulatedScrollDx = 0;
  double accumulatedScrollDy = 0;

  double lastScale = 1.0;

  // Scrollbar UI state
  double scrollVerticalPosition = 0.5;
  double scrollHorizontalPosition = 0.5;

  // Cursor speed customization
  double cursorSpeedMultiplier = 1.0; // Default 1.0x speed
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _textController = TextEditingController();

  // GlobalKeys for tutorial
  final GlobalKey _ipFieldKey = GlobalKey();
  final GlobalKey _touchpadKey = GlobalKey();
  final GlobalKey _scrollbarKey = GlobalKey();
  final GlobalKey _scrollbarThumbKey =
      GlobalKey(); // Key for the draggable thumb
  final GlobalKey _leftButtonKey = GlobalKey();
  final GlobalKey _rightButtonKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;

  // UDP Discovery state
  bool isDiscovering = false;
  List<Map<String, dynamic>> discoveredServers = [];
  UDP? udpClient;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeIP();
    connectWebSocket();
  }

  Future<void> _initializeIP() async {
    try {
      final ip = await Helper.getLocalIPv4();
      _ipController.text = ip;
    } catch (e) {
      debugPrint('Error getting local IP: $e');
      _ipController.text = '192.168.1.1'; // Default fallback
    }
  }

  @override
  void dispose() {
    tutorialCoachMark?.finish();
    channel?.sink.close();
    reconnectTimer?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  void _createTutorial() {
    final targets = [
      TargetFocus(
        identify: "ipField",
        keyTarget: _ipFieldKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Remote IP Address",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap the WiFi icon on the right to automatically discover servers on your network",
                    style: TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "touchpad",
        keyTarget: _touchpadKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.1,
            ),
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Touchpad Area",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  ListTile(
                    title: Text(
                      "1 finger: Move cursor\n2 fingers: Zoom in/out, Scroll\nDouble tap: Right click",
                      style: TextStyle(color: Colors.red, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "scrollbar",
        keyTarget: _scrollbarThumbKey, // Focus on the thumb only
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Vertical Scrollbar",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Drag it up and down to scroll pages on your PC. The handle moves to show your scroll position.",
                    style: TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "leftButton",
        keyTarget: _leftButtonKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Left Click Button",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here for a left mouse click. You can also double-tap the touchpad area.",
                    style: TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "rightButton",
        keyTarget: _rightButtonKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Right Click Button",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here for a right mouse click. You can also long-press the touchpad area.",
                    style: TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.grey,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        debugPrint("Tutorial finished");
      },
      onSkip: () {
        debugPrint("Tutorial skipped");
        return true;
      },
    );
  }

  void _showTutorial(BuildContext context) {
    _createTutorial();
    tutorialCoachMark?.show(context: context);
  }

  void connectWebSocket() {
    try {
      channel?.sink.close();
      reconnectTimer?.cancel();

      final wsUrl = "ws://${_ipController.text}:8989";
      debugPrint("WS: Connecting to $wsUrl");

      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      Timer(const Duration(seconds: 5), () {
        if (!isConnected) {
          debugPrint("WS: Connection timeout");
          channel?.sink.close();
          if (mounted) setState(() => isConnected = false);
          scheduleReconnect();
        }
      });

      channel!.stream.listen(
        (event) {
          debugPrint("WS: ← $event");
          if (!isConnected) {
            debugPrint("WS: ✓ Connected!");
            reconnectTimer?.cancel();
            if (mounted) setState(() => isConnected = true);
          }
        },
        onError: (err) {
          debugPrint("WS ERROR: $err");
          if (mounted) setState(() => isConnected = false);
          scheduleReconnect();
        },
        onDone: () {
          debugPrint("WS: Connection closed");
          if (mounted) setState(() => isConnected = false);
          scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint("WS Exception: $e");
      if (mounted) setState(() => isConnected = false);
      scheduleReconnect();
    }
  }

  void scheduleReconnect() {
    if (isConnected) return;
    if (reconnectTimer != null && reconnectTimer!.isActive) return;

    debugPrint("WS: Scheduling reconnect in 3 seconds...");
    reconnectTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!isConnected) {
        debugPrint("WS: Attempting reconnect...");
        connectWebSocket();
      } else {
        reconnectTimer?.cancel();
      }
    });
  }

  void send(Map data) {
    if (isConnected && channel != null) {
      try {
        final json = jsonEncode(data);
        channel?.sink.add(json);
        debugPrint("WS: → ${data['type']}");
      } catch (e) {
        debugPrint("WS Send Error: $e");
      }
    } else {
      debugPrint("WS: Not connected, cannot send ${data['type']}");
    }
  }

  void sendMove(double dx, double dy) {
    final now = DateTime.now();
    accumulatedDx += dx * cursorSpeedMultiplier; // Apply speed multiplier
    accumulatedDy += dy * cursorSpeedMultiplier; // Apply speed multiplier

    if (lastMoveTime == null ||
        now.difference(lastMoveTime!).inMilliseconds >= movementThrottleMs) {
      if (accumulatedDx.abs() > 0.1 || accumulatedDy.abs() > 0.1) {
        send({'type': 'move', 'dx': accumulatedDx, 'dy': accumulatedDy});
        accumulatedDx = 0;
        accumulatedDy = 0;
        lastMoveTime = now;
      }
    }
  }

  void sendClick(String btn) {
    channel?.sink.add(jsonEncode({'type': 'click', 'button': btn}));
  }

  void sendScroll(double dx, double dy) {
    final now = DateTime.now();
    accumulatedScrollDx += dx;
    accumulatedScrollDy += dy;

    if (lastScrollTime == null ||
        now.difference(lastScrollTime!).inMilliseconds >= movementThrottleMs) {
      if (accumulatedScrollDx.abs() > 0.1 || accumulatedScrollDy.abs() > 0.1) {
        send({
          'type': 'scroll',
          'dx': accumulatedScrollDx,
          'dy': accumulatedScrollDy,
        });

        // Update scrollbar positions
        setState(() {
          scrollVerticalPosition =
              (scrollVerticalPosition - accumulatedScrollDy * 0.001).clamp(
                0.0,
                1.0,
              );
          scrollHorizontalPosition =
              (scrollHorizontalPosition + accumulatedScrollDx * 0.001).clamp(
                0.0,
                1.0,
              );
        });

        accumulatedScrollDx = 0;
        accumulatedScrollDy = 0;
        lastScrollTime = now;
      }
    }
  }

  Future<void> discoverServers() async {
    if (isDiscovering) return;

    setState(() {
      isDiscovering = true;
      discoveredServers.clear();
    });

    try {
      // Create UDP instance
      udpClient = await UDP.bind(Endpoint.any(port: const Port(0)));

      // Listen for responses
      udpClient!
          .asStream(timeout: const Duration(seconds: 5))
          .listen(
            (datagram) {
              if (datagram != null) {
                try {
                  final response = jsonDecode(
                    String.fromCharCodes(datagram.data),
                  );
                  if (response['type'] == 'server_info') {
                    debugPrint(
                      '📡 Found server: ${response['hostname']} at ${response['ip']}',
                    );

                    // Add server if not already in list
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
              setState(() => isDiscovering = false);
              udpClient?.close();

              // Auto-select if only one server found
              if (discoveredServers.length == 1) {
                _ipController.text = discoveredServers[0]['ip'];
                debugPrint(
                  'Auto-selected server: ${discoveredServers[0]['ip']}',
                );
              }
            },
          );

      // Send broadcast discovery request
      final discoveryMessage = jsonEncode({
        'type': 'discover',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Broadcast to local network
      await udpClient!.send(
        discoveryMessage.codeUnits,
        Endpoint.broadcast(port: const Port(8988)),
      );

      debugPrint('📡 Sent discovery broadcast');

      // Timeout after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (mounted && isDiscovering) {
          setState(() => isDiscovering = false);
          udpClient?.close();

          if (discoveredServers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No servers found. Make sure server is running.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Discovery error: $e');
      setState(() => isDiscovering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovery failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void selectServer(Map<String, dynamic> server) {
    debugPrint('📡 Selecting server: $server');
    final ip = server['ip']?.toString() ?? '';
    debugPrint('📡 IP to set: $ip');

    if (ip.isNotEmpty) {
      // Update the text field using controller.value for immediate update
      _ipController.value = TextEditingValue(
        text: ip,
        selection: TextSelection.collapsed(offset: ip.length),
      );

      setState(() {
        discoveredServers.clear();
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server selected: $ip'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      debugPrint('✓ IP field updated to: ${_ipController.text}');
    } else {
      debugPrint('⚠️ Server IP is empty!');
    }
  }

  void _showSettingsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Settings',
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
                  const Text(
                    'Cursor Speed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.speed, color: Colors.grey),
                      Expanded(
                        child: Slider(
                          value: cursorSpeedMultiplier,
                          min: 0.5,
                          max: 3.0,
                          divisions: 25,
                          label: '${cursorSpeedMultiplier.toStringAsFixed(1)}x',
                          activeColor: Colors.grey,
                          inactiveColor: Colors.white,
                          onChanged: (value) {
                            setModalState(() {
                              setState(() {
                                cursorSpeedMultiplier = value;
                              });
                            });
                          },
                        ),
                      ),
                      Text(
                        '${cursorSpeedMultiplier.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slow (0.5x)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Normal (1.0x)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Fast (3.0x)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Theme',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {_themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        setModalState(() {
                          setState(() {
                            _themeMode = newSelection.first;
                          });
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          cursorSpeedMultiplier = 1.0;
                          _themeMode = ThemeMode.system;
                        });
                        setModalState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text('Default Settings'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isConnected ? "RUNNING .." : "STOPPED",
          style: TextStyle(
            color: isConnected ? Colors.green.shade400 : Colors.red.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsPanel(context),
            tooltip: 'Cursor Settings',
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.info),
          onPressed: () => _showTutorial(context),
          tooltip: 'Show Tutorial',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    key: _ipFieldKey,
                    keyboardType: TextInputType.number,
                    controller: _ipController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "Remote IP",
                      labelStyle: TextStyle(fontSize: 15),
                      hintText: "Enter Remote IP (e.g. 192.168.0.1)",
                      hintStyle: TextStyle(fontSize: 14),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.computer_rounded),
                      suffixIcon: IconButton(
                        icon: isDiscovering
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : Icon(
                                Icons.wifi_find_rounded,
                                color: Colors.grey,
                                size: 35,
                              ),
                        onPressed: isDiscovering ? null : discoverServers,
                        tooltip: 'Discover Server',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Server list (shown when servers are discovered)
          if (discoveredServers.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Found ${discoveredServers.length} server(s):',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...discoveredServers.map((server) {
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.computer),
                      title: Text(
                        server['hostname'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${server['ip']}:${server['port']}'),
                      trailing: ElevatedButton(
                        onPressed: () => selectServer(server),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.grey.shade200,
                        ),
                        child: const Text('Select'),
                      ),
                    );
                  }),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  // Main touchpad area
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      lastScale = 1.0;
                    },
                    onScaleUpdate: (details) {
                      final fingers = details.pointerCount;

                      if (fingers == 1) {
                        sendMove(
                          details.focalPointDelta.dx,
                          details.focalPointDelta.dy,
                        );
                        return;
                      }

                      if (fingers == 2) {
                        final currentScale = details.scale;
                        final scaleDelta = currentScale - lastScale;
                        final totalScaleChange = (currentScale - 1.0).abs();

                        // If scale hasn't changed much, treat as scroll
                        if (totalScaleChange < 0.1 && scaleDelta.abs() < 0.05) {
                          sendScroll(
                            details.focalPointDelta.dx,
                            details.focalPointDelta.dy,
                          );
                        } else {
                          // Otherwise treat as zoom
                          if (scaleDelta.abs() > 0.01) {
                            send({"type": "zoom", "delta": scaleDelta});
                            lastScale = currentScale;
                          }
                        }
                      }
                    },
                    onScaleEnd: (details) {
                      lastScale = 1.0;
                    },
                    onTap: () => send({"type": "click", "button": "left"}),
                    onDoubleTap: () =>
                        send({"type": "click", "button": "right"}),
                    onLongPress: () =>
                        send({"type": "click", "button": "right"}),
                    child: Container(
                      key: _touchpadKey,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),

                  // Vertical Scrollbar (Always visible, draggable)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      key: _scrollbarKey,
                      width: 50,
                      margin: EdgeInsets.only(bottom: 20, right: 5, top: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final barHeight = 50.0; // Fixed thumb height
                          final topPosition =
                              (constraints.maxHeight - barHeight) *
                              scrollVerticalPosition;
                          return Stack(
                            children: [
                              // Track
                              Container(
                                width: 50,
                                height: constraints
                                    .maxHeight, // Use full available height
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border(
                                    right: BorderSide(color: Colors.black12),
                                  ),
                                ),
                              ),
                              // Draggable Thumb
                              Positioned(
                                top: topPosition,
                                child: GestureDetector(
                                  onVerticalDragUpdate: (details) {
                                    setState(() {
                                      scrollVerticalPosition =
                                          ((topPosition + details.delta.dy) /
                                                  (constraints.maxHeight -
                                                      barHeight))
                                              .clamp(0.0, 1.0);
                                    });
                                    // Send scroll command based on drag
                                    sendScroll(0, -details.delta.dy * 5);
                                  },
                                  child: SizedBox(
                                    key: _scrollbarThumbKey, // Add key to thumb
                                    width: 50,
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 30,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.keyboard,
                            color: Theme.of(context).dividerColor,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.backspace,
                                  color: Theme.of(context).dividerColor,
                                ),
                                onPressed: () {
                                  send({"type": "backspace"});
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: Theme.of(context).dividerColor,
                                ),
                                onPressed: () {
                                  if (_textController.text.isEmpty) {
                                    return;
                                  }
                                  send({
                                    "type": "text",
                                    "text": _textController.text,
                                  });
                                  _textController.clear();
                                },
                              ),
                            ],
                          ),
                          labelText: 'Enter text',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(right: 8.0, left: 8.0, bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                key: _leftButtonKey,
                onPressed: () => send({"type": "click", "button": "left"}),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.white,
                  shadowColor: Theme.of(context).shadowColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: SizedBox.fromSize(size: Size(50, 50)),
              ),
            ),
            const SizedBox(width: 0.8),
            Expanded(
              child: TextButton(
                key: _rightButtonKey,
                onPressed: () => send({"type": "click", "button": "right"}),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.white,
                  shadowColor: Theme.of(context).shadowColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: SizedBox.fromSize(size: Size(50, 50)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
