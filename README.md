# Companion

> Личное рабочее пространство разработчика — десктопное приложение на Flutter.

Персональный инструмент для управления задачами, заметками, сниппетами и трекингом рабочего времени. Работает на Windows, Linux и macOS.

## Возможности

**Управление задачами**
- Канбан-доска с кастомными колонками (добавление/удаление)
- Drag-and-drop между колонками
- Нумерация задач в формате TASK-XXXX
- Подробный просмотр с привязкой заметок и сниппетов
- Архив завершённых задач

**Заметки**
- Markdown-редактор с предпросмотром
- Привязка к задачам

**Сниппеты**
- Подсветка синтаксиса (20+ языков)
- Поиск и фильтрация по тегам
- Привязка к заметкам

**Трекер времени**
- Запуск/остановка таймера с привязкой к задаче
- Индикация в боковой панели
- Ручное добавление времени
- Блокировка колонки In Progress при остановленном таймере

**Дашборд и метрики**
- Статистика за сегодня и неделю
- График активности (BarChart с тултипами)
- Сводка по задачам, заметкам, сниппетам

**Система**
- Системный трей (сворачивание в трей, управление таймером)
- Тёмная/светлая тема
- Автоопределение IDE (VS Code, Zed, IntelliJ и др.)
- Запуск IDE из приложения

## Технологии

| Компонент | Технология |
|-----------|-----------|
| Фреймворк | Flutter 3.x (Dart 3.x) |
| База данных | SQLite (sqflite + sqflite_common_ffi) |
| Состояние | Provider + ChangeNotifier |
| Чарты | fl_chart |
| Парсинг Markdown | flutter_markdown |
| Подсветка кода | flutter_highlight |
| Кеш пользователя | JSON-файл (SharedPreferences для настроек) |
| Системный трей | system_tray |
| Управление окном | window_manager |

## Установка

### Требования
- Flutter SDK 3.11+
- Инструменты платформы:
  - **Linux**: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`
  - **Windows**: Visual Studio с C++ workload
  - **macOS**: Xcode Command Line Tools

### Сборка

```bash
git clone <repo-url>
cd companion
flutter config --enable-linux-desktop   # или --enable-windows/macos-desktop
flutter pub get
flutter build linux --release           # linux/windows/macos
```

Бинарник:
- **Linux**: `build/linux/x64/release/bundle/`
- **Windows**: `build/windows/x64/runner/Release/`
- **macOS**: `build/macos/Build/Products/Release/Runner.app`

### CI/CD

При пуше в `main` GitHub Actions собирает release-версии для всех трёх платформ автоматически. Артефакты доступны 7 дней.

## Структура проекта

```
lib/
├── app.dart                   # Главный виджет, темы, навигация
├── main.dart                  # Точка входа, инициализация провайдеров
├── database/
│   └── database_helper.dart   # SQLite, миграции v1→v4
├── models/                    # Модели данных
│   ├── task.dart
│   ├── task_column.dart
│   ├── note.dart
│   ├── snippet.dart
│   ├── work_session.dart
│   └── activity.dart
├── repositories/              # Слой доступа к данным
│   ├── task_repository.dart
│   ├── note_repository.dart
│   ├── snippet_repository.dart
│   ├── work_session_repository.dart
│   └── activity_repository.dart
├── services/                  # Бизнес-логика
│   ├── settings_service.dart
│   ├── work_timer_service.dart
│   ├── app_store.dart
│   └── tray_service.dart
├── screens/                   # Экраны
│   ├── dashboard_screen.dart
│   ├── kanban_screen.dart
│   ├── task_detail_screen.dart
│   ├── note_list_screen.dart
│   ├── note_editor_screen.dart
│   ├── snippet_list_screen.dart
│   ├── snippet_editor_screen.dart
│   ├── metrics_screen.dart
│   └── settings_screen.dart
└── widgets/                   # Переиспользуемые виджеты
    ├── task_card.dart
    ├── kanban_column.dart
    └── metric_chart.dart
```

## Скриншоты

*(добавьте скриншоты по мере готовности)*

## Лицензия

MIT
