# Windows-Beta verteilen

## Empfohlener Ablauf

Sermonary wird in einem privaten GitHub-Repository verwaltet. Der Workflow
`Windows Beta` baut die App auf einem Windows-Rechner von GitHub und erstellt
eine portable ZIP-Datei.

- Ein manueller Lauf stellt die ZIP-Datei als GitHub-Actions-Artefakt bereit.
- Ein Tag wie `v0.9.0-beta.1` erstellt zusätzlich ein GitHub Release und hängt
  die ZIP-Datei daran.
- Tester erhalten nur die ZIP-Datei, nicht das Repository oder den `.git`-Ordner.

## Testversion starten

1. `Sermonary-…-Windows-x64.zip` herunterladen.
2. Die ZIP-Datei vollständig entpacken.
3. Im entpackten Ordner `Sermonary.exe` starten.
4. Nicht nur die EXE verschieben: Die DLLs und der Ordner `data` werden zum
   Start benötigt.

Da die Beta noch nicht digital signiert ist, kann Windows SmartScreen eine
Warnung anzeigen. Das Paket sollte deshalb nur über einen vereinbarten,
vertrauenswürdigen Download-Link verteilt werden.

## Erste technische Abnahme

Der erste Windows-Test sollte mindestens Start und Neustart, lokale
Datenspeicherung, Backup/Wiederherstellung, Dateiimport, PDF-/Word-/PowerPoint-
Export, Drucken, Bildauswahl und die `Strg`-Tastenkürzel abdecken.
