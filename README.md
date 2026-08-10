# Sermonary

**Eine umfassende Predigt-Schreib- und Präsentationslösung – von der ersten Idee bis zum Vortrag.**

Sermonary bündelt den gesamten Predigtprozess in einer ruhigen, zusammenhängenden Arbeitsumgebung. Die App verbindet drei bewährte Arbeitsweisen: konzentriertes, ablenkungsarmes Schreiben, ein notizbuchartig organisiertes Predigtarchiv und die Erstellung begleitender Präsentationsfolien.

Das Ziel ist nicht, mehrere allgemeine Programme nebeneinander zu ersetzen, sondern einen speziell auf Predigten zugeschnittenen Workflow anzubieten. Gedanken, Gliederung, Notizen, Manuskript, Bibeltexte, Präsentation und Vortrag bleiben miteinander verbunden und müssen nicht immer wieder zwischen verschiedenen Anwendungen übertragen werden.

Sermonary ist ein eigenständiges Projekt. Erwähnungen oder gedankliche Vergleiche mit bekannten Schreib-, Notiz- oder Präsentationsprogrammen dienen ausschließlich der Beschreibung vertrauter Bedienkonzepte; es besteht keine Verbindung, Partnerschaft oder Empfehlung durch deren Hersteller.

## Aktueller Stand

Sermonary befindet sich in **Version 0.9 Beta** und wird derzeit als lokale macOS-Desktop-App entwickelt. Der zentrale Predigtworkflow ist vollständig nutzbar:

- Predigten können angelegt, importiert, strukturiert und archiviert werden.
- Jede Predigt beginnt mit einer Outline und kann beliebig viele Notes-, Script- und Präsentationsinhalte erhalten.
- Inhalte können eigenständig bleiben oder zu Gruppen verknüpft werden.
- Verknüpfte Notes und Scripts synchronisieren ihre Überschriften und richten Abschnitte im Splitscreen aneinander aus.
- Inhalte lassen sich als neue Version duplizieren und direkt miteinander vergleichen.
- Präsentationsfolien können erstellt und mit konkreten Predigtstellen verknüpft werden.
- Notes, Script und Präsentation lassen sich in mehreren Formaten exportieren.
- Die Live-Ansicht zeigt den gewählten Predigtinhalt, Folienwechsel und die jeweils aktive Folie.
- Alle Inhalte werden lokal in einer SQLite-Datenbank gespeichert.
- Ein Backup- und Wiederherstellungssystem schützt die Daten bei späteren Updates und Datenbankmigrationen.

Die Beta ist für praktische Tests mit realen Predigten geeignet. Die App wird bereits als funktionierender macOS-Release-Build erzeugt; ein signiertes und notarisiertes Installationspaket für eine öffentliche Verteilung ist jedoch noch nicht Bestandteil des aktuellen Stands. Online-Synchronisierung, Web-App und Mehrbenutzerbetrieb gehören ebenfalls noch nicht zum Funktionsumfang.

## Der Predigtflow

Der empfohlene Ablauf lautet **Outline → Notes → Script → Präsentation → Export → Live**. Dieser Flow ist nicht mehr starr: Nach der Outline werden nur die Inhalte angelegt, die für die jeweilige Predigt gebraucht werden. Eine Predigt kann beispielsweise zwei Notes-Dateien, mehrere Script-Versionen, eine Präsentation oder auch nur einen einzelnen Inhalt besitzen.

### 1. Outline – Idee, Einordnung und Überblick

Die Outline ist der feste Ausgangspunkt und Übersichtsbildschirm einer Predigt. Sie ist keine löschbare Inhaltsdatei. Hier werden die wichtigsten Metadaten und die inhaltliche Richtung festgelegt:

- Predigtart und Zuordnung zum Archiv
- Bibelbuch und normalisierte Bibelstelle
- Vortragsreihe und Reihenfolge innerhalb der Reihe
- Titel, Datum und Ort beziehungsweise Gemeinde
- kurze Beschreibung: „Worum geht es in dieser Predigt?“
- Quicknotes für erste Gedanken und spontane Einfälle
- individuelles Hintergrundbild
- unabhängige oder verknüpfte Inhalte hinzufügen

Änderungen an der Einordnung werden bewusst erst mit **Speichern** übernommen. Titel, Datum, Beschreibung und Quicknotes werden dagegen laufend gesichert.

### 2. Notes – die Predigt in Stichpunkten entwickeln

In einem Notes-Inhalt entsteht die stichpunktartige Gliederung der Predigt:

- Stichpunkte auf zwei Hierarchieebenen
- Überschriften der Ebenen H1, H2 und H3
- Fett-, Kursiv- und Markerformatierung
- Mehrfachauswahl über mehrere Blöcke
- Einrücken und Ausrücken per Tabulator
- gemeinsames Bearbeiten mit einem beliebigen zweiten Inhalt im Splitscreen

Sind Notes und Script miteinander verknüpft, werden H1-, H2- und H3-Überschriften in der gesamten Verknüpfungsgruppe synchronisiert. Unverknüpfte Inhalte bleiben vollständig eigenständig. Notes und Quicknotes sind grundsätzlich getrennte Bereiche.

### 3. Script – die Predigt ausformulieren

Ein Script-Inhalt ist der ablenkungsarme Schreibeditor für das vollständige Manuskript:

- normale Absätze sowie H1-, H2- und H3-Überschriften
- Zitatblöcke und Bibeltexte
- Fett-, Kursiv- und Markerformatierung
- Formatierungen als Auswahl oder aktiver Schreibzustand
- Markdown-Erkennung für häufige Formatierungen
- strukturierte Übernahme formatierter Inhalte aus Word
- Mehrfachauswahl, Kopieren, Ausschneiden und Löschen über mehrere Absätze
- Rückgängig und Wiederholen
- Fokusmodus mit dezenter Hervorhebung des aktuellen Abschnitts
- Splitscreen mit jedem anderen Inhalt derselben Predigt

Die Editorlogik erhält Absatzgrenzen und Formatierungen. In verknüpften Textinhalten bilden gemeinsame Überschriften eine Abschnittsstruktur; diese sorgt im Splitscreen für synchrones Scrollen und eine vergleichbare vertikale Ausrichtung. Unverknüpfte Inhalte scrollen unabhängig.

### 4. Präsentation – Folien aus der Predigt entwickeln

Im Präsentationsmodus entstehen die begleitenden Folien direkt neben der Predigt. Verfügbare Vorlagen sind:

- Titelfolie
- Überschrift und Text
- Überschrift und Bibeltext
- Inhaltsangabe
- große Inhaltsangabe ohne separate Überschrift
- Überschrift und Bild
- Überschrift, Bild und Bibeltext
- Bild

Folien können manuell oder intelligent aus ausgewähltem Text erzeugt werden. Sermonary erkennt dabei – abhängig von der Vorlage – Überschriften, umgebenden Kontext und Bibelstellen. Eine Präsentation muss mit einem Notes- oder Script-Inhalt verknüpft sein, bevor Folien dort verankert werden können. Beim Verankern einer zuvor unabhängigen Präsentation kann die passende Verknüpfung automatisch entstehen.

Dezente, nummerierte Folienmarker zeigen Wechselstellen in Notes, Script und Live-Modus an; beim Darüberfahren erscheint eine Vorschau. Verankerte Folien werden automatisch nach ihrer Position im Text sortiert, während unverankerte Folien manuell dazwischen angeordnet werden können. Lange Bibeltexte werden bei Bedarf auf zusammengehörige Folgefolien verteilt.

Alle Präsentationstexte unterstützen Fett, Kursiv und Markierung. Folien können dupliziert, sortiert, gelöscht und nachträglich bearbeitet werden. Bilder mit Transparenz werden vor dem Hintergrund der Folie dargestellt.

### 5. Export – Inhalte weitergeben oder ausdrucken

Das gemeinsame Exportmenü trennt die drei Inhaltsbereiche:

**Notes**

- PDF
- Word
- Drucken

**Script**

- PDF
- Word
- Drucken

**Präsentation**

- PDF
- bearbeitbare PowerPoint-Datei
- pixelgetreue PowerPoint-Datei mit gerenderten Folien

Der bearbeitbare PowerPoint-Export erhält Texte und Formatierungen möglichst als editierbare Elemente. Der pixelgetreue Export rendert jede Folie als Bild und bewahrt dadurch das Erscheinungsbild aus Sermonary besonders exakt.

PDF- und Druckausgaben von Notes und Script enthalten dezente, nummerierte Hinweise auf verankerte Folienwechsel. Word-Dateien bleiben bewusst frei von diesen Präsentationsanmerkungen. PDF und Druck verwenden ein A4-Layout mit Predigttitel beziehungsweise Bibelstelle im Kopfbereich und Seitenzahlen im Fußbereich.

### 6. Live – die Predigt vortragen

Die Live-Ansicht reduziert die Oberfläche auf das Wesentliche für den Vortrag:

- gut lesbare Darstellung des Manuskripts
- heller und dunkler Modus
- anpassbare Textgröße und Textbreite
- Timer
- einblendbare Outline
- Tastaturnavigation
- freie Wahl des vorhandenen Notes- oder Script-Inhalts für den Vortrag
- nummerierte Folienwechsel direkt im Fließtext
- Vorschau einer Folie beim Darüberfahren über den Wechselmarker
- Anzeige der zum aktuellen Abschnitt gehörenden Präsentationsfolie rechts neben dem Text

## Funktionen im Überblick

### Archiv und Navigation

- automatische Archivierung nach Bibelbüchern
- kanonische Sortierung nach Kapitel und Vers
- Vortragsreihen mit frei wählbarer Reihenfolge
- Kategorien für Kurzthemen, Einleitungen und Vorträge
- zusätzliche Buchzuordnung für Reihenpredigten und Vorträge
- alphabetische Sortierung der Vortragsreihen
- Umbenennen von Vortragsreihen
- Duplizieren und Löschen von Predigten
- sichtbare Gruppierung zusammengehöriger Predigtversionen
- Zuordnen und Lösen von Versionen per Drag-and-drop
- lokale Suche mit bevorzugten Titeltreffern und anschließenden Inhaltstreffern
- Wiederherstellen der zuletzt geöffneten Predigt, Ansicht und Splitscreen-Belegung nach einem Neustart

### Modulare Predigtinhalte

- beliebig viele Notes-, Script- und Präsentationsinhalte pro Predigt
- eigene Namen für Inhalte; ohne Namen wird ihr Erstellungsdatum angezeigt
- Inhaltsbaum direkt unter der ausgewählten Predigt
- unabhängige Inhalte ohne automatische Synchronisierung
- Verknüpfungsgruppen aus beliebig vielen Inhalten
- gemeinsame H1-, H2- und H3-Struktur in verknüpften Textinhalten
- synchrones Scrollen und ausgerichtete Abschnitte im Splitscreen
- Verknüpfen gefüllter Inhalte, sofern ihre Überschriften verlustfrei zusammengeführt werden können
- Verknüpfen per Drag-and-drop auf einen anderen Inhalt
- automatisches Lösen einer Verknüpfung beim Herausziehen nach oben oder unten
- eigenständige Kopien gemeinsamer Überschriften beim Lösen einer Gruppe
- mehrere Versionen eines Inhalts; Duplikate behalten Inhaltstyp und Verknüpfungsgruppe des Originals
- Öffnen zweier Versionen nebeneinander mit ausgerichteten Überschriften und Absätzen
- Löschen einzelner Inhalte nach Sicherheitsabfrage

Der aktuelle Versionsvergleich richtet Inhalte visuell aneinander aus. Eine detaillierte Änderungsverfolgung mit markierten Ergänzungen und Löschungen ist noch nicht implementiert.

### Bibelstellen und Bibeltexte

- robuste Normalisierung unterschiedlicher Schreibweisen von Bibelstellen
- automatische Auflösung vollständiger Kapitelbereiche
- lokale Bibelauswahl für ELB85 nach Buch, Kapitel und Versbereich
- manuelles Einfügen kopierter Bibeltexte
- Bereinigung typischer BibleServer-Formatierungen und numerischer Fußnoten
- Einfügen als Zitat im Script oder Stichpunkt in Notes

### Schreiben und Bearbeiten

- automatische lokale Speicherung
- stabile Absatz- und Überschriftenstruktur
- synchronisierte Überschriften innerhalb verknüpfter Inhaltsgruppen
- direkte Titelbearbeitung in Outline, Notes und Script
- Tastaturkürzel für Überschriften, Zitate und Textformatierungen
- formatierte und unformatierte Zwischenablage
- Übernahme von Word-Überschriften und Absatzgrenzen
- Markdown-Kurzschreibweisen
- Auswahl über mehrere Absätze in beide Richtungen
- echter Splitscreen für zwei frei wählbare Inhalte
- Öffnen eines Inhalts im Splitscreen über Inhaltsauswahl, untere Navigation oder Drag-and-drop
- Hervorhebung beider aktuell geöffneter Inhalte im Inhaltsbaum
- Verhindern, dass derselbe Inhalt gleichzeitig in beiden Bildschirmhälften geöffnet ist
- Focus Mode und kontextbezogenes Verblassen nicht aktiver Abschnitte

Wichtige Editor-Kürzel auf macOS und Windows (`⌘` entspricht unter Windows
`Strg`):

- `⌘1`, `⌘2`, `⌘3` für H1, H2 und H3
- `⌘Q` für einen Zitatblock
- `⌘B`, `⌘I`, `⌘M` für Fett, Kursiv und Markierung
- `⌘Z` und `⌘⇧Z` für Rückgängig und Wiederholen
- `⌘⇧V` für unformatiertes Einfügen im aktuellen Absatzformat
- `Tab` zum Wechsel der Stichpunkthierarchie in Notes
- `Enter` zum Aufteilen beziehungsweise Fortsetzen im passenden Absatzformat

Dropdown-Felder unterstützen außerdem eine Tastatursuche: Buchnamen, Kapitel und andere lange Listen lassen sich durch direktes Tippen schneller durchsuchen.

### Import

Predigten können als UTF-8-kodierte Text- oder Markdown-Dateien importiert werden. Beim Import wird bewusst entschieden, ob eine **Notes-** oder eine **Script-Datei** erzeugt wird; der andere Inhalt wird nicht automatisch angelegt. Nach dem Import öffnet Sermonary direkt die Outline der neuen Predigt, damit Einordnung und Metadaten geprüft werden können.

Unterstützt werden unter anderem:

- Titel und Metadaten
- Datum
- H1-, H2- und H3-Überschriften
- Absätze und Zitate
- Stichpunkte auf zwei Ebenen
- Fett, Kursiv und Markierungen
- tolerante Korrektur eindeutig erkennbarer Syntaxfehler

Die genauen Formate und KI-Prompts stehen in:

- [Import-Anleitung für Notes](IMPORT-NOTES-README.md)
- [Import-Anleitung für Script](IMPORT-SCRIPT-README.md)

### Darstellung

- helles und dunkles App-Design
- eigene helle und dunkle Hintergrundbilder für alle Bibelbücher
- individuell wählbare Predigthintergründe
- reduzierte Typografie mit DM Sans und Literata
- responsive Spalten und getrennte Scrollbereiche im Archiv
- Inhaltsnavigation im Baum der zweiten Spalte und am unteren Rand jedes Arbeitsbereichs
- sichtbare aktive Inhalte auch im Splitscreen
- integriertes Onboarding für Archiv, modulare Inhalte, Splitscreen, Präsentation, Export und Live-Modus

### Daten, Backup und Beta-Feedback

- lokale Drift-/SQLite-Datenbank
- feste Bundle-ID `app.sermonary.sermonary` und migrationsfähige Datenstruktur
- versioniertes, strukturiertes Predigtdokument mit mehreren Inhaltsmodulen
- automatische Sicherung vor Datenbankmigrationen
- manuelles Backup und Wiederherstellen
- lokal gespeicherte Feedbackberichte nach Kategorien mit optionalem Screenshot
- Screenshot-Anhänge als PNG, JPG oder WebP bis maximal 10 MB
- keine automatische Übertragung persönlicher Predigtdaten oder Feedbacks

Weitere Hinweise: [Backup und Wiederherstellung](docs/backup-and-restore.md)

## Mögliche zukünftige Erweiterungen

Die folgenden Punkte sind Produktideen und keine verbindliche Zusage für eine bestimmte Version:

### Unterschiedliche Predigtflows

Nicht jede Predigt entsteht in derselben Reihenfolge. Zukünftig könnten alternative oder frei konfigurierbare Abläufe angeboten werden – beispielsweise ein schneller Flow für Kurzandachten, ein exegetischer Langform-Flow oder ein präsentationsorientierter Vortrag.

### Weitere Font-Pairings und Designs

Zusätzliche sorgfältig abgestimmte Schriftkombinationen, Präsentationsthemen und Layoutvarianten könnten unterschiedliche Gemeinden, Vortragsformen und persönliche Schreibstile unterstützen.

### Sichere Online-Speicherung und Synchronisierung

Eine optionale verschlüsselte Cloud-Sicherung könnte Predigten zwischen mehreren Geräten synchronisieren. Local-first soll dabei ein Grundprinzip bleiben: Die eigenen Inhalte sollen auch ohne Internetverbindung vollständig verfügbar sein.

### Web-App

Eine Browser-Version könnte Sermonary auf weiteren Betriebssystemen zugänglich machen und die Grundlage für geräteübergreifendes Arbeiten schaffen.

### Weitere denkbare Ausbaustufen

- zusätzliche lizenzierte oder selbst importierbare Bibelübersetzungen
- frei konfigurierbare Präsentationsvorlagen
- Referentenansicht und externe Präsentationssteuerung
- vollständige Versionshistorie mit Änderungsmarkierungen und Wiederherstellung einzelner Stände
- optionaler Team- oder Gemeindemodus mit gezielten Freigaben
- mobile Begleitansichten für Live-Modus und spontane Notizen
- erweiterte Suche mit Filtern, Schlagworten und Volltextindex

## Technischer Überblick

Sermonary wird mit Flutter und Dart entwickelt. Die App folgt einem Local-first-Ansatz und speichert das fachliche Predigtdokument strukturiert als versionierbares JSON in einer lokalen SQLite-Datenbank. Das Dokumentmodell umfasst eigenständige Inhaltsmodule, Verknüpfungsgruppen, Inhaltsversionen, formatierte Blöcke, Präsentationsfolien und ihre Anker. Dadurch können Datenbank und Dokumentformat in späteren Versionen kontrolliert migriert werden.

```text
lib/
  app/                    App, Theme, Navigation und Provider
  core/                   Datenbank, Backup, Fehler und gemeinsame Widgets
  features/
    bible/                Bibeltexte und Referenznormalisierung
    export/               PDF-, Word- und Druckexport
    feedback/             lokales Beta-Feedback
    import/               strukturierter Predigtimport
    library/              Predigten, Archiv und Repository
    live_mode/            Vortragansicht
    presentation/         Folieneditor und Präsentationsexport
    sermon_editor/        gemeinsames Dokumentmodell
    workspace/            Outline, Notes, Script und Arbeitsoberfläche
test/                     Unit-, Datenbank- und Oberflächentests
docs/                     Architektur, Entscheidungen und Roadmap
```

Weitere technische Dokumente:

- [Architektur](docs/architecture.md)
- [Datenmodell](docs/data-model.md)
- [Roadmap](docs/roadmap.md)
- [Release-Identität und Datenbankkompatibilität](docs/decisions/007-release-identity-and-database-compatibility.md)

## Entwicklung und Start

Vorausgesetzt werden eine kompatible Flutter-/Dart-Installation, Xcode und CocoaPods.

```bash
flutter pub get
flutter run -d macos
```

Release-Version bauen:

```bash
flutter build macos --release
```

Qualitätsprüfungen:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Die gebaute App liegt anschließend unter:

```text
build/macos/Build/Products/Release/Sermonary.app
```

Der aktuelle Stand wird mit Unit-, Datenbank- und Oberflächentests geprüft. Zum Zeitpunkt dieser README-Aktualisierung bestehen **174 automatisierte Tests** sowie die statische Flutter-Analyse; zusätzlich lässt sich der macOS-Release-Build erfolgreich erzeugen.

## Rechtliche Hinweise

- Für den Quellcode ist derzeit keine öffentliche Nutzungslizenz festgelegt. Ohne ausdrückliche Lizenz werden keine Nutzungsrechte am Quellcode eingeräumt.
- Rechte an importierten Predigten, Bildern, Schriftarten und Bibelübersetzungen müssen durch die jeweils nutzende oder verbreitende Person geklärt werden.
- Enthaltene oder importierte Bibeltexte dürfen nur im Rahmen der jeweils geltenden Lizenz genutzt und weitergegeben werden.
- Namen und Marken anderer Softwareprodukte gehören ihren jeweiligen Rechteinhabern. Sie werden in diesem Dokument höchstens beschreibend verwendet; Sermonary ist nicht mit diesen Unternehmen verbunden.
