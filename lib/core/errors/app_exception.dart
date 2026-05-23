/// Базовое исключение приложения.
class AppException implements Exception {
  final String message;
  final String? detail;
  AppException(this.message, {this.detail});

  @override
  String toString() => 'AppException: $message${detail != null ? ' ($detail)' : ''}';
}

/// Таймер не запущен, но требуется для операции.
class TimerNotRunningException extends AppException {
  TimerNotRunningException()
      : super('Таймер не запущен', detail: 'Сначала запустите рабочий таймер');
}

/// Нельзя удалить стандартную колонку канбана.
class CannotDeleteDefaultColumnException extends AppException {
  CannotDeleteDefaultColumnException()
      : super('Нельзя удалить стандартную колонку');
}

/// Сущность не найдена.
class NotFoundException extends AppException {
  NotFoundException(String entity, String id)
      : super('$entity не найден', detail: 'id: $id');
}
