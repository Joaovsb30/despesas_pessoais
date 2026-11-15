import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../state/expense_store.dart';

/// Pede biometria ou o PIN/padrão do celular.
class DeviceAuth {
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

/// Cobre o app inteiro com uma tela de bloqueio quando o bloqueio está ativo.
/// Bloqueia ao abrir e quando o app fica mais de 1 minuto em segundo plano.
class LockGate extends StatefulWidget {
  final ExpenseStore store;
  final DeviceAuth auth;
  final Widget child;

  const LockGate({super.key, required this.store, required this.auth, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const _graceTime = Duration(minutes: 1);

  bool _locked = false;
  bool _checkedInitial = false;
  bool _authenticating = false;
  DateTime? _backgroundSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onStore);
    _onStore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (_checkedInitial || !widget.store.loaded) return;
    _checkedInitial = true;
    if (widget.store.lockEnabled) {
      setState(() => _locked = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.store.lockEnabled || _authenticating) return;
    if (state == AppLifecycleState.paused) {
      _backgroundSince ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundSince;
      _backgroundSince = null;
      if (since != null && DateTime.now().difference(since) > _graceTime) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await widget.auth.authenticate('Desbloqueie para ver suas finanças');
    _authenticating = false;
    _backgroundSince = null;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Despesas bloqueado', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
