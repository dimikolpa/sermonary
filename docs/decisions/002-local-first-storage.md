# ADR 002: Local-first-Speicherung

## Kontext

Schreiben, Archiv und Vortrag müssen offline und ohne Anbieterbindung funktionieren.

## Entscheidung

SQLite ist die lokale Quelle der Wahrheit. Repository-Schnittstellen trennen
Domain und Persistenz; späterer Sync ist ein separater Adapter.

## Gründe

Transaktionen, Langlebigkeit, einfache Backups und etablierte Plattformunterstützung.

## Alternativen

Dateien pro Predigt, Cloud-Datenbanken oder Key-Value-Stores.

## Konsequenzen

Schema- und Dokumentmigrationen werden dauerhaft gepflegt.

## Bekannte Risiken

Späterer Mehrgeräte-Sync benötigt Konfliktregeln; Revisionen und UTC-Zeitwerte
werden dafür bereits gespeichert.
