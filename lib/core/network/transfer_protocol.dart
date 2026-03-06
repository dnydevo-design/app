import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Defines the wire protocol for file transfer between devices.
///
/// Protocol Header Format (binary):
/// - [0-3]   Magic bytes: 0x46535450 ("FSTP" = Fast Share Transfer Protocol)
/// - [4]     Message type (see [MessageType])
/// - [5-8]   Payload length (uint32, big-endian)
/// - [9-40]  Transfer ID (32-byte UUID string, padded)
/// - [41-44] Chunk index (uint32, big-endian)
/// - [45-48] CRC32 checksum (uint32, big-endian)
/// - [49+]   Payload data

abstract final class TransferProtocol {
  /// Magic bytes identifying Fast Share protocol.
  static const int magic = 0x46535450;

  /// Header size in bytes.
  static const int headerSize = 49;

  /// Encodes a protocol message into bytes.
  static Uint8List encodeMessage(ProtocolMessage message) {
    final payloadLength = message.payload.length;
    final totalLength = headerSize + payloadLength;
    final buffer = ByteData(totalLength);

    // Magic bytes
    buffer.setUint32(0, magic, Endian.big);
    // Message type
    buffer.setUint8(4, message.type.index);
    // Payload length
    buffer.setUint32(5, payloadLength, Endian.big);
    // Transfer ID (padded to 32 bytes)
    final idBytes = message.transferId.codeUnits;
    for (var i = 0; i < 32 && i < idBytes.length; i++) {
      buffer.setUint8(9 + i, idBytes[i]);
    }
    // Chunk index
    buffer.setUint32(41, message.chunkIndex, Endian.big);
    // CRC32
    buffer.setUint32(45, message.crc32, Endian.big);

    final result = buffer.buffer.asUint8List();

    // Copy payload
    if (payloadLength > 0) {
      result.setRange(headerSize, totalLength, message.payload);
    }

    return result;
  }

  /// Decodes a protocol message from raw bytes.
  ///
  /// Returns `null` if the magic bytes don't match or data is too short.
  static ProtocolMessage? decodeMessage(Uint8List data) {
    if (data.length < headerSize) return null;

    final buffer = ByteData.sublistView(data);

    // Verify magic bytes
    final magicValue = buffer.getUint32(0, Endian.big);
    if (magicValue != magic) return null;

    final typeIndex = buffer.getUint8(4);
    if (typeIndex >= MessageType.values.length) return null;

    final payloadLength = buffer.getUint32(5, Endian.big);
    if (data.length < headerSize + payloadLength) return null;

    // Extract transfer ID
    final idBytes = data.sublist(9, 41);
    final transferId = String.fromCharCodes(
      idBytes.where((b) => b != 0),
    );

    final chunkIndex = buffer.getUint32(41, Endian.big);
    final crc32 = buffer.getUint32(45, Endian.big);

    final payload = payloadLength > 0
        ? data.sublist(headerSize, headerSize + payloadLength)
        : Uint8List(0);

    return ProtocolMessage(
      type: MessageType.values[typeIndex],
      transferId: transferId,
      chunkIndex: chunkIndex,
      crc32: crc32,
      payload: payload,
    );
  }
}

/// Protocol message types.
enum MessageType {
  /// File metadata announcement (name, size, chunk count).
  fileOffer,

  /// Accept file transfer.
  fileAccept,

  /// Reject file transfer.
  fileReject,

  /// Data chunk.
  chunkData,

  /// Chunk received acknowledgement.
  chunkAck,

  /// Chunk failed (request retransmit).
  chunkNack,

  /// Transfer complete.
  transferComplete,

  /// Transfer cancelled.
  transferCancel,

  /// Pause transfer.
  transferPause,

  /// Resume transfer.
  transferResume,

  /// Heartbeat / keep-alive.
  heartbeat,

  /// Chat message.
  chatMessage,

  /// Stream data (live broadcast).
  streamData,

  /// Discovery announcement.
  discoveryPing,

  /// Discovery response.
  discoveryPong,
}

/// Represents a single protocol message.
class ProtocolMessage extends Equatable {
  final MessageType type;
  final String transferId;
  final int chunkIndex;
  final int crc32;
  final Uint8List payload;

  const ProtocolMessage({
    required this.type,
    required this.transferId,
    this.chunkIndex = 0,
    this.crc32 = 0,
    required this.payload,
  });

  @override
  List<Object?> get props => [type, transferId, chunkIndex, crc32];
}
