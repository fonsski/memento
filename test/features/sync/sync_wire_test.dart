import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/sync/data/sync_wire.dart';
import 'package:memento/features/sync/domain/sync_manifest.dart';

void main() {
  group('message JSON round-trip', () {
    test('HelloMessage', () {
      final HelloMessage original = HelloMessage(
        deviceId: 'device-1',
        deviceName: 'Ноутбук',
      );
      final HelloMessage decoded =
          decodeSyncMessage(original.toJson()) as HelloMessage;

      expect(decoded.deviceId, 'device-1');
      expect(decoded.deviceName, 'Ноутбук');
    });

    test('PairRequestMessage', () {
      final PairRequestMessage decoded =
          decodeSyncMessage(PairRequestMessage(code: '123456').toJson())
              as PairRequestMessage;
      expect(decoded.code, '123456');
    });

    test('PairResultMessage', () {
      final PairResultMessage decoded =
          decodeSyncMessage(PairResultMessage(accepted: true).toJson())
              as PairResultMessage;
      expect(decoded.accepted, isTrue);
    });

    test('ManifestRequestMessage', () {
      expect(
        decodeSyncMessage(ManifestRequestMessage().toJson()),
        isA<ManifestRequestMessage>(),
      );
    });

    test('ManifestMessage', () {
      final SyncManifest manifest = SyncManifest({
        'a': ManifestEntry(
          path: 'a',
          modifiedAt: DateTime(2026, 1, 1),
          contentHash: 'hash-a',
        ),
      });
      final ManifestMessage decoded =
          decodeSyncMessage(ManifestMessage(manifest: manifest).toJson())
              as ManifestMessage;

      expect(decoded.manifest.entries['a']!.contentHash, 'hash-a');
      expect(decoded.manifest.entries['a']!.modifiedAt, DateTime(2026, 1, 1));
    });

    test('FileRequestMessage', () {
      final FileRequestMessage decoded =
          decodeSyncMessage(FileRequestMessage(path: 'note').toJson())
              as FileRequestMessage;
      expect(decoded.path, 'note');
    });

    test('FileContentMessage', () {
      final FileContentMessage decoded =
          decodeSyncMessage(
                FileContentMessage(path: 'note', content: '# Заметка').toJson(),
              )
              as FileContentMessage;
      expect(decoded.path, 'note');
      expect(decoded.content, '# Заметка');
    });

    test('SyncDoneMessage', () {
      expect(
        decodeSyncMessage(SyncDoneMessage().toJson()),
        isA<SyncDoneMessage>(),
      );
    });

    test('rejects an unknown message type', () {
      expect(
        () => decodeSyncMessage({'type': 'nonsense'}),
        throwsFormatException,
      );
    });
  });

  group('MessageChannel over a real TCP loopback connection', () {
    late ServerSocket serverSocket;

    tearDown(() async {
      await serverSocket.close();
    });

    test('delivers a single message', () async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final Future<Socket> acceptFuture = serverSocket.first;

      final Socket clientSocket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        serverSocket.port,
      );
      final Socket serverSideSocket = await acceptFuture;

      final MessageChannel client = MessageChannel(clientSocket);
      final MessageChannel server = MessageChannel(serverSideSocket);

      await client.send(HelloMessage(deviceId: 'x', deviceName: 'Телефон'));
      final HelloMessage received =
          await server.messages().first as HelloMessage;

      expect(received.deviceName, 'Телефон');

      await client.close();
      await server.close();
    });

    test('delivers several messages sent back-to-back, in order', () async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final Future<Socket> acceptFuture = serverSocket.first;

      final Socket clientSocket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        serverSocket.port,
      );
      final Socket serverSideSocket = await acceptFuture;

      final MessageChannel client = MessageChannel(clientSocket);
      final MessageChannel server = MessageChannel(serverSideSocket);

      final Stream<SyncMessage> received = server.messages();
      await client.send(FileRequestMessage(path: 'one'));
      await client.send(FileRequestMessage(path: 'two'));
      await client.send(FileRequestMessage(path: 'three'));

      final List<SyncMessage> messages = await received.take(3).toList();

      expect(messages.map((m) => (m as FileRequestMessage).path).toList(), [
        'one',
        'two',
        'three',
      ]);

      await client.close();
      await server.close();
    });

    test('delivers a large message intact', () async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final Future<Socket> acceptFuture = serverSocket.first;

      final Socket clientSocket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        serverSocket.port,
      );
      final Socket serverSideSocket = await acceptFuture;

      final MessageChannel client = MessageChannel(clientSocket);
      final MessageChannel server = MessageChannel(serverSideSocket);

      final String bigContent = 'x' * 200000;
      await client.send(FileContentMessage(path: 'big', content: bigContent));
      final FileContentMessage received =
          await server.messages().first as FileContentMessage;

      expect(received.content, bigContent);

      await client.close();
      await server.close();
    });
  });
}
