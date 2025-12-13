import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'models/mouse_event.dart';

/// Controller for Windows mouse operations using Win32 API
class MouseController {
  /// Move the mouse cursor by relative delta
  void moveMouse(double deltaX, double deltaY) {
    // Get current cursor position
    final point = calloc<POINT>();
    try {
      GetCursorPos(point);
      final currentX = point.ref.x;
      final currentY = point.ref.y;

      // Calculate new position
      final newX = currentX + deltaX.toInt();
      final newY = currentY + deltaY.toInt();

      // Set new cursor position
      SetCursorPos(newX, newY);
      print('Mouse moved to: ($newX, $newY)');
    } finally {
      calloc.free(point);
    }
  }

  /// Perform a left mouse button click
  void leftClick() {
    _mouseEvent(MOUSEEVENTF_LEFTDOWN);
    _mouseEvent(MOUSEEVENTF_LEFTUP);
    print('Left click performed');
  }

  /// Perform a right mouse button click
  void rightClick() {
    _mouseEvent(MOUSEEVENTF_RIGHTDOWN);
    _mouseEvent(MOUSEEVENTF_RIGHTUP);
    print('Right click performed');
  }

  /// Perform a double click
  void doubleClick() {
    leftClick();
    // Small delay between clicks
    Future.delayed(Duration(milliseconds: 50), () => leftClick());
    print('Double click performed');
  }

  /// Press left mouse button down
  void leftDown() {
    _mouseEvent(MOUSEEVENTF_LEFTDOWN);
    print('Left button down');
  }

  /// Release left mouse button
  void leftUp() {
    _mouseEvent(MOUSEEVENTF_LEFTUP);
    print('Left button up');
  }

  /// Press right mouse button down
  void rightDown() {
    _mouseEvent(MOUSEEVENTF_RIGHTDOWN);
    print('Right button down');
  }

  /// Release right mouse button
  void rightUp() {
    _mouseEvent(MOUSEEVENTF_RIGHTUP);
    print('Right button up');
  }

  /// Scroll the mouse wheel
  void scroll(double amount) {
    // Windows expects scroll amount in multiples of WHEEL_DELTA (120)
    final scrollAmount = (amount * 120).toInt();
    
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = MOUSEEVENTF_WHEEL;
      input.ref.mi.mouseData = scrollAmount;
      
      SendInput(1, input, sizeOf<INPUT>());
      print('Scrolled: $amount');
    } finally {
      calloc.free(input);
    }
  }

  /// Helper method to send mouse events
  void _mouseEvent(int flags) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = flags;
      
      SendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  /// Process a MouseEvent and execute the corresponding action
  void handleMouseEvent(MouseEvent event) {
    try {
      switch (event.type) {
        case MouseEventType.move:
          if (event.deltaX != null && event.deltaY != null) {
            moveMouse(event.deltaX!, event.deltaY!);
          }
          break;
        case MouseEventType.leftClick:
          leftClick();
          break;
        case MouseEventType.rightClick:
          rightClick();
          break;
        case MouseEventType.doubleClick:
          doubleClick();
          break;
        case MouseEventType.scroll:
          if (event.scrollAmount != null) {
            scroll(event.scrollAmount!);
          }
          break;
        case MouseEventType.leftDown:
          leftDown();
          break;
        case MouseEventType.leftUp:
          leftUp();
          break;
        case MouseEventType.rightDown:
          rightDown();
          break;
        case MouseEventType.rightUp:
          rightUp();
          break;
      }
    } catch (e) {
      print('Error handling mouse event: $e');
    }
  }
}
