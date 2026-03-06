import '../entities/chat_message.dart';

/// Abstract repository contract for P2P chat.
abstract class ChatRepository {
  /// Sends a message to a specific peer.
  Future<ChatMessage> sendMessage({
    required String peerId,
    required String content,
  });

  /// Gets chat history with a specific peer.
  Future<List<ChatMessage>> getMessages(String peerId);

  /// Stream of incoming messages (real-time).
  Stream<ChatMessage> watchMessages();

  /// Clears chat history with a peer.
  Future<void> clearChat(String peerId);
}
