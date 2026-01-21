import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../utils/constants.dart';
import '../utils/file_utils.dart';

/// HTTP server for receiving files
class HttpServerService {
  HttpServer? _server;
  bool _isRunning = false;

  final Map<String, _UploadSession> _uploadSessions = {};
  final StreamController<Transfer> _transferController =
      StreamController<Transfer>.broadcast();

  /// Stream of transfer updates
  Stream<Transfer> get transferStream => _transferController.stream;

  /// Check if server is running
  bool get isRunning => _isRunning;

  /// Start HTTP server
  Future<void> startServer({int port = AppConstants.httpPort}) async {
    if (_isRunning) {
      print('Server already running');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;

      print('HTTP server started on port $port');

      _server!.listen(_handleRequest);
    } catch (e) {
      print('Error starting server: $e');
      rethrow;
    }
  }

  /// Stop HTTP server
  Future<void> stopServer() async {
    if (!_isRunning || _server == null) return;

    await _server!.close();
    _server = null;
    _isRunning = false;

    // Cancel all upload sessions
    for (var session in _uploadSessions.values) {
      await session.file.close();
    }
    _uploadSessions.clear();

    print('HTTP server stopped');
  }

  /// Handle incoming HTTP request
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final uri = request.uri;

      if (uri.path == ApiEndpoints.ping) {
        await _handlePing(request);
      } else if (uri.path == ApiEndpoints.handshake) {
        await _handleHandshake(request);
      } else if (uri.path == ApiEndpoints.upload) {
        await _handleUpload(request);
      } else if (uri.path == ApiEndpoints.uploadChunk) {
        await _handleUploadChunk(request);
      } else if (uri.path == ApiEndpoints.uploadComplete) {
        await _handleUploadComplete(request);
      } else {
        await _sendResponse(request, 404, {'error': 'Not found'});
      }
    } catch (e) {
      print('Error handling request: $e');
      try {
        await _sendResponse(request, 500, {'error': e.toString()});
      } catch (_) {
        // Ignore if response already sent
      }
    }
  }

  /// Handle ping request
  Future<void> _handlePing(HttpRequest request) async {
    await _sendResponse(request, 200, {'status': 'ok'});
  }

  /// Handle handshake request
  Future<void> _handleHandshake(HttpRequest request) async {
    if (request.method != 'POST') {
      await _sendResponse(request, 405, {'error': 'Method not allowed'});
      return;
    }

    final body = await _readRequestBody(request);
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Parse sender device info
    final senderDevice = Device.fromJson(
      data['device'] as Map<String, dynamic>,
    );

    print('Handshake from: ${senderDevice.name}');

    // Todo: Show user confirmation dialog for pairing
    // For now, auto-accept

    await _sendResponse(request, 200, {
      'accepted': true,
      'message': 'Handshake accepted',
    });
  }

  /// Handle file upload (simple single-request upload for small files)
  Future<void> _handleUpload(HttpRequest request) async {
    if (request.method != 'POST') {
      await _sendResponse(request, 405, {'error': 'Method not allowed'});
      return;
    }

    try {
      // Get headers
      final fileName = request.headers.value('X-File-Name') ?? 'unknown_file';
      final fileSizeStr = request.headers.value('X-File-Size');
      final transferId =
          request.headers.value('X-Transfer-Id') ??
          DateTime.now().millisecondsSinceEpoch.toString();

      if (fileSizeStr == null) {
        await _sendResponse(request, 400, {'error': 'Missing file size'});
        return;
      }

      final fileSize = int.parse(fileSizeStr);

      // Prepare file path
      final directory = await _getReceiveDirectory();
      final safeFileName = FileUtils.getSafeFileName(fileName);
      final uniqueFileName = await FileUtils.getUniqueFileName(
        directory.path,
        safeFileName,
      );
      final filePath = '${directory.path}/$uniqueFileName';

      // Create transfer object
      final transfer = Transfer(
        id: transferId,
        fileName: uniqueFileName,
        fileSize: fileSize,
        filePath: filePath,
        status: TransferStatus.active,
        startTime: DateTime.now(),
      );

      _transferController.add(transfer);

      // Write file
      final file = File(filePath);
      final sink = file.openWrite();

      int bytesReceived = 0;
      final startTime = DateTime.now();

      await for (var chunk in request) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        // Update progress
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000;
        final speed = elapsed > 0 ? bytesReceived / elapsed : 0.0;

        transfer.updateProgress(bytesReceived, speed);
        _transferController.add(transfer);
      }

      await sink.close();

      // Mark as completed
      transfer.markCompleted();
      _transferController.add(transfer);

      print('File received: $uniqueFileName ($fileSize bytes)');

      await _sendResponse(request, 200, {
        'success': true,
        'fileName': uniqueFileName,
        'filePath': filePath,
      });
    } catch (e) {
      print('Error uploading file: $e');
      await _sendResponse(request, 500, {'error': e.toString()});
    }
  }

  /// Handle chunked upload (for large files)
  Future<void> _handleUploadChunk(HttpRequest request) async {
    if (request.method != 'POST') {
      await _sendResponse(request, 405, {'error': 'Method not allowed'});
      return;
    }

    try {
      final transferId = request.headers.value('X-Transfer-Id');
      final chunkIndexStr = request.headers.value('X-Chunk-Index');
      final fileName = request.headers.value('X-File-Name');
      final fileSizeStr = request.headers.value('X-File-Size');

      if (transferId == null ||
          chunkIndexStr == null ||
          fileName == null ||
          fileSizeStr == null) {
        await _sendResponse(request, 400, {
          'error': 'Missing required headers',
        });
        return;
      }

      final chunkIndex = int.parse(chunkIndexStr);
      final fileSize = int.parse(fileSizeStr);

      // Get or create upload session
      _UploadSession session;
      if (_uploadSessions.containsKey(transferId)) {
        session = _uploadSessions[transferId]!;
      } else {
        // Create new session
        final directory = await _getReceiveDirectory();
        final safeFileName = FileUtils.getSafeFileName(fileName);
        final uniqueFileName = await FileUtils.getUniqueFileName(
          directory.path,
          safeFileName,
        );
        final filePath = '${directory.path}/$uniqueFileName';

        session = _UploadSession(
          transferId: transferId,
          fileName: uniqueFileName,
          fileSize: fileSize,
          filePath: filePath,
          file: File(filePath).openWrite(),
          startTime: DateTime.now(),
        );

        _uploadSessions[transferId] = session;

        // Create transfer object
        final transfer = Transfer(
          id: transferId,
          fileName: uniqueFileName,
          fileSize: fileSize,
          filePath: filePath,
          status: TransferStatus.active,
          startTime: session.startTime,
        );

        _transferController.add(transfer);
      }

      // Write chunk
      final chunkData = await request.fold<List<int>>(
        [],
        (previous, element) => previous..addAll(element),
      );
      session.file.add(chunkData);
      session.bytesReceived += chunkData.length;
      session.chunksReceived++;

      // Update progress
      final elapsed =
          DateTime.now().difference(session.startTime).inMilliseconds / 1000;
      final speed = elapsed > 0 ? session.bytesReceived / elapsed : 0.0;

      final transfer = Transfer(
        id: transferId,
        fileName: session.fileName,
        fileSize: session.fileSize,
        filePath: session.filePath,
        status: TransferStatus.active,
        bytesTransferred: session.bytesReceived,
        speed: speed,
        startTime: session.startTime,
      );

      _transferController.add(transfer);

      print(
        'Chunk $chunkIndex received (${session.bytesReceived}/${session.fileSize} bytes)',
      );

      await _sendResponse(request, 200, {
        'success': true,
        'chunkIndex': chunkIndex,
        'bytesReceived': session.bytesReceived,
      });
    } catch (e) {
      print('Error uploading chunk: $e');
      await _sendResponse(request, 500, {'error': e.toString()});
    }
  }

  /// Handle upload completion
  Future<void> _handleUploadComplete(HttpRequest request) async {
    if (request.method != 'POST') {
      await _sendResponse(request, 405, {'error': 'Method not allowed'});
      return;
    }

    try {
      final transferId = request.headers.value('X-Transfer-Id');

      if (transferId == null) {
        await _sendResponse(request, 400, {'error': 'Missing transfer ID'});
        return;
      }

      final session = _uploadSessions[transferId];
      if (session == null) {
        await _sendResponse(request, 404, {
          'error': 'Upload session not found',
        });
        return;
      }

      // Close file
      await session.file.close();

      // Mark as completed
      final transfer = Transfer(
        id: transferId,
        fileName: session.fileName,
        fileSize: session.fileSize,
        filePath: session.filePath,
        status: TransferStatus.completed,
        bytesTransferred: session.bytesReceived,
        startTime: session.startTime,
        endTime: DateTime.now(),
      );

      _transferController.add(transfer);

      // Clean up session
      _uploadSessions.remove(transferId);

      print('Upload complete: ${session.fileName}');

      await _sendResponse(request, 200, {
        'success': true,
        'fileName': session.fileName,
        'filePath': session.filePath,
      });
    } catch (e) {
      print('Error completing upload: $e');
      await _sendResponse(request, 500, {'error': e.toString()});
    }
  }

  /// Get directory for received files
  Future<Directory> _getReceiveDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiveDir = Directory(
      '${appDir.path}/${AppConstants.receivedFilesFolder}',
    );

    if (!await receiveDir.exists()) {
      await receiveDir.create(recursive: true);
    }

    return receiveDir;
  }

  /// Read request body
  Future<String> _readRequestBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    return content;
  }

  /// Send JSON response
  Future<void> _sendResponse(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data));

    await request.response.close();
  }

  /// Dispose the service
  void dispose() {
    stopServer();
    _transferController.close();
  }
}

/// Upload session for chunked transfers
class _UploadSession {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String filePath;
  final IOSink file;
  final DateTime startTime;
  int bytesReceived = 0;
  int chunksReceived = 0;

  _UploadSession({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    required this.file,
    required this.startTime,
  });
}
