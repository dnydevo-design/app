import 'package:equatable/equatable.dart';

/// Represents a P2P chat message between devices.
class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final ChatMessageStatus status;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isMe = false,
    this.status = ChatMessageStatus.sent,
  });

  @override
  List<Object?> get props => [id, senderId, timestamp];
}

/// Delivery status for chat messages.
enum ChatMessageStatus {
  sending,
  sent,
  delivered,
  failed,
}
