# Architektur

## Schichten und Datenfluss

```text
Flutter UI → Riverpod-Anwendungszustand → Repository-Schnittstelle
                                      → Drift-Adapter → SQLite
```

Die Feature-Ordner trennen `domain`, `data`, `application` und `presentation`
nur dort, wo die Schicht tatsächlich Inhalt besitzt. Das vermeidet leere
Abstraktionen.

## Domain

`Sermon` ist das Aggregat für Metadaten und `SermonDocument`. Alle Zeitstempel
werden an der Persistenzgrenze nach UTC normalisiert. IDs sind UUIDs. Das
Dokument besteht aus typsicheren Blöcken und besitzt eine unabhängige
Schema-Version.

## Persistenz

Drift verwaltet ein SQLite-Schema der Version 1. Das Dokument liegt als
deterministisches JSON und zusätzlich als extrahierter Klartext für die lokale
Suche vor. Repositorys übersetzen explizit zwischen Drift-Zeilen und
Domainobjekten. Flutter-Widgetzustand wird nicht gespeichert.

## Zustand und Autosave

Riverpod stellt Datenbank und Repository bereit. Eine Editorinstanz hält genau
einen lokalen Entwurf. Änderungen markieren ihn als ungespeichert und starten
einen 700-ms-Debounce. Eine geordnete Future-Kette verhindert überholende
Schreibvorgänge. Moduswechsel, Verlassen und `Cmd+S` speichern sofort.
Manuelles Speichern erzeugt vorher einen Snapshot in `document_versions`.

## Navigation

- `/library`
- `/trash`
- `/sermons/:id/raw`
- `/sermons/:id/script`
- `/sermons/:id/live`

Raw und Script sind Ansichten desselben Dokuments. Der Livemode ist vollständig
schreibgeschützt.

## Plattformgrenzen

Dateiexport nutzt `file_selector`. Bildschirm-Aktivhalten, Backup und Sync
besitzen explizite Schnittstellen. Nicht verfügbare Fähigkeiten melden dies
offen und simulieren keinen Erfolg. Domaincode importiert kein `dart:io`.

## Fehler und Logging

Die Fehlerfamilie unterscheidet Datenbank, Serialisierung, Migration, Export,
Dateisystem, Bibelprovider und Validierung. UI-Meldungen enthalten keine
Predigttexte. Ein produktives strukturiertes Logging ist noch nicht angebunden;
bis dahin werden keine vollständigen Dokumentinhalte protokolliert.

## Accessibility

Tastaturkürzel, Tooltipps, semantischer Speicherstatus, Systemschrift und
skalierbare Live-Typografie sind umgesetzt. Bekannte Lücken: präzise
Fokusreihenfolge über alle dynamischen Blöcke, Screenreader-Ansagen nach
Blockverschiebung und systemweite Einstellung für reduzierte Bewegung.
