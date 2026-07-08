import 'dart:async';

import 'package:flutter/material.dart';

/// Simple inactivity controller:
/// - warn at 25 minutes
/// - logout at 30 minutes
class InactivitySessionController {
  InactivitySessionController({
    required this.onWarn,
    required this.onLogout,
    Duration? warnAfter,
    Duration? logoutAfter,
  }) : warnAfter = warnAfter ?? const Duration(minutes: 25),
       logoutAfter = logoutAfter ?? const Duration(minutes: 30);

  final VoidCallback onWarn;
  final VoidCallback onLogout;
  final Duration warnAfter;
  final Duration logoutAfter;

  Timer? _warnTimer;
  Timer? _logoutTimer;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _schedule();
  }

  void reset() {
    if (!_running) return;
    _schedule();
  }

  void stop() {
    _running = false;
    _warnTimer?.cancel();
    _logoutTimer?.cancel();
    _warnTimer = null;
    _logoutTimer = null;
  }

  void _schedule() {
    _warnTimer?.cancel();
    _logoutTimer?.cancel();

    _warnTimer = Timer(warnAfter, onWarn);
    _logoutTimer = Timer(logoutAfter, onLogout);
  }
}
