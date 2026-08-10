# Editor-Konzept und technischer Spike

## Ergebnis

Version 1 verwendet einen kleinen Flutter-eigenen Blockeditor hinter dem
Domainmodell. Super Editor wird nicht eingebunden.

## Spike-Bewertung

Die prototypisch benötigten Kerninteraktionen sind:

- stabile Raw-Punkte mit rekursiver Tiefe
- Tab/Shift+Tab, Enter und tastaturgesteuertes Verschieben
- begrenzte Scriptblöcke
- verlustfreier Wechsel über ein gemeinsames Dokument
- zuverlässiges Autosave

Super Editor besitzt ein eigenes, leistungsfähiges Dokument- und
Auswahlmodell. Eine bidirektionale Live-Synchronisierung mit
`SermonDocument` würde in Version 1 mehr Fehlerfläche erzeugen als Nutzen:
Blockidentitäten, rekursive Raw-Punkte und eingeschränkte Formatregeln müssten
in zwei Modellen konsistent gehalten werden.

## Adaptergrenze

Die UI liest und ersetzt ausschließlich typsichere `DocumentBlock`-Objekte.
Raw-Punkte werden für die Bearbeitung kurz in `RawLine`-Einträge abgeflacht und
deterministisch wieder als Baum aufgebaut. Der gespeicherte Inhalt enthält
keine Controller, FocusNodes oder Flutter-Zustände.

## Beziehung der Modi

Option A wurde gewählt: Raw- und Scriptblöcke leben gemeinsam in einer
Blockliste. Der Rawmode bearbeitet Listenblöcke, der Scriptmode die übrigen
Blöcke. Verborgene Blöcke bleiben unverändert. Der Livemode rendert beide
Darstellungen schreibgeschützt.

## Tastatur

- `Tab` / `Shift+Tab`: Raw-Punkt ein-/ausrücken
- `Enter`: Punkt auf gleicher Ebene ergänzen
- `Cmd+Option+↑/↓`: Punkt verschieben
- `Cmd+Option+→`: Punkt einklappen
- `Cmd+1/2/3`: Raw, Script, Live
- `Cmd+S`: sofort speichern
- `Cmd+B`: Bibelblock
- `Cmd+\`: Outline

Die Kürzel verwenden keine bekannten reservierten globalen macOS-Kombinationen.
`Cmd+K` bleibt für die globale Suche vorgesehen; in Version 1 ist das Suchfeld
in der Bibliothek direkt fokussierbar.

## Grenzen

Komplexe Auswahl über Blockgrenzen, IME-Sonderfälle und freie Inline-Spans
werden vor einer Erweiterung erneut bewertet. Wenn diese Anforderungen wachsen,
kann Super Editor oder ein anderer nativer Layer durch einen neuen Adapter
ergänzt werden.
