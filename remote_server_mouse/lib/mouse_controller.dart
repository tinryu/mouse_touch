import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Mouse and keyboard controller using Win32 API
class MouseController {
  /// Handle mouse control commands
  static Future<void> handleMouseControl(Map<String, dynamic> data) async {
    try {
      final action = data['action'] as String;

      switch (action) {
        case 'move':
          await _handleMove(data);
          break;

        case 'click':
          await _handleClick(data);
          break;

        case 'scroll':
          await _handleScroll(data);
          break;

        case 'drag_start':
          await _handleDragStart(data);
          break;

        case 'drag_end':
          await _handleDragEnd(data);
          break;

        case 'zoom':
          final delta = (data['delta'] as num).toDouble();
          await _handleZoom(delta);
          break;
      }
    } catch (e) {
      print('Mouse control error: $e');
    }
  }

  /// Handle mouse movement
  static Future<void> _handleMove(Map<String, dynamic> data) async {
    final normalized = data['normalized'] as bool? ?? false;

    if (normalized) {
      // Absolute positioning (normalized coordinates 0-1)
      final x = (data['x'] as num).toDouble();
      final y = (data['y'] as num).toDouble();

      // Convert to screen coordinates (0-65535 range for absolute positioning)
      final screenX = (x * 65535).round();
      final screenY = (y * 65535).round();

      // Create INPUT structure for absolute mouse movement
      final input = calloc<INPUT>();
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dx = screenX;
      input.ref.mi.dy = screenY;
      input.ref.mi.dwFlags =
          MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE | MOUSEEVENTF_VIRTUALDESK;

      SendInput(1, input, sizeOf<INPUT>());
      calloc.free(input);
    } else {
      // Relative movement
      final dx = (data['dx'] as num?)?.toInt() ?? 0;
      final dy = (data['dy'] as num?)?.toInt() ?? 0;

      final input = calloc<INPUT>();
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dx = dx;
      input.ref.mi.dy = dy;
      input.ref.mi.dwFlags = MOUSEEVENTF_MOVE;

      SendInput(1, input, sizeOf<INPUT>());
      calloc.free(input);
    }
  }

  /// Handle mouse click
  static Future<void> _handleClick(Map<String, dynamic> data) async {
    final button = data['button'] as String? ?? 'left';
    final isDouble = data['double'] as bool? ?? false;

    // Move to position if coordinates provided
    if (data.containsKey('x') && data.containsKey('y')) {
      await _handleMove({...data, 'normalized': true});
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Perform click
    final (downFlag, upFlag) = _getMouseButtonFlags(button);

    final input = calloc<INPUT>();
    input.ref.type = INPUT_MOUSE;

    // Mouse down
    input.ref.mi.dwFlags = downFlag;
    SendInput(1, input, sizeOf<INPUT>());

    await Future.delayed(const Duration(milliseconds: 10));

    // Mouse up
    input.ref.mi.dwFlags = upFlag;
    SendInput(1, input, sizeOf<INPUT>());

    if (isDouble) {
      await Future.delayed(const Duration(milliseconds: 50));

      // Second click
      input.ref.mi.dwFlags = downFlag;
      SendInput(1, input, sizeOf<INPUT>());
      await Future.delayed(const Duration(milliseconds: 10));
      input.ref.mi.dwFlags = upFlag;
      SendInput(1, input, sizeOf<INPUT>());
    }

    calloc.free(input);
  }

  /// Handle scroll
  static Future<void> _handleScroll(Map<String, dynamic> data) async {
    final dx = (data['dx'] as num?)?.toInt() ?? 0;
    final dy = (data['dy'] as num?)?.toInt() ?? 0;

    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;

      if (dy != 0) {
        // Vertical scroll - direct mapping from delta
        input.ref.mi.dwFlags = MOUSEEVENTF_WHEEL;
        input.ref.mi.mouseData = dy * 120;
        SendInput(1, input, sizeOf<INPUT>());
      }

      if (dx != 0) {
        // Horizontal scroll
        input.ref.mi.dwFlags = MOUSEEVENTF_HWHEEL;
        input.ref.mi.mouseData = dx * 120;
        SendInput(1, input, sizeOf<INPUT>());
      }
    } finally {
      calloc.free(input);
    }
  }

  /// Handle zoom (Ctrl + Scroll)
  static Future<void> _handleZoom(double delta) async {
    final input = calloc<INPUT>();
    try {
      // Press Ctrl
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = VK_CONTROL;
      input.ref.ki.dwFlags = 0;
      SendInput(1, input, sizeOf<INPUT>());

      await Future.delayed(const Duration(milliseconds: 10));

      // Scroll
      input.ref.type = INPUT_MOUSE;
      final wheelDelta = (delta * 1200).round();
      input.ref.mi.dwFlags = MOUSEEVENTF_WHEEL;
      input.ref.mi.mouseData = wheelDelta;
      SendInput(1, input, sizeOf<INPUT>());

      await Future.delayed(const Duration(milliseconds: 10));

      // Release Ctrl
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = VK_CONTROL;
      input.ref.ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  /// Handle drag start
  static Future<void> _handleDragStart(Map<String, dynamic> data) async {
    final button = data['button'] as String? ?? 'left';
    final (downFlag, _) = _getMouseButtonFlags(button);

    final input = calloc<INPUT>();
    input.ref.type = INPUT_MOUSE;
    input.ref.mi.dwFlags = downFlag;

    SendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);
  }

  /// Handle drag end
  static Future<void> _handleDragEnd(Map<String, dynamic> data) async {
    final button = data['button'] as String? ?? 'left';
    final (_, upFlag) = _getMouseButtonFlags(button);

    final input = calloc<INPUT>();
    input.ref.type = INPUT_MOUSE;
    input.ref.mi.dwFlags = upFlag;

    SendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);
  }

  /// Get mouse button flags
  static (int, int) _getMouseButtonFlags(String button) {
    switch (button.toLowerCase()) {
      case 'right':
        return (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP);
      case 'middle':
        return (MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP);
      default: // left
        return (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP);
    }
  }

  /// Handle keyboard control commands (basic implementation)
  static Future<void> handleKeyboardControl(Map<String, dynamic> data) async {
    try {
      final action = data['action'] as String;

      switch (action) {
        case 'type':
          final text = data['text'] as String;
          await typeText(text);
          break;
        case 'backspace':
          await backspace();
          break;
      }
    } catch (e) {
      print('Keyboard control error: $e');
    }
  }

  /// Public exposure of backspace
  static Future<void> backspace() async {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = VK_BACK;
      input.ref.ki.dwFlags = 0;
      SendInput(1, input, sizeOf<INPUT>());

      await Future.delayed(const Duration(milliseconds: 10));

      input.ref.ki.wVk = VK_BACK;
      input.ref.ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  /// Public exposure of typeText
  static Future<void> typeText(String text) async {
    for (var char in text.runes) {
      final input = calloc<INPUT>();
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wScan = char;
      input.ref.ki.dwFlags = KEYEVENTF_UNICODE;
      SendInput(1, input, sizeOf<INPUT>());

      input.ref.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
      SendInput(1, input, sizeOf<INPUT>());
      calloc.free(input);
    }
  }
}
