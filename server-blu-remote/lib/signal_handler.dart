import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'mouse_controller.dart';
import 'models/mouse_event.dart';

/// Handles incoming WebSocket signals and routes them to the mouse controller
class SignalHandler {
  final MouseController _mouseController = MouseController();

  /// Process incoming WebSocket message
  void handleMessage(String message, WebSocketChannel channel) {
    try {
      print('Received message: $message');
      
      // Parse JSON message
      final data = jsonDecode(message) as Map<String, dynamic>;
      
      // Create MouseEvent from JSON
      final mouseEvent = MouseEvent.fromJson(data);
      
      // Handle the mouse event
      _mouseController.handleMouseEvent(mouseEvent);
      
      // Send acknowledgment back to client
      channel.sink.add(jsonEncode({
        'status': 'success',
        'message': 'Event processed',
        'event': mouseEvent.toJson(),
      }));
    } catch (e) {
      print('Error processing message: $e');
      
      // Send error response
      channel.sink.add(jsonEncode({
        'status': 'error',
        'message': 'Failed to process event: $e',
      }));
    }
  }

  /// Handle WebSocket connection
  void handleConnection(WebSocketChannel channel) {
    print('New WebSocket connection established');
    
    // Send welcome message
    channel.sink.add(jsonEncode({
      'status': 'connected',
      'message': 'Connected to server-blu-remote',
    }));

    // Listen for messages
    channel.stream.listen(
      (message) {
        if (message is String) {
          handleMessage(message, channel);
        }
      },
      onDone: () {
        print('WebSocket connection closed');
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
    );
  }
}
