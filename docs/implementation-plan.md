# Sermonary – Umsetzungsplan

## Ziel

Ein lokal speichernder macOS-Prototyp, in dem Predigten angelegt, strukturiert
geschrieben, automatisch gespeichert, gesucht, vorgetragen, exportiert und über
den Papierkorb verwaltet werden können.

## Architektur

- Feature-orientierte Flutter-Anwendung mit `app`, `core` und `features`.
- Unveränderliche Domainmodelle sind unabhängig von Flutter und Drift.
- Riverpod stellt Datenbank, Repositorys und sitzungsbezogenen Editorzustand bereit.
- Drift/SQLite speichert Metadaten und das deterministisch serialisierte,
  versionierte `SermonDocument`.
- `go_router` bildet Bibliothek, Editor und Livemode ab.
- Plattformfunktionen liegen hinter kleinen Schnittstellen.

## Paketwahl

- `flutter_riverpod`: Dependency Injection und reaktiver Zustand.
- `go_router`: deklarative Navigation.
- `drift`, `drift_flutter`, `sqlite3_flutter_libs`: lokale SQLite-Persistenz.
- `json_annotation`, `json_serializable`: etablierte JSON-Infrastruktur; das
  polymorphe Dokumentformat erhält bewusst eine kleine explizite Serialisierung.
- `uuid`: stabile Entitäts- und Block-IDs.
- `intl`: lokale Datumsdarstellung.
- `file_selector`: plattformübergreifende native Export-Dateiauswahl.
- `build_runner`, `drift_dev`: Codegenerierung.

Die tatsächlich aufgelösten Versionen werden in `docs/dependencies.md` festgehalten.

## Datenmodell

`Sermon` enthält Metadaten, UTC-Zeitwerte, Sync-Vorbereitungsfelder und genau ein
`SermonDocument`. Das Dokument besitzt eine Schema-Version und typsichere Blöcke:
Titel, Überschrift, Absatz, Liste, Bibelzitat, Zitat, Notiz und Trenner.

Drift-Tabellen: `sermons`, `sermon_series`, `sermon_topics`, `sermon_tags`,
`sermon_preached_dates`, `document_versions`, `app_settings`. Themen und Tags
werden für Version 1 in Join-Tabellen geführt.

## Editorstrategie

Der technische Spike wird mit Flutter-eigenen editierbaren Blockzeilen umgesetzt.
Super Editor bringt für die eng begrenzten Raw-/Script-Interaktionen eine größere
zweite Dokumentabstraktion und komplexe bidirektionale Synchronisierung mit. Für
Version 1 ist ein kleiner Adapter über dem eigenen Modell sicherer und testbarer.
Die Entscheidung und Austauschgrenze stehen in `docs/editor-concept.md`.

Raw- und Scriptblöcke leben gemeinsam im selben Dokument (Option A). Jeder Modus
filtert bzw. präsentiert passende Blöcke; kein Modus löscht verborgene Blöcke.

## Datensicherheit

- Geordnete Schreibwarteschlange pro geöffneter Predigt.
- Autosave nach 700 ms.
- Sofortspeicherung bei Moduswechsel und `Cmd+S`.
- Sichtbare Zustände: ungespeichert, speichert, gespeichert, Fehler.
- Snapshots beim manuellen Speichern und vor größeren Strukturänderungen.
- Fehler werden typisiert und niemals mit vollständigem Predigttext geloggt.

## Risiken

- Mehrzeilige Rich-Text-Spans (fett/kursiv) benötigen langfristig ein erweitertes
  Inline-Modell; Version 1 formatiert ganze Blöcke bewusst begrenzt.
- FTS5 wird erst nach einem stabilen Datenbank-Grundpfad bewertet. Die erste Suche
  darf über normalisierten extrahierten Klartext laufen.
- Drag-and-drop wird nur ergänzt, wenn Tastaturreihenfolge stabil bleibt.
- Bildschirm-Aktivhalten ist plattformspezifisch und bleibt hinter einem Service;
  der erste Adapter kann die Fähigkeit als nicht verfügbar melden.

## Umsetzungsschritte

1. Flutter-Projekt, strikte Lints, Theme, Routing.
2. Domainmodelle, Parser, Dokumentmigration und Hilfslogik.
3. Drift-Schema, Mapper, Repositorys und Demo-Seeding.
4. Responsive Bibliothek mit Suche, Filter, Sortierung und Papierkorb.
5. Blockeditor, Raw-/Scriptmodus, Metadaten-Inspector und Autosave.
6. Outline, Livemode, Timer und Lesezeitschätzung.
7. Markdown-/Text-Export.
8. Unit-, Datenbank-, Widget- und Happy-Path-Tests.
9. Formatierung, Analyse, Tests und macOS-Debug-Build.

## Definition of Done

- Der in Abschnitt 30 des Projektauftrags beschriebene Ablauf ist lokal möglich.
- Neustartfeste Drift-Persistenz und sichtbares Autosave funktionieren.
- `flutter analyze` und `flutter test` laufen ohne Fehler.
- Ein macOS-Debug-Build wird erfolgreich erzeugt.
- README, Abhängigkeiten, Architektur, Datenmodell, Editor-Konzept, Roadmap und ADRs
  beschreiben den tatsächlich implementierten Stand und bekannte Grenzen.
