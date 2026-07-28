# Datenmodell

## Sermon

Das Aggregat enthält stabile ID, Schema-Version, Titel, Untertitel, Status,
Predigtart, strukturierte Bibelstellen, Serie/Position, Themen, Tags, Zielgruppe,
Ort, Plan- und Ist-Dauer, Predigttermine, UTC-Zeitstempel, Favorit/Papierkorb,
Revision und genau ein `SermonDocument`.

Gespeicherte Enumwerte sind sprachunabhängige Bezeichner wie `inProgress` oder
`expository`. Deutsche Labels entstehen ausschließlich in der UI.

## SermonDocument, Version 1

```json
{
  "schemaVersion": 1,
  "blocks": []
}
```

Unterstützte Blocktypen:

- `title`
- `heading` (Ebene 1–3, einklappbar)
- `paragraph` (semantische Rolle, Block-Fett/Kursiv)
- `bulletList` (rekursive Punkte mit stabilen IDs)
- `bibleQuote` (strukturierte Referenz und Übersetzungsmetadaten)
- `quote`
- `note` (`editorOnly`, `liveMode`, `always`)
- `divider`

Jeder Block besitzt ID sowie Erstellungs- und Änderungszeitpunkt. Migrationen
laufen über `DocumentMigrator`; die V1→V1-Migration ist getestet und unverändert.

## BibleReference

Referenzen speichern Buch-ID, Startkapitel/-vers, optionales Endkapitel/-vers
und den ursprünglichen Anzeigetext. Der gekapselte deutsche Parser unterstützt
im Prototyp häufige Schreibweisen für Johannes, Römer, 1. Korinther, Matthäus
und Offenbarung.

## SQLite-Tabellen

- `sermons`
- `sermon_series`
- `sermon_topics`
- `sermon_tags`
- `sermon_preached_dates`
- `document_versions`
- `app_settings`

`revision`, `created_at`, `updated_at` und `deleted_at` bereiten späteren Sync
vor. Schema-Upgrades werden additiv geplant; destruktive Migrationen sind kein
Standardpfad.

## Geplantes `.sermon`-Format

Eine spätere portable Datei ist ein ZIP-Container:

```text
example.sermon/
  manifest.json
  metadata.json
  document.json
  attachments/
  preview/
```
