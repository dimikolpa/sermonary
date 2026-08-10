# ADR 007: Dauerhafte Release-Identität und Datenbankkompatibilität

## Status

Angenommen vor Beta 0.9.0.

## Entscheidung

Die macOS-Bundle-ID lautet dauerhaft:

```text
app.sermonary.sermonary
```

Der Datenbankname lautet dauerhaft:

```text
sermonary.sqlite
```

Die erste öffentliche Beta verwendet Version `0.9.0` und Buildnummer `1`.
Spätere Betas und Version 1.0 behalten Bundle-ID und Datenbankdatei bei.

## Begründung

macOS leitet den Sandbox-Container aus der Bundle-ID ab. Ein Wechsel würde
einen neuen Container erzeugen und vorhandene Daten für die App unsichtbar
machen. Die bestehende ID wird beibehalten, damit auch Entwicklungsdaten ohne
manuelle Verschiebung in signierten Release-Builds sichtbar bleiben.

## Verbindliche Regeln

1. Die Bundle-ID darf in Updates nicht geändert werden.
2. Datenbankschemata werden ausschließlich vorwärts migriert.
3. Veröffentlichte Migrationsschritte werden nie entfernt.
4. Vor jeder Schemaänderung wird eine konsistente SQLite-Sicherung erzeugt.
5. Eine Datenbank aus einer neueren App-Version wird nicht schreibend geöffnet.
6. Wiederherstellungen werden im laufenden Prozess nur vorgemerkt und vor dem
   nächsten Datenbankstart atomar ausgeführt.
7. Beta-zu-Beta- und Beta-zu-1.0-Upgrades sind verpflichtende Release-Tests.

## Konsequenzen

Eine spätere Umbenennung der sichtbaren App ist möglich. Eine Änderung der
Bundle-ID erfordert dagegen ein gesondertes, getestetes Container-
Migrationsprogramm und ist kein normales Update.
