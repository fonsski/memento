import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/sync_manifest.dart';

/// A message in the sync wire protocol. Every subtype round-trips
/// through [toJson]/the matching `fromJson` and is dispatched by
/// [decodeSyncMessage] via its `type` tag.
sealed class SyncMessage {
  Map<String, dynamic> toJson();
}

/// Sent by both sides right after connecting, to identify themselves.
class HelloMessage extends SyncMessage {
  HelloMessage({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;

  static HelloMessage fromJson(Map<String, dynamic> json) => HelloMessage(
    deviceId: json['deviceId'] as String,
    deviceName: json['deviceName'] as String,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'hello',
    'deviceId': deviceId,
    'deviceName': deviceName,
  };
}

/// Sent by the connecting device to prove it knows the pairing code
/// shown on the other device.
class PairRequestMessage extends SyncMessage {
  PairRequestMessage({required this.code});

  final String code;

  static PairRequestMessage fromJson(Map<String, dynamic> json) =>
      PairRequestMessage(code: json['code'] as String);

  @override
  Map<String, dynamic> toJson() => {'type': 'pairRequest', 'code': code};
}

/// Reply to a [PairRequestMessage].
class PairResultMessage extends SyncMessage {
  PairResultMessage({required this.accepted});

  final bool accepted;

  static PairResultMessage fromJson(Map<String, dynamic> json) =>
      PairResultMessage(accepted: json['accepted'] as bool);

  @override
  Map<String, dynamic> toJson() => {'type': 'pairResult', 'accepted': accepted};
}

/// Asks the peer to send its [ManifestMessage].
class ManifestRequestMessage extends SyncMessage {
  static ManifestRequestMessage fromJson(Map<String, dynamic> json) =>
      ManifestRequestMessage();

  @override
  Map<String, dynamic> toJson() => {'type': 'manifestRequest'};
}

/// A vault's [SyncManifest], sent in reply to a [ManifestRequestMessage].
class ManifestMessage extends SyncMessage {
  ManifestMessage({required this.manifest});

  final SyncManifest manifest;

  static ManifestMessage fromJson(Map<String, dynamic> json) =>
      ManifestMessage(manifest: SyncManifest.fromJson(json));

  @override
  Map<String, dynamic> toJson() => {'type': 'manifest', ...manifest.toJson()};
}

/// Requests the peer's content for [path] (used to pull it).
class FileRequestMessage extends SyncMessage {
  FileRequestMessage({required this.path});

  final String path;

  static FileRequestMessage fromJson(Map<String, dynamic> json) =>
      FileRequestMessage(path: json['path'] as String);

  @override
  Map<String, dynamic> toJson() => {'type': 'fileRequest', 'path': path};
}

/// A note's full content for [path] — sent unprompted to push, or in
/// reply to a [FileRequestMessage] to fulfil a pull.
class FileContentMessage extends SyncMessage {
  FileContentMessage({required this.path, required this.content});

  final String path;
  final String content;

  static FileContentMessage fromJson(Map<String, dynamic> json) =>
      FileContentMessage(
        path: json['path'] as String,
        content: json['content'] as String,
      );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'fileContent',
    'path': path,
    'content': content,
  };
}

/// Signals that the sender has no more actions to perform this session.
class SyncDoneMessage extends SyncMessage {
  static SyncDoneMessage fromJson(Map<String, dynamic> json) =>
      SyncDoneMessage();

  @override
  Map<String, dynamic> toJson() => {'type': 'done'};
}

SyncMessage decodeSyncMessage(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'hello':
      return HelloMessage.fromJson(json);
    case 'pairRequest':
      return PairRequestMessage.fromJson(json);
    case 'pairResult':
      return PairResultMessage.fromJson(json);
    case 'manifestRequest':
      return ManifestRequestMessage.fromJson(json);
    case 'manifest':
      return ManifestMessage.fromJson(json);
    case 'fileRequest':
      return FileRequestMessage.fromJson(json);
    case 'fileContent':
      return FileContentMessage.fromJson(json);
    case 'done':
      return SyncDoneMessage.fromJson(json);
    default:
      throw FormatException('Unknown sync message type: ${json['type']}');
  }
}

/// Frames [SyncMessage]s as `<4-byte big-endian length><UTF-8 JSON>` over
/// a [Socket], so messages can be told apart on a byte stream.
class MessageChannel {
  MessageChannel(this._socket);

  final Socket _socket;
  final List<int> _buffer = [];

  Future<void> send(SyncMessage message) async {
    final List<int> body = utf8.encode(jsonEncode(message.toJson()));
    final ByteData header = ByteData(4)..setUint32(0, body.length, Endian.big);
    _socket.add(header.buffer.asUint8List());
    _socket.add(body);
    await _socket.flush();
  }

  /// Decoded messages, in the order their frames complete. Ends when the
  /// underlying socket closes.
  Stream<SyncMessage> messages() async* {
    await for (final List<int> chunk in _socket) {
      _buffer.addAll(chunk);
      while (true) {
        final SyncMessage? message = _tryDecodeNext();
        if (message == null) break;
        yield message;
      }
    }
  }

  SyncMessage? _tryDecodeNext() {
    if (_buffer.length < 4) return null;
    final int length = ByteData.sublistView(
      Uint8List.fromList(_buffer.sublist(0, 4)),
    ).getUint32(0, Endian.big);
    if (_buffer.length < 4 + length) return null;

    final List<int> body = _buffer.sublist(4, 4 + length);
    _buffer.removeRange(0, 4 + length);
    return decodeSyncMessage(
      jsonDecode(utf8.decode(body)) as Map<String, dynamic>,
    );
  }

  Future<void> close() => _socket.close();
}
