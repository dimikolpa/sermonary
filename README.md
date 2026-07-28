# Sermonary

Sermonary ist ein ruhiger, lokal speichernder Predigt-Writer mit Archiv. Der
Prototyp verbindet Gliederung, ausgeschriebenes Manuskript und eine
schreibgeschützte Vortragansicht in einem gemeinsamen, versionierten Dokument.

## Aktueller Funktionsumfang

- lokale Drift-/SQLite-Bibliothek mit Entwicklungs-Beispieldaten
- neue Predigten, Duplikate, Suche, Sortierung und Statusansichten
- Papierkorb mit Wiederherstellen und endgültigem Löschen
- Metadaten-Inspector
- Rawmode mit stabilen Stichpunkt-IDs, Ein-/Ausrücken und Verschieben
- Scriptmode mit Überschriften, Absätzen, Zitaten, Notizen und Bibelblöcken
- Autosave nach 700 ms, Sofortspeichern und Dokument-Snapshots
- automatische Outline mit Wortzahl und Zeitschätzung
- heller/dunkler Livemode, Timer, Textgröße, Textbreite und Tastaturscrollen
- Markdown- und Klartext-Export über native Dateiauswahl

> Screenshot-Platzhalter: Ein aktueller Produkt-Screenshot wird nach dem ersten
> visuellen Abnahmelauf ergänzt.

## Voraussetzungen

- Flutter 3.44.6 stable oder kompatibel
- Dart 3.12.2 oder kompatibel
- Xcode 26.6 oder kompatibel
- CocoaPods für macOS-Plugins

Die geprüfte Entwicklungsumgebung ist macOS 26.5.2 auf Apple Silicon.

## Installation und Start

```bash
flutter pub get
dart run build_runner build
flutter run -d macos
```

Drift-Code nach Schemaänderungen neu erzeugen:

```bash
dart run build_runner build
```

Qualitätsprüfungen:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d macos
flutter build macos --debug
```

## Projektstruktur

```text
lib/
  app/                    App, Theme, Router, Provider
  core/                   Datenbank, Fehler, Plattform- und Sync-Grenzen
  features/
    bible/                strukturierte Referenzen und Provider
    export/               Markdown-/Text-Export
    library/              Sermon-Domain, Repository und Bibliothek
    live_mode/            schreibgeschützte Vortragansicht
    sermon_editor/        Dokumentmodell, Raw-/Scripteditor, Outline
test/                     Unit-, Datenbank- und Widget-Tests
integration_test/         macOS-Happy-Path
docs/                     Architektur, ADRs und Roadmap
```

## Architekturüberblick

Domainmodelle kennen weder Flutter noch Drift. `SermonDocument` ist die
fachliche Quelle der Wahrheit und wird deterministisch als JSON in SQLite
gespeichert. Riverpod stellt konkrete Repositorys bereit. `go_router` navigiert
zwischen Bibliothek, Raw-, Script- und Livemode. Weitere Details stehen in
[docs/architecture.md](docs/architecture.md).

## Bekannte Einschränkungen

- Fett und kursiv gelten in Version 1 für einen ganzen Absatzblock, nicht für
  freie Textauswahlen.
- Die Outline-Navigation im Editor zeigt Struktur und Kennzahlen; präzises
  Scrollen zu einem Block ist im Livemode derzeit nur angenähert.
- Drag-and-drop und eine Versionshistorien-Oberfläche sind noch nicht umgesetzt.
- Bildschirm-Aktivhalten ist als Plattformgrenze definiert, aber ohne native
  macOS-Implementierung.
- Die Suche ist eine gekapselte lokale `contains`-Suche; FTS5 folgt später.
- Serien können zugeordnet gespeichert werden, eine vollständige Serienverwaltung
  folgt in Phase 2.

## Roadmap

Die priorisierte Planung steht in [docs/roadmap.md](docs/roadmap.md).

## Lizenz- und Bibelhinweise

Für den Quellcode ist noch keine Veröffentlichungslizenz festgelegt. Der
Prototyp enthält keine vollständige Bibelübersetzung. Mock-Passagen sind kurze,
selbst formulierte Platzhalter und ausdrücklich keine Wiedergabe einer
geschützten Übersetzung. Lizenzierte Bibeltexte müssen später über einen
separaten `BibleProvider` eingebunden werden.
