import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mouse_track/utils/helper.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:udp/udp.dart';

void main() => runApp(TouchpadApp());

class TouchpadApp extends StatefulWidget {
  const TouchpadApp({super.key});
  @override
  State<TouchpadApp> createState() => _TouchpadAppState();
}

class _TouchpadAppState extends State<TouchpadApp> {
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

  final TextEditingController _ipController = TextEditingController();

  // GlobalKeys for tutorial
  final GlobalKey _ipFieldKey = GlobalKey();
  final GlobalKey _connectButtonKey = GlobalKey();
  final GlobalKey _touchpadKey = GlobalKey();
  final GlobalKey _scrollbarKey = GlobalKey();
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
        alignSkip: Alignment.topRight,
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
                    "Server IP Address",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Enter IP address remote device.",
                    style: TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "connectButton",
        keyTarget: _connectButtonKey,
        alignSkip: Alignment.topRight,
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
                    "Connect Button",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here to connect to your PC. Make sure the server is running on your computer first!",
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
              left: MediaQuery.of(context).size.width * 0.2,
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
                  Text(
                    "• 1 finger: Move cursor\n• 2 fingers: Zoom in/out\n• Double tap: Left click\n• Long press: Right click",
                    style: TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "scrollbar",
        keyTarget: _scrollbarKey,
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
                    "Scrollbar",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Drag this scrollbar up and down to scroll on your PC. It provides visual feedback for scrolling.",
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
      colorShadow: Colors.black,
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
    accumulatedDx += dx;
    accumulatedDy += dy;

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
    _ipController.text = server['ip'];
    setState(() {
      discoveredServers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext scaffoldContext) {
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text(
                isConnected ? "Server (Connected)" : "Server (Offline)",
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              backgroundColor: isConnected
                  ? Colors.green.shade400
                  : Colors.red.shade400,
              toolbarOpacity: 0.2,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: _ipFieldKey,
                          keyboardType: TextInputType.number,
                          controller: _ipController,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(fontSize: 14, color: Colors.black),
                          decoration: InputDecoration(
                            labelText: "Server IP",
                            labelStyle: TextStyle(fontSize: 15),
                            hintText: "Enter PC IP (e.g. 192.168.1.5)",
                            hintStyle: TextStyle(fontSize: 14),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.settings_ethernet_rounded),
                            prefixIconColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: isDiscovering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              )
                            : const Icon(Icons.search, color: Colors.blue),
                        onPressed: isDiscovering ? null : discoverServers,
                        tooltip: 'Discover Server',
                      ),
                      IconButton(
                        icon: const Icon(Icons.info, color: Colors.black),
                        onPressed: () => _showTutorial(scaffoldContext),
                        tooltip: 'Show Tutorial',
                      ),
                      ElevatedButton(
                        key: _connectButtonKey,
                        onPressed: () {
                          isConnected = false;
                          connectWebSocket();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black12,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          minimumSize: Size(55, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Icon(
                          Icons.subdirectory_arrow_left_outlined,
                          size: 22,
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
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
                            leading: const Icon(
                              Icons.computer,
                              color: Colors.blue,
                            ),
                            title: Text(
                              server['hostname'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('${server['ip']}:${server['port']}'),
                            trailing: ElevatedButton(
                              onPressed: () => selectServer(server),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Select'),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                Expanded(
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

                          if (fingers >= 2) {
                            final currentScale = details.scale;
                            final scaleDelta = currentScale - lastScale;
                            final totalScaleChange = (currentScale - 1.0).abs();

                            if (totalScaleChange > 0.1 ||
                                scaleDelta.abs() > 0.03) {
                              send({"type": "zoom", "delta": scaleDelta});
                              lastScale = currentScale;
                            }
                            return;
                          }

                          if (fingers == 3) {
                            final dx = details.focalPointDelta.dx;
                            final dy = details.focalPointDelta.dy;
                            sendScroll(dx, dy);
                          }
                        },
                        onScaleEnd: (details) {
                          lastScale = 1.0;
                        },
                        onDoubleTap: () =>
                            send({"type": "click", "button": "left"}),
                        onLongPress: () =>
                            send({"type": "click", "button": "right"}),
                        child: Container(
                          key: _touchpadKey,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                      ),

                      // Vertical Scrollbar (Always visible, draggable)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          key: _scrollbarKey,
                          width: 30,
                          margin: EdgeInsets.only(bottom: 20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final barHeight = constraints.maxHeight * 0.2;
                              final topPosition =
                                  (constraints.maxHeight - barHeight) *
                                  scrollVerticalPosition;
                              return Stack(
                                children: [
                                  // Track
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      border: Border.symmetric(
                                        horizontal: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 0.8,
                                        ),
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
                                              ((topPosition +
                                                          details.delta.dy) /
                                                      (constraints.maxHeight -
                                                          barHeight))
                                                  .clamp(0.0, 1.0);
                                        });
                                        // Send scroll command based on drag
                                        sendScroll(0, -details.delta.dy * 5);
                                      },
                                      child: SizedBox(
                                        width: 30,
                                        height: barHeight,
                                        child: Icon(
                                          Icons.unfold_more_double_outlined,
                                          color: Colors.black26,
                                          size: 30,
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
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: _leftButtonKey,
                    onPressed: () => send({"type": "click", "button": "left"}),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black12,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: SizedBox.fromSize(size: Size(50, 50)),
                  ),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: TextButton(
                    key: _rightButtonKey,
                    onPressed: () => send({"type": "click", "button": "right"}),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black12,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: SizedBox.fromSize(size: Size(50, 50)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
