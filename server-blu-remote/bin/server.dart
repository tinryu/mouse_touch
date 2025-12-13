import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:server_blu_remote/signal_handler.dart';

void main() async {
  final signalHandler = SignalHandler();
  
  // Create WebSocket handler
  final wsHandler = webSocketHandler((webSocket) {
    signalHandler.handleConnection(webSocket);
  });

  // Create handler pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(wsHandler);

  // Get port from environment or use default
  final port = int.parse(Platform.environment['PORT'] ?? '9090');
  
  // Get IP address
  final ip = InternetAddress.anyIPv4;

  // Start the server
  final server = await shelf_io.serve(handler, ip, port);
  
  print('╔════════════════════════════════════════════════════════════╗');
  print('║         Server-Blu-Remote - WebSocket Server              ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');
  print('Server running on: ws://${server.address.host}:${server.port}');
  print('');
  print('Waiting for connections from Flutter remote mouse app...');
  print('Press Ctrl+C to stop the server');
  print('');
  print('════════════════════════════════════════════════════════════');
}
