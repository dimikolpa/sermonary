# Zentrale Abhängigkeiten

Die Versionen entsprechen der Auflösung am 28. Juli 2026 mit Flutter 3.44.6 und
Dart 3.12.2.

| Paket | Version | Zweck und Wahl | Ersatz | Plattformen |
|---|---:|---|---|---|
| flutter_riverpod | 2.6.1 | DI und reaktiver Zustand; reif und gut testbar | Provider, Bloc | alle Flutter-Plattformen |
| go_router | 17.3.0 | deklarative, URL-fähige Navigation | Navigator 2.0 | alle |
| drift | 2.34.x | typsichere SQLite-Abfragen und Migrationen | sqlite3 direkt, Floor | alle mit Laufzeitadapter |
| drift_flutter | 0.3.1 | plattformgerechtes Öffnen der Drift-Datenbank | eigener QueryExecutor | Flutter Desktop/Mobile/Web mit passender Konfiguration |
| uuid | 4.6.0 | stabile UUID-v4-IDs | `crypto`-basierter Generator | alle |
| intl | 0.20.3 | lokale Datumsdarstellung | eigene Formatierung | alle |
| file_selector | 1.1.0 | native plattformübergreifende Exportdialoge | eigener Plattformadapter | macOS, iOS, Windows, Linux, Android, Web |
| collection | 1.19.1 | kleine Iterable-Hilfen | Dart-Kernimplementierung | alle |
| json_annotation / json_serializable | 4.12.0 / 6.14.0 | etablierte JSON-Infrastruktur für künftige Modelle | explizite Mapper | alle |
| build_runner | 2.15.x | Codegenerierung | manuell generierter Code | Entwicklung |
| drift_dev | 2.34.x | Drift-Schema-/Mapper-Generierung | manuelle SQL-Schicht | Entwicklung |
| very_good_analysis | 10.3.0 | strenge, gepflegte Lints | flutter_lints | Entwicklung |
| integration_test | Flutter SDK | nativer Happy-Path | Patrol oder eigene Driver | Flutter-Zielplattformen |

## Versionshinweis

Riverpod 3.4.1 verlangt eine neuere, mit dem installierten stabilen SDK noch
nicht auflösbare Toolchain; 2.6.1 ist die neueste kompatible Version.

`drift_flutter` zieht derzeit `sqlite3_flutter_libs` transitiv für
Legacy-Plattformpfade ein, obwohl das Paket selbst als EOL markiert ist. Es ist
keine direkte Sermonary-Abhängigkeit. Vor Android-/Windows-/Web-Freigaben wird
die Drift-Laufzeit erneut geprüft und gegebenenfalls durch einen expliziten
`sqlite3`-Native-Assets-Executor ersetzt.
