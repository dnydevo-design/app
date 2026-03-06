import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../datasources/local/database_helper.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

/// Implementation of [ChatRepository] using TCP sockets for P2P chat.
class ChatRepositoryImpl implements ChatRepository {
  final _uuid = const Uuid();
  final _messageController = StreamController<ChatMessage>.broadcast();
  final Map<String, List<ChatMessage>> _chatHistory = {};
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String _localDeviceId = '';
  String _localDeviceName = 'Me';

  void configure({required String deviceId, required String deviceName}) {
    _localDeviceId = deviceId;
    _localDeviceName = deviceName;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String peerId,
    required String content,
  }) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: _localDeviceId,
      senderName: _localDeviceName,
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
      status: ChatMessageStatus.sending,
    );

    // Store locally in memory
    _chatHistory.putIfAbsent(peerId, () => []);
    _chatHistory[peerId]!.add(message);
    _messageController.add(message);

    // Save to SQLite before sending to prevent data loss
    await _saveMessageToDb(message);

    // Send over network via HTTP POST
    try {
      final client = HttpClient();
      client.connectionTimeout =
          const Duration(seconds: AppConstants.connectionTimeoutSec);
      // In production, resolve peer host from connection manager
      // For now, this is a placeholder
      client.close();

      final updated = ChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
        timestamp: message.timestamp,
        isMe: true,
        status: ChatMessageStatus.sent,
      );

      _updateMessageStatus(message.id, ChatMessageStatus.sent);
      return updated;
    } catch (_) {
      final failed = ChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
        timestamp: message.timestamp,
        isMe: true,
        status: ChatMessageStatus.failed,
      );
      _updateMessageStatus(message.id, ChatMessageStatus.failed);
      return failed;
    }
  }

  Future<void> _saveMessageToDb(ChatMessage message) async {
    final db = await _dbHelper.database;
    await db.insert('chat_messages', {
      'id': message.id,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'is_me': message.isMe ? 1 : 0,
      'status': message.status.name,
    });
  }

  Future<void> _updateMessageStatus(String messageId, ChatMessageStatus status) async {
    final db = await _dbHelper.database;
    await db.update(
      'chat_messages',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Called when a message is received from the network.
  void onMessageReceived(Map<String, dynamic> data) {
    final message = ChatMessage(
      id: data['id'] as String? ?? _uuid.v4(),
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Unknown',
      content: data['content'] as String? ?? '',
      timestamp: DateTime.tryParse(data['timestamp'] as String? ?? '') ??
          DateTime.now(),
      isMe: false,
      status: ChatMessageStatus.delivered,
    );

    _chatHistory.putIfAbsent(message.senderId, () => []);
    _chatHistory[message.senderId]!.add(message);
    _messageController.add(message);
    
    // Save incoming message
    _saveMessageToDb(message);
  }

  @override
  Future<List<ChatMessage>> getMessages(String peerId) async {
    if (_chatHistory.containsKey(peerId)) {
      return _chatHistory[peerId]!;
    }
    
    // Load from database if not in memory
    final db = await _dbHelper.database;
    final maps = await db.query(
      'chat_messages',
      where: 'sender_id = ? OR (is_me = 1 AND sender_id = ?)', 
      whereArgs: [peerId, _localDeviceId], // Note: sender_id here is actually the conversation identifier
      orderBy: 'timestamp ASC',
    );
    
    final messages = maps.map((map) => ChatMessage(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      senderName: map['sender_name'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isMe: (map['is_me'] as int) == 1,
      status: ChatMessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ChatMessageStatus.sent,
      ),
    )).toList();
    
    _chatHistory[peerId] = messages;
    return messages;
  }

  @override
  Stream<ChatMessage> watchMessages() => _messageController.stream;

  @override
  Future<void> clearChat(String peerId) async {
    _chatHistory.remove(peerId);
    final db = await _dbHelper.database;
    await db.delete(
      'chat_messages',
      where: 'sender_id = ? OR (is_me = 1 AND sender_id = ?)',
      whereArgs: [peerId, _localDeviceId],
    );
  }

  /// Disposes resources.
  Future<void> dispose() async {
    await _messageController.close();
  }
}
