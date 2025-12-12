import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:image/image.dart' as img;
import 'config.dart';

/// Screen capture handler using Win32 GDI
class ScreenCapture {
  /// Capture screen and compress to JPEG
  static Future<Map<String, dynamic>?> captureScreen({
    int monitorId = 0,
    int quality = Config.defaultQuality,
  }) async {
    return _captureWin32(quality);
  }

  static Future<Map<String, dynamic>?> _captureWin32(int quality) async {
    final hwnd = 0; // Desktop
    final hdcScreen = GetDC(hwnd);
    final hdcMem = CreateCompatibleDC(hdcScreen);

    // Get screen dimensions
    final width = GetSystemMetrics(SM_CXSCREEN);
    final height = GetSystemMetrics(SM_CYSCREEN);

    final hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);
    final hOldBitmap = SelectObject(hdcMem, hBitmap);

    // Copy screen to memory DC
    BitBlt(hdcMem, 0, 0, width, height, hdcScreen, 0, 0, SRCCOPY);

    // Setup BITMAPINFO to get 32-bit RGBA (actually BGRA in Windows)
    final bmi = calloc<BITMAPINFO>();
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = width;
    bmi.ref.bmiHeader.biHeight = -height; // Top-down
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32;
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    // Calculate buffer size
    // 32 bits = 4 bytes per pixel
    final imageSize = width * height * 4;
    final pPixels = calloc<Uint8>(imageSize);

    try {
      // Get bits
      final result = GetDIBits(
        hdcMem,
        hBitmap,
        0,
        height,
        pPixels,
        bmi,
        DIB_RGB_COLORS,
      );

      if (result == 0) {
        print('Failed to get DIB bits');
        return null;
      }

      // Create image from raw bytes
      // pPixels contains BGRA data
      final bytes = pPixels.asTypedList(imageSize);

      // Convert BGRA to RGBA for package:image
      // This is efficient enough for now, but could be optimized with FFI if needed
      for (var i = 0; i < bytes.length; i += 4) {
        final b = bytes[i];
        final r = bytes[i + 2];
        bytes[i] = r;
        bytes[i + 2] = b;
      }

      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: bytes.buffer,
        order: img.ChannelOrder.rgba,
      );

      // Encode to JPEG
      final jpegBytes = img.encodeJpg(image, quality: quality);

      return {
        'buffer': Uint8List.fromList(jpegBytes),
        'width': width,
        'height': height,
        'size': jpegBytes.length,
        'codec': 'jpeg',
      };
    } catch (e) {
      print('Screen capture error: $e');
      return null;
    } finally {
      // Cleanup
      free(pPixels);
      free(bmi);
      SelectObject(hdcMem, hOldBitmap);
      DeleteObject(hBitmap);
      DeleteDC(hdcMem);
      ReleaseDC(hwnd, hdcScreen);
    }
  }

  /// Get screen information
  static Future<Map<String, dynamic>> getScreenInfo() async {
    // Basic info for now
    final width = GetSystemMetrics(SM_CXSCREEN);
    final height = GetSystemMetrics(SM_CYSCREEN);

    return {
      'monitors': [
        {
          'id': 0,
          'name': 'Primary Display',
          'width': width,
          'height': height,
          'primary': true,
        },
      ],
      'primaryMonitor': 0,
    };
  }
}
