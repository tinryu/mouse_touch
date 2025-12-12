import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class Win32MouseController {
  /// Move mouse cursor by relative delta
  static void moveMouse(double dx, double dy) {
    // Get current cursor position
    final point = calloc<POINT>();
    try {
      GetCursorPos(point);

      // Calculate new position
      final newX = point.ref.x + dx.round();
      final newY = point.ref.y + dy.round();

      // Set new cursor position
      SetCursorPos(newX, newY);
    } finally {
      calloc.free(point);
    }
  }

  /// Perform mouse click
  static void click(String button) {
    switch (button.toLowerCase()) {
      case 'left':
        _leftClick();
        break;
      case 'right':
        _rightClick();
        break;
      case 'middle':
        _middleClick();
        break;
    }
  }

  static void _leftClick() {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
      SendInput(1, input, sizeOf<INPUT>());

      Sleep(10);

      input.ref.mi.dwFlags = MOUSEEVENTF_LEFTUP;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  static void _rightClick() {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
      SendInput(1, input, sizeOf<INPUT>());

      Sleep(10);

      input.ref.mi.dwFlags = MOUSEEVENTF_RIGHTUP;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  static void _middleClick() {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
      SendInput(1, input, sizeOf<INPUT>());

      Sleep(10);

      input.ref.mi.dwFlags = MOUSEEVENTF_MIDDLEUP;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  /// Scroll mouse wheel
  static void scroll(double dx, double dy) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;

      if (dy != 0) {
        // Vertical scroll
        final wheelDelta = (dy * -120)
            .round(); // Negative for natural scrolling
        input.ref.mi.dwFlags = MOUSEEVENTF_WHEEL;
        input.ref.mi.mouseData = wheelDelta;
        SendInput(1, input, sizeOf<INPUT>());
      }

      if (dx != 0) {
        // Horizontal scroll
        final wheelDelta = (dx * 120).round();
        input.ref.mi.dwFlags = MOUSEEVENTF_HWHEEL;
        input.ref.mi.mouseData = wheelDelta;
        SendInput(1, input, sizeOf<INPUT>());
      }
    } finally {
      calloc.free(input);
    }
  }

  /// Zoom (Ctrl + Scroll)
  static void zoom(double delta) {
    final input = calloc<INPUT>();
    try {
      // Press Ctrl
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = VK_CONTROL;
      input.ref.ki.dwFlags = 0;
      SendInput(1, input, sizeOf<INPUT>());

      Sleep(10);

      // Scroll
      input.ref.type = INPUT_MOUSE;
      final wheelDelta = (delta * 1200).round();
      input.ref.mi.dwFlags = MOUSEEVENTF_WHEEL;
      input.ref.mi.mouseData = wheelDelta;
      SendInput(1, input, sizeOf<INPUT>());

      Sleep(10);

      // Release Ctrl
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = VK_CONTROL;
      input.ref.ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  /// Type text
  static void typeText(String text) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_KEYBOARD;

      for (var i = 0; i < text.length; i++) {
        final charCode = text.codeUnitAt(i);

        // Key down
        input.ref.ki.wScan = charCode;
        input.ref.ki.dwFlags = KEYEVENTF_UNICODE;
        SendInput(1, input, sizeOf<INPUT>());

        // Key up
        input.ref.ki.wScan = charCode;
        input.ref.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        SendInput(1, input, sizeOf<INPUT>());
      }
    } finally {
      calloc.free(input);
    }
  }

  /// Press Backspace
  static void backspace() {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = VK_BACK;
      input.ref.ki.dwFlags = 0;
      SendInput(1, input, sizeOf<INPUT>());

      Sleep(10);

      input.ref.ki.wVk = VK_BACK;
      input.ref.ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }
}
