import 'dart:typed_data';

/// CRC32 checksum utility for file chunk integrity verification.
///
/// Uses the standard CRC-32/ISO-HDLC polynomial.
abstract final class Crc32Util {
  static final Uint32List _table = _generateTable();

  static Uint32List _generateTable() {
    final table = Uint32List(256);
    const polynomial = 0xEDB88320;
    for (var i = 0; i < 256; i++) {
      var crc = i;
      for (var j = 0; j < 8; j++) {
        if ((crc & 1) == 1) {
          crc = (crc >> 1) ^ polynomial;
        } else {
          crc = crc >> 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// Computes CRC32 checksum for the given [data].
  static int compute(Uint8List data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      final index = (crc ^ byte) & 0xFF;
      crc = (crc >> 8) ^ _table[index];
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// Validates that [data] matches the [expectedChecksum].
  static bool validate(Uint8List data, int expectedChecksum) {
    return compute(data) == expectedChecksum;
  }

  /// Computes CRC32 incrementally from a stream of byte chunks.
  ///
  /// Returns a function that accepts chunks and produces a running CRC.
  static CrcAccumulator createAccumulator() {
    return CrcAccumulator._();
  }
}

/// Accumulates CRC32 incrementally across multiple byte chunks.
class CrcAccumulator {
  int _crc = 0xFFFFFFFF;

  CrcAccumulator._();

  /// Feeds [chunk] into the running CRC32 computation.
  void add(Uint8List chunk) {
    for (final byte in chunk) {
      final index = (_crc ^ byte) & 0xFF;
      _crc = (_crc >> 8) ^ Crc32Util._table[index];
    }
  }

  /// Returns the final CRC32 value. Call after all chunks have been added.
  int finalize() => _crc ^ 0xFFFFFFFF;

  /// Resets the accumulator for reuse.
  void reset() {
    _crc = 0xFFFFFFFF;
  }
}
