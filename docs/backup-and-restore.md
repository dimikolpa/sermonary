# Datensicherung und Wiederherstellung

## Automatische Sicherung

Sermonary löst den Datenbankpfad vor dem Öffnen von Drift auf. Existiert eine
ältere Schema-Version, wird zuerst über die SQLite-Backup-API eine konsistente
Kopie erzeugt und mit `PRAGMA integrity_check` geprüft. Erst danach darf Drift
die Migration ausführen.

Die fünf neuesten automatischen Sicherungen liegen im Unterordner `Backups`
des App-Dokumentverzeichnisses. Zu jeder Sicherung wird ein JSON-Manifest mit
Bundle-ID, Quell-Schema, Zeitstempel und SHA-256-Prüfsumme geschrieben.

Eine Datenbank mit neuerer Schema-Version wird nicht geöffnet. Dadurch kann ein
älterer Build keine Daten einer neueren Version überschreiben.

## Manuelle Sicherung

Unten links öffnet das Datenbanksymbol den Dialog **Datensicherung**.
**Sicherung erstellen** speichert einen vollständigen SQLite-Snapshot mit der
Endung `.sermonarybackup`. Vorher wird der aktive Entwurf gespeichert.

Die Sicherung enthält Predigten, Notes, Script, Metadaten, Reihen, Versionen,
Papierkorb und Einstellungen.

## Wiederherstellung

Eine Wiederherstellung wird im laufenden Prozess nur vorgemerkt:

1. Die ausgewählte Datei wird auf SQLite-Integrität und Schema-Kompatibilität
   geprüft.
2. Sie wird in den privaten App-Container kopiert.
3. Beim nächsten vollständigen App-Start wird zuerst eine Rettungskopie des
   aktuellen Stands erstellt.
4. Anschließend wird die vorgemerkte Datenbank atomar eingesetzt.
5. Bei einem Fehler wird der vorherige Stand zurückgelegt.

Die App muss nach dem Vormerken vollständig beendet und neu gestartet werden.

## Release-Regel

Vor jeder Beta und jeder 1.x-Version werden mindestens diese Wege getestet:

- Neuinstallation → Daten anlegen → Update installieren.
- Schema 1, 2 und 3 → aktuelles Schema.
- Beta 0.9.x → nächster Beta-Build.
- Letzte Beta → 1.0.0.
- Manuelle Sicherung → Änderung → Wiederherstellung.
- Beschädigte und zu neue Sicherung werden ohne Datenänderung abgewiesen.
