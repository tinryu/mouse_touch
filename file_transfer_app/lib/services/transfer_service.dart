import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../utils/constants.dart';
import 'relay_service.dart';

/// Service for sending files to other devices
class TransferService {
  final Map<String, Transfer> _activeTransfers = {};
  final StreamController<Transfer> _transferController =
      StreamController<Transfer>.broadcast();

  /// Stream of transfer updates
  Stream<Transfer> get transferStream => _transferController.stream;

  /// Get active transfers
  List<Transfer> get activeTransfers => _activeTransfers.values.toList();

  /// Send file to device
  Future<Transfer> sendFile({
    required String filePath,
    required Device receiver,
    Device? sender,
    RelayService? relayService,
  }) async {
    final file = File(filePath);

    // Validate file
    if (!await file.exists()) {
      throw Exception('File does not exist');
    }

    final fileSize = await file.length();
    final fileName = filePath.split(Platform.pathSeparator).last;

    // Create transfer
    final transferId = const Uuid().v4();
    final transfer = Transfer(
      id: transferId,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      sender: sender,
      receiver: receiver,
      status: TransferStatus.pending,
      startTime: DateTime.now(),
    );

    _activeTransfers[transferId] = transfer;
    _transferController.add(transfer);

    // Start transfer in background
    _performTransfer(transfer, file, relayService);

    return transfer;
  }

  /// Perform the actual file transfer
  Future<void> _performTransfer(
    Transfer transfer,
    File file,
    RelayService? relayService,
  ) async {
    try {
      // Update status to connecting
      transfer.status = TransferStatus.connecting;
      _transferController.add(transfer);

      final receiver = transfer.receiver!;

      // Perform handshake
      final handshakeSuccess = await _performHandshake(receiver);
      if (!handshakeSuccess) {
        throw Exception('Handshake failed');
      }

      // Update status to active
      transfer.status = TransferStatus.active;
      _transferController.add(transfer);

      // Check if relay
      if (receiver.ipAddress == 'relay') {
        if (relayService == null || !relayService.isConnected) {
          throw Exception('Relay service not connected');
        }
        await _sendFileRelay(transfer, file, relayService);
      } else if (transfer.fileSize <= AppConstants.chunkSize) {
        // Small file: send in single request
        await _sendFileSimple(transfer, file);
      } else {
        // Large file: send in chunks
        await _sendFileChunked(transfer, file);
      }

      _activeTransfers.remove(transfer.id);
    } catch (e) {
      print('Transfer failed: $e');
      transfer.markFailed(e.toString());
      _transferController.add(transfer);
      _activeTransfers.remove(transfer.id);
    }
  }

  /// Send file via Relay (WebSocket)
  Future<void> _sendFileRelay(
    Transfer transfer,
    File file,
    RelayService relayService,
  ) async {
    final receiver = transfer.receiver!;
    final startTime = DateTime.now();

    // Handshake/Start
    relayService.sendMessage(receiver.id, {
      'type': 'file_start',
      'transferId': transfer.id,
      'fileName': transfer.fileName,
      'fileSize': transfer.fileSize,
    });

    // Wait for Ack? For simplicity, we assume start is acked implicitly or continue.
    // Ideally we wait for 'ack_file_start' via relayService stream but that requires complex state.
    // We'll proceed to stream chunks.

    final fileStream = file.openRead();
    int chunkIndex = 0;
    int bytesTransferred = 0;

    // Use smaller chunks for WebSocket (512KB)
    final int relayChunkSize = 512 * 1024;
    final List<int> chunkBuffer = [];

    await for (var chunk in fileStream) {
      chunkBuffer.addAll(chunk);

      while (chunkBuffer.length >= relayChunkSize ||
          (chunkBuffer.isNotEmpty &&
              bytesTransferred + chunkBuffer.length >= transfer.fileSize)) {
        // Take a chunk
        final int sizeToTake = chunkBuffer.length >= relayChunkSize
            ? relayChunkSize
            : chunkBuffer.length;
        final currentChunk = chunkBuffer.sublist(0, sizeToTake);
        // Remove from buffer
        chunkBuffer.removeRange(0, sizeToTake);

        // Send chunk
        relayService.sendMessage(receiver.id, {
          'type': 'file_chunk',
          'transferId': transfer.id,
          'chunkIndex': chunkIndex,
          'data': base64Encode(currentChunk),
        });

        bytesTransferred += sizeToTake;
        chunkIndex++;

        // Update progress
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000;
        final speed = elapsed > 0 ? bytesTransferred / elapsed : 0.0;
        transfer.updateProgress(bytesTransferred, speed);
        _transferController.add(transfer);

        // Small delay to prevent flooding WS buffer if needed
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }

    // Send complete
    relayService.sendMessage(receiver.id, {
      'type': 'file_complete',
      'transferId': transfer.id,
    });
  }

  /// Perform handshake with receiver
  Future<bool> _performHandshake(Device receiver) async {
    try {
      final url =
          'http://${receiver.ipAddress}:${receiver.port}${ApiEndpoints.handshake}';

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device': receiver.toJson()}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['accepted'] == true;
      }

      return false;
    } catch (e) {
      print('Handshake error: $e');
      return false;
    }
  }

  /// Send file in single request (for small files)
  Future<void> _sendFileSimple(Transfer transfer, File file) async {
    final receiver = transfer.receiver!;
    final url =
        'http://${receiver.ipAddress}:${receiver.port}${ApiEndpoints.upload}';

    final startTime = DateTime.now();
    final fileBytes = await file.readAsBytes();

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['X-File-Name'] = transfer.fileName;
    request.headers['X-File-Size'] = transfer.fileSize.toString();
    request.headers['X-Transfer-Id'] = transfer.id;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: transfer.fileName,
      ),
    );

    // Send request with progress tracking
    final streamedResponse = await request.send();

    // Read response
    if (streamedResponse.statusCode == 200) {
      final responseBody = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data['success'] == true) {
        // Update final progress
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000;
        final speed = elapsed > 0 ? transfer.fileSize / elapsed : 0.0;
        transfer.updateProgress(transfer.fileSize, speed);
        _transferController.add(transfer);
      } else {
        throw Exception('Upload failed');
      }
    } else {
      throw Exception('HTTP ${streamedResponse.statusCode}');
    }
  }

  /// Send file in chunks (for large files)
  Future<void> _sendFileChunked(Transfer transfer, File file) async {
    final receiver = transfer.receiver!;
    final baseUrl = 'http://${receiver.ipAddress}:${receiver.port}';

    final startTime = DateTime.now();
    final fileStream = file.openRead();

    int chunkIndex = 0;
    int bytesTransferred = 0;
    final List<int> chunkBuffer = [];

    await for (var chunk in fileStream) {
      chunkBuffer.addAll(chunk);

      // Send chunk when buffer reaches chunk size or at end of file
      if (chunkBuffer.length >= AppConstants.chunkSize ||
          bytesTransferred + chunkBuffer.length >= transfer.fileSize) {
        // Send chunk
        final url = '$baseUrl${ApiEndpoints.uploadChunk}';
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/octet-stream',
                'X-Transfer-Id': transfer.id,
                'X-Chunk-Index': chunkIndex.toString(),
                'X-File-Name': transfer.fileName,
                'X-File-Size': transfer.fileSize.toString(),
              },
              body: chunkBuffer,
            )
            .timeout(AppConstants.transferTimeout);

        if (response.statusCode != 200) {
          throw Exception('Chunk upload failed: HTTP ${response.statusCode}');
        }

        bytesTransferred += chunkBuffer.length;
        chunkIndex++;

        // Update progress
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000;
        final speed = elapsed > 0 ? bytesTransferred / elapsed : 0.0;
        transfer.updateProgress(bytesTransferred, speed);
        _transferController.add(transfer);

        // Clear buffer
        chunkBuffer.clear();
      }
    }

    // Send completion signal
    final completeUrl = '$baseUrl${ApiEndpoints.uploadComplete}';
    final response = await http
        .post(Uri.parse(completeUrl), headers: {'X-Transfer-Id': transfer.id})
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Upload completion failed');
    }
  }

  /// Ping device to check if reachable
  Future<bool> pingDevice(Device device) async {
    try {
      final url =
          'http://${device.ipAddress}:${device.port}${ApiEndpoints.ping}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Cancel transfer
  Future<void> cancelTransfer(String transferId) async {
    final transfer = _activeTransfers[transferId];
    if (transfer != null) {
      transfer.markCancelled();
      _transferController.add(transfer);
      _activeTransfers.remove(transferId);
    }
  }

  /// Get transfer by ID
  Transfer? getTransfer(String transferId) {
    return _activeTransfers[transferId];
  }

  /// Dispose the service
  void dispose() {
    _transferController.close();
    _activeTransfers.clear();
  }
}
