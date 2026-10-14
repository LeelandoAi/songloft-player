import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final screenAwakeRouteObserver = RouteObserver<ModalRoute<void>>();

/// Lyrics and video share one lock; releasing either must not release the other.
class ScreenAwakeController {
  ScreenAwakeController(this.toggle);

  final Future<void> Function(bool enabled) toggle;
  final Set<Object> _owners = {};
  Future<void> _writes = Future<void>.value();

  Future<void> update(Object owner, bool enabled) {
    if (enabled) {
      _owners.add(owner);
    } else {
      _owners.remove(owner);
    }
    _writes = _writes.then((_) async {
      try {
        // Read the latest desired state after any previous native call completes.
        await toggle(_owners.isNotEmpty);
      } catch (error) {
        debugPrint('[ScreenAwake] $error');
      }
    });
    return _writes;
  }
}

final screenAwakeControllerProvider = Provider<ScreenAwakeController>(
  (ref) =>
      ScreenAwakeController((enabled) => WakelockPlus.toggle(enable: enabled)),
);

/// Keep the screen awake only while this route and the app are visible.
class ScreenAwakeScope extends ConsumerStatefulWidget {
  const ScreenAwakeScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  ConsumerState<ScreenAwakeScope> createState() => _ScreenAwakeScopeState();
}

class _ScreenAwakeScopeState extends ConsumerState<ScreenAwakeScope>
    with WidgetsBindingObserver, RouteAware {
  final Object _owner = Object();
  late final ScreenAwakeController _controller;
  ModalRoute<void>? _route;
  bool? _applied;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(screenAwakeControllerProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      screenAwakeRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) screenAwakeRouteObserver.subscribe(this, route);
    }
    _sync();
  }

  @override
  void didUpdateWidget(covariant ScreenAwakeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final enabled =
        widget.enabled &&
        (_route?.isCurrent ?? true) &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (_applied == enabled) return;
    _applied = enabled;
    unawaited(_controller.update(_owner, enabled));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();
  @override
  void didPush() => _sync();
  @override
  void didPopNext() => _sync();
  @override
  void didPushNext() => _sync();
  @override
  void didPop() {
    _applied = false;
    unawaited(_controller.update(_owner, false));
  }

  @override
  void dispose() {
    screenAwakeRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.update(_owner, false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
