import 'dart:convert';
import 'dart:async';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(TouchpadApp());

class TouchpadApp extends StatefulWidget {
  const TouchpadApp({super.key});
  @override
  State<TouchpadApp> createState() => _TouchpadAppState();
}

class _TouchpadAppState extends State<TouchpadApp> {
  late WebSocketChannel channel;
  bool isConnected = false;

  // Auto reconnect timer
  Timer? reconnectTimer;

  // WebSocket URL
  final String wsUrl = "ws://192.168.0.103:8989"; // đổi IP cho phù hợp

  @override
  void initState() {
    super.initState();
    connectWebSocket();
  }

  void connectWebSocket() {
    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      debugPrint("WS: Connecting…");

      // Lắng nghe kết nối
      channel.stream.listen(
        (event) {
          debugPrint("WS: Message received $event");
          if (!isConnected) setState(() => isConnected = true);
        },
        onError: (err) {
          debugPrint("WS ERROR: $err");
          setState(() => isConnected = false);
          scheduleReconnect();
        },
        onDone: () {
          debugPrint("WS: Disconnected");
          setState(() => isConnected = false);
          scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint("WS Connect Exception: $e");
      scheduleReconnect();
    }
  }

  void scheduleReconnect() {
    if (reconnectTimer != null && reconnectTimer!.isActive) return;

    reconnectTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      debugPrint("WS: Trying reconnect…");
      connectWebSocket();
    });
  }

  void send(Map data) {
    if (isConnected) {
      channel.sink.add(jsonEncode(data));
    }
  }

  void sendMove(double dx, double dy) {
    channel.sink.add(jsonEncode({'type': 'move', 'dx': dx, 'dy': dy}));
  }

  void sendClick(String btn) {
    channel.sink.add(jsonEncode({'type': 'click', 'button': btn}));
  }

  void sendScroll(double dx, double dy) {
    channel.sink.add(jsonEncode({'type': 'scroll', 'dx': dx, 'dy': dy}));
  }

  /// ============================================================
  /// Touchpad: gestures
  /// ============================================================

  Offset lastFocalPoint = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(
            isConnected ? "Touchpad (Connected)" : "Touchpad (Offline)",
          ),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
        body: Listener(
          onPointerSignal: (ps) {
            // Scroll wheel (nếu có chuột)
            if (ps is PointerScrollEvent) {
              send({
                "type": "scroll",
                "dx": ps.scrollDelta.dx,
                "dy": ps.scrollDelta.dy,
              });
            }
          },

          child: GestureDetector(
            behavior: HitTestBehavior.opaque,

            // 1 callback duy nhất cho multi-touch
            onScaleUpdate: (details) {
              final fingers = details.pointerCount;

              // ====== 1 NGÓN = MOVE ======
              if (fingers == 1) {
                send({
                  "type": "move",
                  "dx": details.focalPointDelta.dx,
                  "dy": details.focalPointDelta.dy,
                });
                return;
              }

              // ====== 2 NGÓN = SCROLL ======
              if (fingers == 2) {
                // zoom?
                if (details.scale != 1.0) {
                  send({"type": "zoom", "scale": details.scale});
                } else {
                  // scroll
                  send({
                    "type": "scroll",
                    "dx": details.focalPointDelta.dx,
                    "dy": details.focalPointDelta.dy,
                  });
                }
                return;
              }
            },

            onDoubleTap: () => send({"type": "click", "button": "left"}),

            child: Container(
              color: Colors.black12,
              child: const Center(
                child: Text(
                  "Touchpad Area - 1 finger = move, 2 fingers = scroll",
                ),
              ),
            ),
          ),
        ),

        bottomNavigationBar: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(
              onPressed: () => send({"type": "click", "button": "left"}),
              child: const Text("Left Click"),
            ),
            TextButton(
              onPressed: () => send({"type": "click", "button": "right"}),
              child: const Text("Right Click"),
            ),
          ],
        ),
      ),
    );
  }
}
