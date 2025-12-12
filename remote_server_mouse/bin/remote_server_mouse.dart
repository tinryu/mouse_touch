import 'dart:async';
import 'dart:io';

import 'package:remote_server_mouse/server_controller.dart';

Future<void> main(List<String> args) async {
  final controller = RemoteServerController(onLog: print);

  await controller.initialize();
  await controller.start();

  print('');
  print('📟 Remote Server Mouse CLI running.');
  print('    Press CTRL+C to stop.');

  final completer = Completer<void>();
  StreamSubscription<ProcessSignal>? sigIntSub;
  StreamSubscription<ProcessSignal>? sigTermSub;

  Future<void> shutdown() async {
    await controller.stop();
    await controller.dispose();
    await sigIntSub?.cancel();
    await sigTermSub?.cancel();
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  sigIntSub = ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\n🛑 SIGINT received.');
    await shutdown();
  });

  sigTermSub = ProcessSignal.sigterm.watch().listen((_) async {
    stdout.writeln('\n🛑 SIGTERM received.');
    await shutdown();
  });

  await completer.future;
  stdout.writeln('✓ Server stopped. Bye 👋');
}
