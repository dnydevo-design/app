/// Data model for individual file chunks tracked in the database.
///
/// Used for pause/resume functionality — each chunk's status is
/// persisted so transfers can resume from the last completed offset.
class ChunkModel {
  final int? id;
  final String transferId;
  final int chunkIndex;
  final int chunkOffset;
  final int chunkSize;
  final int crc32Checksum;
  final String status;

  const ChunkModel({
    this.id,
    required this.transferId,
    required this.chunkIndex,
    required this.chunkOffset,
    required this.chunkSize,
    required this.crc32Checksum,
    this.status = 'pending',
  });

  factory ChunkModel.fromMap(Map<String, dynamic> map) {
    return ChunkModel(
      id: map['id'] as int?,
      transferId: map['transfer_id'] as String,
      chunkIndex: map['chunk_index'] as int,
      chunkOffset: map['chunk_offset'] as int,
      chunkSize: map['chunk_size'] as int,
      crc32Checksum: map['crc32_checksum'] as int,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transfer_id': transferId,
      'chunk_index': chunkIndex,
      'chunk_offset': chunkOffset,
      'chunk_size': chunkSize,
      'crc32_checksum': crc32Checksum,
      'status': status,
    };
  }

  ChunkModel copyWith({
    int? id,
    String? transferId,
    int? chunkIndex,
    int? chunkOffset,
    int? chunkSize,
    int? crc32Checksum,
    String? status,
  }) {
    return ChunkModel(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      chunkOffset: chunkOffset ?? this.chunkOffset,
      chunkSize: chunkSize ?? this.chunkSize,
      crc32Checksum: crc32Checksum ?? this.crc32Checksum,
      status: status ?? this.status,
    );
  }
}
