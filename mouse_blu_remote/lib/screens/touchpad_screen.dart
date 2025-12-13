import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../providers/connection_provider.dart';
import '../models/mouse_event.dart';
import 'settings_screen.dart';
import 'connection_screen.dart';

class TouchpadScreen extends StatefulWidget {
  const TouchpadScreen({super.key});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  Offset? _lastPosition;
  int _tapCount = 0;
  DateTime? _lastTapTime;
  bool _isScrolling = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              const Color(0xFF334155),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildTouchpad(),
              ),
              _buildControlButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildConnectionStatus(provider),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings, color: Colors.white),
              ),
              IconButton(
                onPressed: () async {
                  await provider.disconnect();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ConnectionScreen(),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(ConnectionProvider provider) {
    final isConnected = provider.status == ConnectionStatus.connected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchpad() {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return GestureDetector(
          onPanStart: (details) {
            _lastPosition = details.localPosition;
            _isScrolling = false;
          },
          onPanUpdate: (details) {
            if (_lastPosition == null) return;

            final delta = details.localPosition - _lastPosition!;
            _lastPosition = details.localPosition;

            // Check if this is a scroll gesture (2+ pointers would be detected differently)
            // For simplicity, we'll use a modifier key or separate scroll area
            if (_isScrolling) {
              _sendScrollEvent(provider, delta.dy);
            } else {
              _sendMoveEvent(provider, delta.dx, delta.dy);
            }
          },
          onPanEnd: (details) {
            _lastPosition = null;
          },
          onTap: () {
            _handleTap(provider);
          },
          onDoubleTap: () {
            _sendDoubleClick(provider);
          },
          onLongPress: () {
            _sendRightClick(provider);
          },
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 64,
                    color: Colors.cyan.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Touchpad Area',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Swipe to move • Tap to click',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Long press for right click',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: _buildButton(
                  icon: Icons.mouse,
                  label: 'Left Click',
                  onPressed: () => _sendLeftClick(provider),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildButton(
                  icon: Icons.touch_app,
                  label: 'Right Click',
                  onPressed: () => _sendRightClick(provider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(ConnectionProvider provider) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    // Single tap = left click
    if (_tapCount == 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_tapCount == 1) {
          _sendLeftClick(provider);
        }
      });
    }
  }

  void _sendMoveEvent(ConnectionProvider provider, double dx, double dy) {
    final sensitivity = provider.sensitivity;
    final event = MoveEvent(
      deltaX: dx * sensitivity,
      deltaY: dy * sensitivity,
    );
    provider.sendMouseEvent(event);
  }

  void _sendLeftClick(ConnectionProvider provider) {
    _vibrate(provider);
    provider.sendMouseEvent(LeftClickEvent());
  }

  void _sendRightClick(ConnectionProvider provider) {
    _vibrate(provider);
    provider.sendMouseEvent(RightClickEvent());
  }

  void _sendDoubleClick(ConnectionProvider provider) {
    _vibrate(provider);
    provider.sendMouseEvent(DoubleClickEvent());
  }

  void _sendScrollEvent(ConnectionProvider provider, double delta) {
    final scrollSpeed = provider.scrollSpeed;
    final event = ScrollEvent(
      scrollAmount: delta * scrollSpeed * 0.1,
    );
    provider.sendMouseEvent(event);
  }

  Future<void> _vibrate(ConnectionProvider provider) async {
    if (provider.hapticFeedback) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 50);
      }
    }
  }
}
