import 'dart:async';
import 'package:flutter/material.dart';
import '../models/work_session.dart';
import '../models/task.dart';
import '../data/repositories/interfaces/work_session_repository.dart';
import '../data/repositories/interfaces/task_repository.dart';

/// ChangeNotifier-сервис управления таймером работы.
/// Содержит логику старта/остановки и оповещает UI об изменениях.
class WorkTimerService extends ChangeNotifier {
  final WorkSessionRepository _repo;
  final TaskRepository _taskRepo;

  WorkSession? _activeSession;
  Timer? _ticker;
  bool _isRunning = false;
  Duration _elapsed = Duration.zero;
  Task? _linkedTask;

  WorkTimerService(this._repo, this._taskRepo);

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

  /// Восстанавливает активную сессию (если приложение было перезапущено).
  Future<void> init() async {
    _activeSession = await _repo.getActive();
    if (_activeSession != null) {
      _isRunning = true;
      _elapsed = DateTime.now().difference(_activeSession!.startTime);
      if (_activeSession!.taskId != null) {
        _linkedTask = await _taskRepo.getById(_activeSession!.taskId!);
      }
      _startTicker();
    }
    notifyListeners();
  }

  /// Запускает таймер, опционально привязывая к задаче.
  Future<void> start({String? taskId}) async {
    _activeSession = await _repo.start(taskId: taskId);
    _isRunning = true;
    _elapsed = Duration.zero;
    _linkedTask = taskId != null ? await _taskRepo.getById(taskId) : null;
    _startTicker();
    notifyListeners();
  }

  /// Останавливает таймер и сохраняет сессию.
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
