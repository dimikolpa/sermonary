# Sermonary – Beta-Abnahmeprotokoll

**Prüfdatum:** 10. August 2026  
**Geprüfter Stand:** 0.9.0 (Build 1)  
**Plattform:** macOS 10.15 oder neuer  
**Bundle-ID:** `app.sermonary.sermonary`

## Ergebnis

Der geprüfte Stand ist funktional als geschlossene Beta einsetzbar. Die
statische Analyse, alle 174 automatisierten Tests, ein vollständiger
macOS-End-to-End-Durchlauf und der Release-Build wurden erfolgreich
abgeschlossen.

Vor einem komfortablen Versand an beliebige Tester fehlt noch die reguläre
Apple-Signierung und Notarisierung. Das erzeugte App-Paket ist technisch
korrekt und intern konsistent, aber nur ad-hoc signiert. macOS Gatekeeper lehnt
es deshalb bei einer normalen externen Verteilung zunächst ab.

## Prüfstrategie

Die Abnahme bestand aus vier Ebenen:

1. statische Prüfung des gesamten Dart-/Flutter-Codes,
2. gezielte Editor- und Datenmodelltests,
3. vollständige automatisierte Regression ohne Testauswahl,
4. echter macOS-Ablauf mit App-Start, Datenbank und Navigation sowie
   abschließendem Release-Build.

## Editor-Grundlagen

| Bereich | Geprüfte Szenarien | Ergebnis |
| --- | --- | --- |
| Schreiben | Text in Notes und Script, Enter mitten im Absatz, neuer Absatz, Cursorposition, Scrollen über dem unteren Verlauf | Bestanden |
| Löschen | Zeichen löschen, formatierte Zeichen löschen und Format erben, leere Überschrift entfernen, Absätze mit Backspace verbinden | Bestanden |
| Mehrfachauswahl | Auswahl über mehrere Absätze und Überschriften, Auswahl in beide Richtungen, Auswahl im Notes-Splitscreen | Bestanden |
| Kopieren | Text innerhalb eines Blocks sowie mehrere strukturierte Blöcke einschließlich Überschriften und Quotes | Bestanden |
| Ausschneiden | Mehrere ausgewählte Blöcke mit `⌘X`, anschließendes Wiederherstellen mit Undo | Bestanden |
| Einfügen | Einfügen am Cursor, Ersetzen einer Mehrblock-Auswahl, strukturierter Sermonary-Inhalt, Word-Inhalt und Klartext | Bestanden |
| Word-Paste | Word-Überschriften 1–3, einzelne Absätze, Leerzeilen, Fett und Kursiv; im Notes-Bereich Umwandlung in Stichpunkte | Bestanden |
| Klartext-Paste | `⌘⇧V` fügt nur Reintext in das aktuelle Absatzformat ein | Bestanden |
| Formatierung | Fett, Kursiv und Markierung auf Auswahl sowie als ein-/ausschaltbarer Schreibzustand | Bestanden |
| Blockformate | H1, H2, H3, Absatz, Quote und Notes-Hierarchien | Bestanden |
| Markdown | Überschriften- und Inline-Syntax wird beim Abschließen des Blocks erkannt | Bestanden |
| Rückgängig | `⌘Z` und `⌘⇧Z`, auch für strukturierte Einfüge- und Ausschneidevorgänge | Bestanden |
| Bibeltext | Manueller Import, ELB85-Auswahl, Bereinigung und Einfügen an der aktuellen Stelle | Bestanden |

## Splitscreen und modulare Inhalte

| Szenario | Ergebnis |
| --- | --- |
| Splitscreen explizit öffnen und schließen | Bestanden |
| Inhalt für die rechte Seite auswählen | Bestanden |
| Notes und Script gleichzeitig anzeigen und bearbeiten | Bestanden |
| Aktive Inhalte in Navigation und Dateibaum erkennen | Bestanden |
| Verknüpfte Überschriften synchronisieren und ausrichten | Bestanden |
| Verknüpfte Inhaltsabschnitte und Versionen vergleichen | Bestanden |
| Unverknüpfte Inhalte unabhängig verwenden | Bestanden |
| Inhalte per Drag-and-drop verknüpfen und durch Wegziehen lösen | Bestanden |
| Wortzählung auf den aktiven bzw. linken Inhalt begrenzen | Bestanden |
| Sitzung mit Predigt, Ansicht und Splitscreen wiederherstellen | Bestanden |

## Workflow und Daten

| Bereich | Geprüfte Szenarien | Ergebnis |
| --- | --- | --- |
| Neue Predigt | Outline öffnen, Titel setzen, Kategorie wählen und speichern | Bestanden |
| Modularer Flow | Notes anlegen, verknüpftes Script anlegen, Inhalte dauerhaft speichern | Bestanden |
| Archiv | Buch-/Reihenzuordnung, Sortierung, Verschieben, Versionen und Suche | Bestanden |
| Outline | Live-Speicherung normaler Metadaten, verzögertes Speichern von Platzierung, lange Inhalte und Quicknotes | Bestanden |
| Präsentation | Folien anlegen, verankern, intelligent befüllen, sortieren und lange Bibeltexte aufteilen | Bestanden |
| Live | Inhalt auswählen, Predigttitel und Script darstellen, Folienhinweise erhalten | Bestanden |
| Import | Notes und Script getrennt importieren, Metadaten und robuste Tags erkennen | Bestanden |
| Export | Notes/Script als PDF, Word und Print sowie Präsentation als PDF und PowerPoint | Bestanden |
| Datenbank | Lesen/Schreiben, bestehendes Dokumentformat, Migration und Backup vor Schemaänderungen | Bestanden |
| Erstinstallation | Einmaliges Anlegen der löschbaren Beispielpredigt | Bestanden |
| Feedback | Lokales Speichern von Text und optionalem Screenshot | Bestanden |

## Echter macOS-End-to-End-Test

Der Test startet die vollständige macOS-App mit einer isolierten Datenbank und
durchläuft folgenden Ablauf:

1. neue Predigt über den Schnelleinstieg anlegen,
2. Titel und Kategorie speichern,
3. Notes-Inhalt anlegen und schreiben,
4. ein verknüpftes Script anlegen und schreiben,
5. Splitscreen öffnen und beide Inhalte anzeigen,
6. Verknüpfung und persistierte Texte direkt in der Datenbank kontrollieren,
7. Live-Modus öffnen, Script auswählen und die sichtbaren Inhalte prüfen.

**Ergebnis:** Bestanden.

## Gefundene und behobene Punkte

### 1. Zitat-Shortcut wich von der Dokumentation ab

Der Editor reagierte nur auf `⌘⌥Q`, obwohl Oberfläche und README `⌘Q`
vorsehen. Der Shortcut wurde auf `⌘Q` korrigiert und mit einem automatisierten
Regressionstest abgesichert.

### 2. End-to-End-Test bildete den alten, festen Predigtflow ab

Der bisherige macOS-Integrationstest suchte nicht mehr vorhandene feste
Notes-/Script-Schaltflächen und prüfte daher den aktuellen modularen Aufbau
nicht. Er wurde vollständig auf Outline, Inhaltsmodule, Verknüpfung,
Splitscreen, Persistenz und Live-Auswahl umgestellt. Dies war ein Fehler in der
Testabdeckung, nicht im sichtbaren Produkt.

## Vollständige Prüfergebnisse

- Flutter-Analyse: **keine Probleme**
- Formatprüfung: **70 Dateien geprüft, keine Abweichung**
- Automatisierte Unit-, Datenbank- und Oberflächentests: **174 von 174 bestanden**
- macOS-End-to-End-Test: **1 von 1 bestanden**
- Release-Build: **erfolgreich**
- App-Bundle/`Info.plist`: **gültig**
- Interne Codesign-Prüfung: **gültig**
- Architekturen: **Apple Silicon und Intel** (`arm64`, `x86_64`)
- Größe des App-Pakets: **ca. 433 MB**

## Bekannte Versandrisiken

### Apple-Signierung und Notarisierung

Die App ist derzeit ad-hoc signiert und besitzt keine Apple-Team-ID.
`codesign --verify` bestätigt ein technisch gültiges Paket, die
Gatekeeper-Prüfung lehnt es jedoch ohne Developer-ID-Signatur und Notarisierung
ab. Für einen kleinen, betreuten Testkreis lässt sich die App über die
macOS-Sicherheitsfreigabe öffnen. Für einen reibungslosen Beta-Versand sollte
als nächster Schritt ein signiertes und notarisiertes ZIP oder DMG erzeugt
werden.

### Abhängigkeiten

Flutter weist darauf hin, dass `irondash_engine_context` und
`super_native_extensions` Swift Package Manager noch nicht unterstützen. Das
beeinträchtigt den aktuellen Build nicht, kann aber bei einer zukünftigen
Flutter-Version relevant werden. Zusätzlich melden die nativen Assets von
`objective_c` und `sqlite3` unterschiedliche Framework-Namen zwischen den
Architekturen. Auch diese Warnungen verhindern den aktuellen Universal-Build
nicht und sollten nach der Beta in einem kontrollierten Dependency-Upgrade
bereinigt werden.

### Paketgröße

Mit etwa 433 MB ist die App für eine Desktop-Beta funktionsfähig, aber relativ
groß. Vor einer breiten Veröffentlichung sollte geprüft werden, welche lokalen
Bibel-, Bild- und Präsentationsassets komprimiert oder bedarfsgerecht
ausgeliefert werden können.

## Freigabeempfehlung

**Funktionale Freigabe für eine geschlossene, betreute Beta: Ja.**

**Freigabe für einen reibungslosen öffentlichen Download: Noch nicht.** Dafür
sind mindestens Developer-ID-Signierung, Notarisierung und ein finales
Installationspaket erforderlich.

Die geprüfte App liegt unter:

`build/macos/Build/Products/Release/Sermonary.app`
