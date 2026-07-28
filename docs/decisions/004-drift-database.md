# ADR 004: Drift-Datenbank

## Kontext

SQLite-Zugriffe sollen typsicher, testbar und migrationsfähig sein.

## Entscheidung

Drift verwaltet Schema, Abfragen, Transaktionen und In-Memory-Tests.

## Gründe

Aktive Pflege, Compile-time-Prüfung und gute Flutter-/SQLite-Integration.

## Alternativen

Direktes `sqlite3`, Floor, Isar oder Hive.

## Konsequenzen

Generierte Dateien gehören zum Buildprozess; Drift bleibt in der Datenschicht.

## Bekannte Risiken

Web benötigt später eine abweichende SQLite-Laufzeitkonfiguration.
