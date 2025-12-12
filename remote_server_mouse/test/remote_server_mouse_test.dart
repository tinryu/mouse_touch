import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_server_mouse/server_controller.dart';

void main() {
  group('RemoteServerController', () {
    test('initializes without errors on supported platform', () async {
      final controller = RemoteServerController();

      if (!Platform.isWindows) {
        expect(controller.isRunning, isFalse);
        await controller.dispose();
        return;
      }

      await controller.initialize();
      expect(controller.serverIp.isNotEmpty, isTrue);
      await controller.dispose();
    });
  });
}
