import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/task_repository.dart';
import '../repositories/work_session_repository.dart';
import '../models/work_session.dart';
import '../models/task.dart';

class WorkTimerService extends ChangeNotifier {
  final _repo = WorkSessionRepository();
  final _taskRepo = TaskRepository();
  WorkSession? _activeSession;
  Timer? _ticker;
  bool _isRunning = false;
  Duration _elapsed = Duration.zero;
  Task? _linkedTask;

  bool get isRunning => _isRunning;
  WorkSession? get activeSession => _activeSession;
  Duration get elapsed => _elapsed;
  Task? get linkedTask => _linkedTask;

  String get elapsedFormatted {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> init() async {
    _activeSession = await _repo.getActive();
    if (_activeSession != null) {
      _isRunning = true;
      _elapsed = DateTime.now().difference(_activeSession!.startTime);
      if (_activeSession!.taskId != null) {
        final tasks = await _taskRepo.getAll();
        _linkedTask = tasks.where((t) => t.id == _activeSession!.taskId).firstOrNull;
      }
      _startTicker();
    }
    notifyListeners();
  }

  Future<void> start({String? taskId}) async {
    _activeSession = await _repo.start(taskId: taskId);
    _isRunning = true;
    _elapsed = Duration.zero;
    if (taskId != null) {
      final tasks = await _taskRepo.getAll();
      _linkedTask = tasks.where((t) => t.id == taskId).firstOrNull;
    } else {
      _linkedTask = null;
    }
    _startTicker();
    notifyListeners();
  }

  Future<void> stop() async {
    if (_activeSession == null) return;
    await _repo.stop(_activeSession!);
    _isRunning = false;
    _ticker?.cancel();
    _activeSession = null;
    _linkedTask = null;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeSession != null) {
        _elapsed = DateTime.now().difference(_activeSession!.startTime);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
