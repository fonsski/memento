import 'dart:async';

import 'package:flutter/material.dart';

import '../../notes/presentation/note_tree_dialogs.dart';
import '../data/sync_coordinator.dart';
import '../domain/discovered_peer.dart';
import '../domain/trusted_peer.dart';

/// Shows the sync panel: paired devices (with a sync action for
/// currently-online ones), nearby unpaired devices (with a pair
/// action), and a way to display this device's own pairing code.
Future<void> showSyncPanel(BuildContext context, SyncCoordinator coordinator) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => SyncPanel(coordinator: coordinator),
  );
}

class SyncPanel extends StatefulWidget {
  const SyncPanel({super.key, required this.coordinator});

  final SyncCoordinator coordinator;

  @override
  State<SyncPanel> createState() => _SyncPanelState();
}

class _SyncPanelState extends State<SyncPanel> {
  List<TrustedPeer> _trustedPeers = [];
  List<DiscoveredPeer> _discoveredPeers = [];
  StreamSubscription<List<DiscoveredPeer>>? _subscription;
  String? _pairingCode;
  String? _syncingDeviceId;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _subscription = widget.coordinator.discovery.peers.listen((
      List<DiscoveredPeer> peers,
    ) {
      if (mounted) setState(() => _discoveredPeers = peers);
    });
    unawaited(_loadTrustedPeers());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _loadTrustedPeers() async {
    final List<TrustedPeer> peers = await widget.coordinator.pairingStore
        .loadTrustedPeers();
    if (mounted) setState(() => _trustedPeers = peers);
  }

  DiscoveredPeer? _discoveredFor(String deviceId) {
    for (final DiscoveredPeer peer in _discoveredPeers) {
      if (peer.deviceId == deviceId) return peer;
    }
    return null;
  }

  void _showMyPairingCode() {
    setState(() => _pairingCode = widget.coordinator.beginPairingAsResponder());
  }

  Future<void> _pairWithDiscovered(DiscoveredPeer peer) async {
    final String? code = await promptForTitle(
      context,
      dialogTitle: 'Код с устройства «${peer.name}»',
    );
    if (code == null || !mounted) return;

    try {
      await widget.coordinator.pairWithPeer(peer, code);
      await _loadTrustedPeers();
      if (mounted) {
        setState(() => _statusMessage = 'Сопряжено с «${peer.name}»');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Не удалось сопрячь: $error');
      }
    }
  }

  Future<void> _syncWithTrusted(TrustedPeer trusted) async {
    final DiscoveredPeer? discovered = _discoveredFor(trusted.deviceId);
    if (discovered == null) return;

    setState(() {
      _syncingDeviceId = trusted.deviceId;
      _statusMessage = null;
    });
    try {
      await widget.coordinator.syncWithPeer(discovered);
      if (mounted) {
        setState(() => _statusMessage = 'Синхронизировано с «${trusted.name}»');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Ошибка синхронизации: $error');
      }
    } finally {
      if (mounted) setState(() => _syncingDeviceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? pairingCode = _pairingCode;
    final List<TrustedPeer> untrustedDiscovered = [
      for (final DiscoveredPeer peer in _discoveredPeers)
        if (!_trustedPeers.any((t) => t.deviceId == peer.deviceId))
          TrustedPeer(deviceId: peer.deviceId, name: peer.name),
    ];

    return AlertDialog(
      title: const Text('Синхронизация'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pairingCode != null)
              _PairingCodeBanner(code: pairingCode)
            else
              OutlinedButton.icon(
                onPressed: _showMyPairingCode,
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('Показать код для сопряжения'),
              ),
            const SizedBox(height: 16),
            Text('Устройства', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_trustedPeers.isEmpty && untrustedDiscovered.isEmpty)
              Text(
                'Пока ничего не найдено рядом',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              for (final TrustedPeer trusted in _trustedPeers)
                _DeviceRow(
                  name: trusted.name,
                  online: _discoveredFor(trusted.deviceId) != null,
                  syncing: _syncingDeviceId == trusted.deviceId,
                  actionLabel: 'Синхронизировать',
                  onAction: _discoveredFor(trusted.deviceId) == null
                      ? null
                      : () => _syncWithTrusted(trusted),
                ),
              for (final TrustedPeer peer in untrustedDiscovered)
                _DeviceRow(
                  name: peer.name,
                  online: true,
                  syncing: false,
                  actionLabel: 'Сопряжить',
                  onAction: () =>
                      _pairWithDiscovered(_discoveredFor(peer.deviceId)!),
                ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(_statusMessage!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _PairingCodeBanner extends StatelessWidget {
  const _PairingCodeBanner({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Введите этот код на другом устройстве',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 4),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.name,
    required this.online,
    required this.syncing,
    required this.actionLabel,
    required this.onAction,
  });

  final String name;
  final bool online;
  final bool syncing;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _StatusDot(online: online, syncing: syncing),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
          if (syncing)
            Text('Синхронизация…', style: theme.textTheme.bodySmall)
          else
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// A calm presence dot: solid while idle, breathing (fading in and out
/// over 2s) while syncing — never a spinning indicator.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.online, required this.syncing});

  final bool online;
  final bool syncing;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  // Created eagerly in initState (not as a lazy `late final` field
  // initializer): if this widget never actually renders the "syncing"
  // branch, a lazy controller would only ever get first-accessed from
  // dispose(), which tries to look up the ticker mode on an
  // already-deactivated element and crashes.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.syncing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncing && !oldWidget.syncing) {
      _controller.repeat(reverse: true);
    } else if (!widget.syncing && oldWidget.syncing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.online
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;

    final Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    if (!widget.syncing) return dot;
    return FadeTransition(
      opacity: _controller.drive(
        CurveTween(
          curve: Curves.easeInOut,
        ).chain(Tween<double>(begin: 0.5, end: 1)),
      ),
      child: dot,
    );
  }
}
