import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// SQLite database helper for Fast Share.
///
/// Manages database creation, migrations, and provides
/// factory access to the singleton database instance.
class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper instance = DatabaseHelper._internal();

  DatabaseHelper._internal();

  /// Gets the database instance, creating it if needed.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates all tables on first launch.
  Future<void> _onCreate(Database db, int version) async {
    // Transfer tasks
    await db.execute('''
      CREATE TABLE transfer_tasks (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        total_chunks INTEGER NOT NULL,
        completed_chunks INTEGER NOT NULL DEFAULT 0,
        direction TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        peer_id TEXT NOT NULL,
        peer_name TEXT NOT NULL,
        speed_bytes_per_sec REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        error_message TEXT
      )
    ''');

    // Chunk tracking for pause/resume
    await db.execute('''
      CREATE TABLE transfer_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        chunk_offset INTEGER NOT NULL,
        chunk_size INTEGER NOT NULL,
        crc32_checksum INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (transfer_id) REFERENCES transfer_tasks(id)
          ON DELETE CASCADE,
        UNIQUE(transfer_id, chunk_index)
      )
    ''');

    // Vault items
    await db.execute('''
      CREATE TABLE vault_items (
        id TEXT PRIMARY KEY,
        original_name TEXT NOT NULL,
        encrypted_path TEXT NOT NULL,
        original_path TEXT NOT NULL,
        original_size INTEGER NOT NULL,
        mime_type TEXT NOT NULL,
        encrypted_at TEXT NOT NULL,
        is_locked INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Chat messages
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_me INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'sent'
      )
    ''');

    // Device discovery cache
    await db.execute('''
      CREATE TABLE discovered_devices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        platform TEXT,
        avatar TEXT,
        is_group_owner INTEGER NOT NULL DEFAULT 0,
        discovered_at TEXT NOT NULL
      )
    ''');

    // Indexes for efficient queries
    await db.execute(
      'CREATE INDEX idx_transfer_status ON transfer_tasks(status)',
    );
    await db.execute(
      'CREATE INDEX idx_chunks_transfer_id ON transfer_chunks(transfer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_chat_sender ON chat_messages(sender_id)',
    );
  }

  /// Handles database migrations.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migration logic here
  }

  /// Closes the database.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
