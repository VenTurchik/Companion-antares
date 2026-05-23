# Companion

> **Alpha** — версия 0.1.0-alpha. API и схема БД могут меняться.

Личное рабочее пространство разработчика — десктопное приложение на Flutter. Управление задачами, заметками, сниппетами и трекинг рабочего времени. Windows, Linux, macOS.

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

## Архитектура

Чистая архитектура (clean architecture), 4 слоя:

```
lib/
├── main.dart                        # Точка входа, DI-контейнер
├── app.dart                         # Корневой виджет, навигация, темы
│
├── core/                            # Инфраструктура
│   ├── constants.dart               # Константы, ключи статусов
│   ├── errors/
│   │   └── app_exception.dart       # Исключения предметной области
│   └── database/
│       ├── database_helper.dart     # Координатор БД (singleton)
│       ├── migrations.dart          # Миграции v1 → v4
│       └── tables/                  # Табличные классы (SRP)
│           ├── tasks_table.dart
│           ├── notes_table.dart
│           ├── snippets_table.dart
│           ├── activities_table.dart
│           ├── work_sessions_table.dart
│           └── task_columns_table.dart
│
├── data/                            # Слой данных
│   └── repositories/
│       ├── interfaces/              # Абстракции (DIP)
│       │   ├── task_repository.dart
│       │   ├── note_repository.dart
│       │   ├── snippet_repository.dart
│       │   ├── work_session_repository.dart
│       │   ├── activity_repository.dart
│       │   └── task_column_repository.dart
│       └── impl/                    # Реализации SQLite
│           ├── task_repository_impl.dart
│           ├── note_repository_impl.dart
│           ├── snippet_repository_impl.dart
│           ├── work_session_repository_impl.dart
│           ├── activity_repository_impl.dart
│           └── task_column_repository_impl.dart
│
├── domain/                          # Бизнес-логика
│   ├── models/                      # Модели данных
│   │   ├── task.dart
│   │   ├── task_column.dart
│   │   ├── note.dart
│   │   ├── snippet.dart
│   │   ├── work_session.dart
│   │   └── activity.dart
│   └── services/
│       ├── task_service.dart        # Сервис управления задачами
│       └── metrics_service.dart     # Сервис расчёта метрик
│
├── services/                        # ChangeNotifier-сервисы
│   ├── settings_service.dart        # Настройки (SharedPreferences)
│   ├── work_timer_service.dart      # Таймер рабочего времени
│   ├── app_store.dart               # Хранилище + кеш метрик (JSON)
│   └── tray_service.dart            # Системный трей
│
├── screens/                         # Экраны
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── kanban/
│   │   ├── kanban_screen.dart
│   │   ├── dialogs/
│   │   │   ├── task_dialog.dart
│   │   │   └── column_dialog.dart
│   │   └── widgets/
│   │       ├── kanban_board.dart
│   │       ├── kanban_table_tab.dart
│   │       └── archive_tab.dart
│   ├── tasks/
│   │   └── task_detail_screen.dart
│   ├── notes/
│   │   ├── note_list_screen.dart
│   │   └── note_editor_screen.dart
│   ├── snippets/
│   │   ├── snippet_list_screen.dart
│   │   └── snippet_editor_screen.dart
│   ├── metrics/
│   │   └── metrics_screen.dart
│   └── settings/
│       └── settings_screen.dart
│
└── widgets/                         # Переиспользуемые виджеты
    ├── task_card.dart
    ├── kanban_column.dart
    └── metric_chart.dart
```

Управление состоянием — Provider (ChangeNotifier + Provider). DI — ручное, через конструктор в `main.dart`.

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

## Документация

[`docs.pdf`](docs.pdf) — полное описание архитектуры, модели данных, БД, слоёв приложения и DI (A4, 12 с., русский).

## Лицензия

MIT
