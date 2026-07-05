# Memento

Кроссплатформенное приложение для заметок: локальное хранение, Markdown,
граф связей между заметками, P2P-синхронизация между устройствами без
облака. Целевые платформы — Linux, Windows, iOS.

## Требования

- Flutter SDK (канал `stable`; на момент написания — 3.41.6 / Dart 3.11.4).
  Проверить свою версию: `flutter --version`.
- `flutter doctor` должен быть зелёным для нужной вам платформы — см. ниже.

## Сборка и запуск

### Linux

Нужны: `clang`, `cmake`, `ninja-build`, `pkg-config` и dev-заголовки GTK 3
(`libgtk-3-dev` на Debian/Ubuntu, пакет `gtk3` на Arch/Manjaro). Проверить
всё сразу: `flutter doctor -v` — раздел «Linux toolchain» должен быть ✓.

```bash
flutter pub get
flutter build linux --release   # или --debug для отладочной сборки
```

Готовое приложение лежит в `build/linux/x64/release/bundle/` — это
самодостаточная папка (бинарник + нужные `.so`), её можно переносить
целиком.

Быстрый запуск без отдельной сборки: `flutter run -d linux`.

Для реальной работы P2P-синхронизации на Linux должен быть запущен
`avahi-daemon` (mDNS/Bonjour-обнаружение устройств в сети работает через
Avahi). Это требование к рантайму, а не к сборке.

### Windows

Нужны: Visual Studio 2022 (подойдёт Community) с компонентом **Desktop
development with C++** — именно он даёт MSVC-тулчейн и Windows SDK,
которыми Flutter линкует Windows-сборку. Проверить: `flutter doctor -v`,
раздел «Visual Studio».

```powershell
flutter pub get
flutter build windows --release
```

Готовое приложение — `build\windows\x64\runner\Release\memento.exe`
вместе с DLL рядом в той же папке; переносится целиком.

Быстрый запуск: `flutter run -d windows`.

### iOS

Требует macOS с установленным Xcode — со сборкой под iOS никак не
получится с Linux или Windows, это ограничение самого Xcode/Apple
toolchain, а не проекта. На Mac:

```bash
flutter pub get
open ios/Runner.xcworkspace   # первый запуск: CocoaPods установит зависимости
flutter build ios --release   # либо flutter run -d <устройство/симулятор>
```

Для работы P2P-синхронизации на iOS 14+ нужно разрешение на доступ к
локальной сети — оно уже прописано в `ios/Runner/Info.plist`
(`NSBonjourServices` / `NSLocalNetworkUsageDescription`); при первом
использовании синхронизации система покажет системный диалог с запросом
этого разрешения.

## Проверка перед коммитом

```bash
flutter analyze
flutter test
```

## Структура проекта

- `lib/core/` — тема оформления (цвета, типографика, `ThemeData`).
- `lib/features/notes/` — дерево заметок, редактор, поиск, граф связей,
  файловое хранилище (`FileSystemNoteRepository`).
- `lib/features/sync/` — P2P-синхронизация: обнаружение устройств по
  mDNS, сопряжение по коду, протокол синхронизации поверх TCP.
- `test/` — тесты зеркалируют структуру `lib/`.
