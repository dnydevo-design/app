import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Service handling raw UDP audio streaming for ultra low latency P2P voice calls.
class VoiceCallService {
  RawDatagramSocket? _socket;
  Timer? _keepAliveTimer;
  
  // Call State
  bool _isInCall = false;
  String? _peerIp;
  int? _peerPort;
  
  // Audio Playback Placeholder (Using audioplayers in production for ringtones)
  // Jitter Buffer for out-of-order UDP packets
  final Map<int, Uint8List> _jitterBuffer = {};
  int _expectedSequenceNumber = 0;
  final int _bufferSize = 5; // 5 packets buffer ~100ms
  
  int _sequenceCounter = 0;

  // Stream for incoming audio data
  final _audioStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  // Stream for call state events
  final _callStateController = StreamController<CallState>.broadcast();
  Stream<CallState> get callStateStream => _callStateController.stream;

  bool get isInCall => _isInCall;

  /// Start listening for incoming call requests or audio packets
  Future<void> startListening(int port) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      debugPrint('VoiceCallService listening on UDP port $port');

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleIncomingDatagram(datagram);
          }
        }
      });
    } catch (e) {
      debugPrint('Error binding UDP socket: $e');
    }
  }

  void _handleIncomingDatagram(Datagram datagram) {
    final data = datagram.data;
    if (data.isEmpty) return;

    // Header structure:
    // [0]: Packet Type (0 = Audio, 1 = Call Request, 2 = Call Accept, 3 = Call Decline, 4 = End)
    final packetType = data[0];

    switch (packetType) {
      case 0:
        if (_isInCall) _handleAudioPacket(data.sublist(1));
        break;
      case 1:
        // Incoming Call Request
        _callStateController.add(CallState.ringing(datagram.address.address));
        break;
      case 2:
        // Call Accepted
        _isInCall = true;
        _peerIp = datagram.address.address;
        _callStateController.add(CallState.active());
        break;
      case 3:
        // Call Declined
        _callStateController.add(CallState.declined());
        break;
      case 4:
        // Call Ended
        endCall();
        break;
    }
  }

  void _handleAudioPacket(Uint8List packet) {
    if (packet.length < 4) return;
    
    // Extract sequence number (4 bytes)
    final byteData = ByteData.sublistView(packet, 0, 4);
    final sequenceNum = byteData.getUint32(0);
    final audioData = packet.sublist(4);

    // Jitter Buffer Logic
    if (sequenceNum >= _expectedSequenceNumber) {
      _jitterBuffer[sequenceNum] = audioData;
      
      // If buffer is full enough or we have the exact expected packet, flush it
      if (_jitterBuffer.containsKey(_expectedSequenceNumber)) {
        _audioStreamController.add(_jitterBuffer.remove(_expectedSequenceNumber)!);
        _expectedSequenceNumber++;
      } else if (_jitterBuffer.length > _bufferSize) {
        // Force flush oldest
        final sortedKeys = _jitterBuffer.keys.toList()..sort();
        final oldestSeq = sortedKeys.first;
        _audioStreamController.add(_jitterBuffer.remove(oldestSeq)!);
        _expectedSequenceNumber = oldestSeq + 1;
      }
    }
  }

  /// Initiate a call to a peer
  Future<void> initiateCall(String targetIp, int targetPort) async {
    _peerIp = targetIp;
    _peerPort = targetPort;
    
    final address = InternetAddress(targetIp);
    // Send Call Request packet (Type 1)
    _socket?.send([1], address, targetPort);
    _callStateController.add(CallState.calling());
  }

  /// Accept an incoming call
  void acceptCall(String callerIp, int port) {
    _isInCall = true;
    _peerIp = callerIp;
    _peerPort = port;
    _expectedSequenceNumber = 0;
    _jitterBuffer.clear();
    
    final address = InternetAddress(callerIp);
    _socket?.send([2], address, port); // Type 2: Accept
    
    _callStateController.add(CallState.active());
    _startDummyAudioCapture();
  }

  /// Decline an incoming call
  void declineCall(String callerIp, int port) {
    final address = InternetAddress(callerIp);
    _socket?.send([3], address, port); // Type 3: Decline
    _callStateController.add(CallState.idle());
  }

  /// End an active call
  void endCall() {
    if (_isInCall && _peerIp != null && _peerPort != null) {
      final address = InternetAddress(_peerIp!);
      _socket?.send([4], address, _peerPort!); // Type 4: End
    }
    
    _isInCall = false;
    _peerIp = null;
    _peerPort = null;
    _expectedSequenceNumber = 0;
    _jitterBuffer.clear();
    _keepAliveTimer?.cancel();
    
    _callStateController.add(CallState.ended());
  }

  /// Dummy method to represent sending raw microphone data via UDP
  void _startDummyAudioCapture() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_isInCall || _peerIp == null || _peerPort == null) {
        timer.cancel();
        return;
      }
      
      // Construct Packet: [Type (0)] + [Sequence (4 bytes)] + [Audio Data]
      final builder = BytesBuilder();
      builder.addByte(0); // Audio Type
      
      final seqBytes = ByteData(4)..setUint32(0, _sequenceCounter);
      builder.add(seqBytes.buffer.asUint8List());
      
      // Dummy 160 bytes of audio (e.g. 20ms of 8kHz 8-bit PCM)
      builder.add(Uint8List(160)..fillRange(0, 160, 128));
      
      _socket?.send(builder.toBytes(), InternetAddress(_peerIp!), _peerPort!);
      _sequenceCounter++;
    });
  }

  void dispose() {
    _keepAliveTimer?.cancel();
    _socket?.close();
    _audioStreamController.close();
    _callStateController.close();
  }
}

/// Helper class to represent the state of a call
class CallState {
  final _CallStateEnum state;
  final String? peerIp;

  CallState._(this.state, {this.peerIp});

  factory CallState.idle() => CallState._(_CallStateEnum.idle);
  factory CallState.calling() => CallState._(_CallStateEnum.calling);
  factory CallState.ringing(String ip) => CallState._(_CallStateEnum.ringing, peerIp: ip);
  factory CallState.active() => CallState._(_CallStateEnum.active);
  factory CallState.declined() => CallState._(_CallStateEnum.declined);
  factory CallState.ended() => CallState._(_CallStateEnum.ended);

  bool get isRinging => state == _CallStateEnum.ringing;
  bool get isActive => state == _CallStateEnum.active;
}

enum _CallStateEnum { idle, calling, ringing, active, declined, ended }
