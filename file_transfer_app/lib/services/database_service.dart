import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transfer_model.dart';
import '../models/device_model.dart';
import '../utils/constants.dart';

/// Service for managing transfer history in SQLite database
class DatabaseService {
  static Database? _database;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        fileName TEXT NOT NULL,
        fileSize INTEGER NOT NULL,
        filePath TEXT,
        senderData TEXT,
        receiverData TEXT,
        status TEXT NOT NULL,
        bytesTransferred INTEGER NOT NULL DEFAULT 0,
        speed REAL NOT NULL DEFAULT 0.0,
        startTime TEXT NOT NULL,
        endTime TEXT,
        errorMessage TEXT
      )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_status ON transfers(status)');
    await db.execute('CREATE INDEX idx_startTime ON transfers(startTime DESC)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema changes
  }

  /// Insert transfer
  Future<void> insertTransfer(Transfer transfer) async {
    final db = await database;

    await db.insert('transfers', {
      'id': transfer.id,
      'fileName': transfer.fileName,
      'fileSize': transfer.fileSize,
      'filePath': transfer.filePath,
      'senderData': transfer.sender != null
          ? jsonEncode(transfer.sender!.toJson())
          : null,
      'receiverData': transfer.receiver != null
          ? jsonEncode(transfer.receiver!.toJson())
          : null,
      'status': transfer.status.name,
      'bytesTransferred': transfer.bytesTransferred,
      'speed': transfer.speed,
      'startTime': transfer.startTime.toIso8601String(),
      'endTime': transfer.endTime?.toIso8601String(),
      'errorMessage': transfer.errorMessage,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update transfer
  Future<void> updateTransfer(Transfer transfer) async {
    final db = await database;

    await db.update(
      'transfers',
      {
        'status': transfer.status.name,
        'bytesTransferred': transfer.bytesTransferred,
        'speed': transfer.speed,
        'endTime': transfer.endTime?.toIso8601String(),
        'errorMessage': transfer.errorMessage,
      },
      where: 'id = ?',
      whereArgs: [transfer.id],
    );
  }

  /// Get transfer by ID
  Future<Transfer?> getTransfer(String id) async {
    final db = await database;

    final maps = await db.query('transfers', where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;
    return _transferFromMap(maps.first);
  }

  /// Get all transfers
  Future<List<Transfer>> getAllTransfers({int? limit, int? offset}) async {
    final db = await database;

    final maps = await db.query(
      'transfers',
      orderBy: 'startTime DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map(_transferFromMap).toList();
  }

  /// Get transfers by status
  Future<List<Transfer>> getTransfersByStatus(TransferStatus status) async {
    final db = await database;

    final maps = await db.query(
      'transfers',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'startTime DESC',
    );

    return maps.map(_transferFromMap).toList();
  }

  /// Get completed transfers
  Future<List<Transfer>> getCompletedTransfers({int? limit}) async {
    final db = await database;

    final maps = await db.query(
      'transfers',
      where: 'status = ?',
      whereArgs: [TransferStatus.completed.name],
      orderBy: 'startTime DESC',
      limit: limit,
    );

    return maps.map(_transferFromMap).toList();
  }

  /// Get failed transfers
  Future<List<Transfer>> getFailedTransfers({int? limit}) async {
    final db = await database;

    final maps = await db.query(
      'transfers',
      where: 'status IN (?, ?)',
      whereArgs: [TransferStatus.failed.name, TransferStatus.cancelled.name],
      orderBy: 'startTime DESC',
      limit: limit,
    );

    return maps.map(_transferFromMap).toList();
  }

  /// Search transfers by filename
  Future<List<Transfer>> searchTransfers(String query) async {
    final db = await database;

    final maps = await db.query(
      'transfers',
      where: 'fileName LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'startTime DESC',
    );

    return maps.map(_transferFromMap).toList();
  }

  /// Get transfers within date range
  Future<List<Transfer>> getTransfersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final maps = await db.query(
      'transfers',
      where: 'startTime BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'startTime DESC',
    );

    return maps.map(_transferFromMap).toList();
  }

  /// Get transfer statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    // Total transfers
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transfers',
    );
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    // Completed transfers
    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transfers WHERE status = ?',
      [TransferStatus.completed.name],
    );
    final completed = Sqflite.firstIntValue(completedResult) ?? 0;

    // Failed transfers
    final failedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transfers WHERE status IN (?, ?)',
      [TransferStatus.failed.name, TransferStatus.cancelled.name],
    );
    final failed = Sqflite.firstIntValue(failedResult) ?? 0;

    // Total bytes transferred (completed only)
    final bytesResult = await db.rawQuery(
      'SELECT SUM(fileSize) as total FROM transfers WHERE status = ?',
      [TransferStatus.completed.name],
    );
    final totalBytes = Sqflite.firstIntValue(bytesResult) ?? 0;

    // Success rate
    final successRate = total > 0 ? (completed / total * 100) : 0.0;

    return {
      'total': total,
      'completed': completed,
      'failed': failed,
      'totalBytes': totalBytes,
      'successRate': successRate,
    };
  }

  /// Delete transfer
  Future<void> deleteTransfer(String id) async {
    final db = await database;
    await db.delete('transfers', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all transfer history
  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('transfers');
  }

  /// Delete old transfers (older than specified days)
  Future<void> deleteOldTransfers(int days) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    await db.delete(
      'transfers',
      where: 'startTime < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Convert database map to Transfer object
  Transfer _transferFromMap(Map<String, dynamic> map) {
    return Transfer(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      fileSize: map['fileSize'] as int,
      filePath: map['filePath'] as String?,
      sender: map['senderData'] != null
          ? _parseDevice(map['senderData'] as String)
          : null,
      receiver: map['receiverData'] != null
          ? _parseDevice(map['receiverData'] as String)
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

  /// Parse device from JSON string
  Device? _parseDevice(String jsonString) {
    try {
      final map = jsonDecode(jsonString);
      if (map is Map<String, dynamic>) {
        return Device.fromJson(map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
