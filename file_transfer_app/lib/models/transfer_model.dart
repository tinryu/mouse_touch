import 'device_model.dart';
import '../utils/constants.dart';

/// Transfer model representing a file transfer
class Transfer {
  final String id;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final Device? sender;
  final Device? receiver;
  TransferStatus status;
  int bytesTransferred;
  double speed; // bytes per second
  final DateTime startTime;
  DateTime? endTime;
  String? errorMessage;

  Transfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.filePath,
    this.sender,
    this.receiver,
    this.status = TransferStatus.pending,
    this.bytesTransferred = 0,
    this.speed = 0.0,
    required this.startTime,
    this.endTime,
    this.errorMessage,
  });

  /// Create transfer from database map
  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      fileSize: map['fileSize'] as int,
      filePath: map['filePath'] as String?,
      sender: map['senderData'] != null
          ? Device.fromJson(map['senderData'] as Map<String, dynamic>)
          : null,
      receiver: map['receiverData'] != null
          ? Device.fromJson(map['receiverData'] as Map<String, dynamic>)
          : null,
      status: TransferStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransferStatus.pending,
      ),
      bytesTransferred: map['bytesTransferred'] as int,
      speed: map['speed'] as double,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  /// Convert transfer to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileSize': fileSize,
      'filePath': filePath,
      'senderData': sender?.toJson(),
      'receiverData': receiver?.toJson(),
      'status': status.name,
      'bytesTransferred': bytesTransferred,
      'speed': speed,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  /// Get progress percentage (0-100)
  double get progressPercentage {
    if (fileSize == 0) return 0;
    return (bytesTransferred / fileSize * 100).clamp(0, 100);
  }

  /// Get remaining bytes
  int get remainingBytes {
    return (fileSize - bytesTransferred).clamp(0, fileSize);
  }

  /// Check if transfer is complete
  bool get isComplete {
    return status == TransferStatus.completed;
  }

  /// Check if transfer is active
  bool get isActive {
    return status == TransferStatus.active ||
        status == TransferStatus.connecting;
  }

  /// Check if transfer failed
  bool get isFailed {
    return status == TransferStatus.failed ||
        status == TransferStatus.cancelled;
  }

  /// Get duration
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Get average speed in bytes per second
  double get averageSpeed {
    final durationSeconds = duration.inSeconds;
    if (durationSeconds == 0) return 0;
    return bytesTransferred / durationSeconds;
  }

  /// Update progress
  void updateProgress(int bytes, double currentSpeed) {
    bytesTransferred = bytes;
    speed = currentSpeed;

    if (bytesTransferred >= fileSize) {
      status = TransferStatus.completed;
      endTime = DateTime.now();
    }
  }

  /// Mark as failed
  void markFailed(String error) {
    status = TransferStatus.failed;
    errorMessage = error;
    endTime = DateTime.now();
  }

  /// Mark as cancelled
  void markCancelled() {
    status = TransferStatus.cancelled;
    endTime = DateTime.now();
  }

  /// Mark as completed
  void markCompleted() {
    status = TransferStatus.completed;
    bytesTransferred = fileSize;
    endTime = DateTime.now();
  }

  @override
  String toString() {
    return 'Transfer(file: $fileName, status: $status, progress: ${progressPercentage.toStringAsFixed(1)}%)';
  }
}
