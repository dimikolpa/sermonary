# Bericht zum Figma-Import

Stand: 29. Juli 2026

## Ergebnis

Der in Figma Make veröffentlichte Stand „Low Distraction Writer Design“ und der
vollständige Export unter `imports/Figma/` wurden in die bestehende
Flutter-/Riverpod-/Drift-Anwendung übertragen. Das neue Hauptfenster folgt dem
Figma-Aufbau mit drei Spalten, denselben Ansichtsmodi und einem gemeinsamen,
versionierten Predigtdokument.

Die React-/Tailwind-Referenz wurde nicht als zweite Anwendung eingebettet.
Layout, Verhalten und Inhalte wurden nativ in Flutter nachgebaut und an das
vorhandene lokale Datenmodell angeschlossen.

## Übernommener Look

- Navigationsspalte: 172 px
- Eintragsspalte: 210 px
- Schreibspalte: maximal 620 px
- Outline: maximal 580 px
- Split-Screen: maximal 1160 px
- Werkzeugleiste: 48 px
- helle und dunkle Farbwerte aus den Figma-Tokens
- Radien, Haarlinien, Opazitäten, Innenabstände und ruhige Übergänge
- originale Sermonary-Grafik aus dem Figma-Export
- Lucide-Icons wie in der Referenz
- unterer Verlauf über dem scrollenden Dokument
- Fokusmodus mit animiertem Ausblenden der beiden Archivspalten

## Schriften

Die verwendeten Schriften wurden aus dem offiziellen Google-Fonts-Repository
lokal eingebunden:

- DM Sans Variable, normal und kursiv
- Literata Variable, normal und kursiv

Die Oberfläche nutzt DM Sans, der Schreib- und Vortragstext Literata. Es werden
keine Webfonts zur Laufzeit geladen. Die SIL-OFL-Lizenztexte liegen in
`assets/licenses/`.

## Übernommene und vervollständigte Funktionen

- dynamische Bücherliste: nur Bücher mit vorhandenen Predigten
- Sortierung der Predigten nach Kapitel und Vers
- Vortragsreihen anlegen, umbenennen und mitsamt Einträgen in den Papierkorb
  verschieben
- Bereiche Kurzthemen, Einleitungen und Vorträge
- neue Einträge passend zum aktuell gewählten Bereich
- Outline mit Typ, Buch/Bibelabschnitt, Reihe, Titel, Datum, Ort und
  Zusammenfassung
- Notizenansicht mit Stichpunkten und Unterpunkten
- Skriptansicht mit Überschriften, Absätzen und Zitaten
- kombinierter Notizen-/Skript-Split-Screen mit gemeinsam ausgerichteten
  Überschriften
- Blocktyp-Auswahl
- Fett, Kursiv und gelbe Hervorhebung auf markierten Textbereichen
- Enter für einen Folgeblock, Backspace zum Entfernen eines leeren Blocks,
  Tab/Shift-Tab für Notiztiefe
- Wortzahl und geschätzte Dauer mit 105 Wörtern pro Minute
- automatisches lokales Speichern und sichtbarer Speicherstatus
- Hell-/Dunkelmodus
- Fokusmodus
- Live-Ansicht
- echte lokale PDF-/Druckvorschau mit den eingebetteten Schriften
- Tastaturkürzel für Speichern und Ansichtswechsel

Die Figma-Blöcke wurden in das bestehende typisierte Dokumentformat übersetzt.
Inline-Formatierungen und Notiztiefe sind serialisiert und bleiben nach einem
Neustart erhalten. Ältere Gliederungslisten werden beim Öffnen
nicht-destruktiv in die neue Notizdarstellung überführt.

## Technische Anpassungen

- Die Figma-Zustände wurden nicht als flüchtige React-Objekte übernommen,
  sondern mit Riverpod und dem vorhandenen Drift-Repository verbunden.
- Split-Screen, Inline-Markierungen und die Kategorie „Einleitung“ wurden im
  Domainmodell ergänzt.
- Reihen-Umbenennungen aktualisieren alle zugehörigen Predigten konsistent.
- Die Print-Schaltfläche ist über den Figma-Prototyp hinaus vollständig
  funktionsfähig.
- Bestehende Legacy-Routen werden auf die entsprechenden neuen Ansichten
  weitergeleitet.

## Vorhandene Funktionen ohne eindeutige Figma-Zuordnung

Folgende Funktionen des bisherigen Prototyps sind im neuen Figma-Hauptfenster
nicht vorgesehen und werden dort vorerst nicht angeboten. Datenmodell und
Repository-Code wurden nicht entfernt:

- globale Suche und alternative Sortierungen
- Detail-Metadaten wie Status, Tags, Themen, Zielgruppe und geplante Dauer
- Duplizieren sowie einzelne Papierkorb-, Wiederherstellungs- und
  endgültige Löschaktionen
- Datei-Export
- manuelle Gliederungsverschiebung und spezielle Bibelzitat-Einfügung

Damit gehen keine gespeicherten Felder verloren. Für eine spätere
Wiedereinführung brauchen diese Funktionen einen eigenen, zum neuen Design
passenden Ort.

## Prüfung

- `flutter analyze`: ohne Hinweise oder Fehler
- alle Unit-, Datenbank- und Widgettests: erfolgreich
- nativer macOS-End-to-End-Test: erfolgreich
- macOS-Release-Build: erfolgreich (`sermonary.app`, 55,8 MB)
- geprüfter Pfad: Anlegen → Outline → Notizen → Split-Screen → Skript →
  Autosave → Live-Ansicht
- PDF-/Druckvorschau auf macOS visuell geprüft
- helle Ansicht, dunkle Ansicht und Split-Screen im laufenden macOS-Fenster
  visuell gegen die Figma-Referenz geprüft

Geringfügige Unterschiede in der Buchstabenrasterung können zwischen dem
Browser-Rendering der Figma-Make-Vorschau und Flutter/macOS auftreten. Schrift,
Schnitte, Größen, Zeilenhöhen und Layoutwerte entsprechen jedoch der Referenz.

Beim universellen macOS-Build melden die transitiven Pakete `objective_c` und
`sqlite3` weiterhin nicht-blockierende Warnungen zu abweichenden
Framework-Dateinamen zwischen Architekturen. Der Build wird korrekt erzeugt;
die Warnungen stammen nicht aus dem importierten UI-Code.
