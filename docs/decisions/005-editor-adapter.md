# ADR 005: Kleiner Blockeditor hinter Adapter

## Kontext

Super Editor wurde als Rendering-Layer geprüft, während das eigene Dokumentmodell
Quelle der Wahrheit bleiben muss.

## Entscheidung

Version 1 nutzt Flutter-Textfelder pro Block und einen schmalen `EditorAdapter`.
Super Editor wird nicht als Kernabhängigkeit aufgenommen.

## Gründe

Raw-Einrückung, Blockwechsel und Autosave bleiben direkt auf stabilen IDs
abbildbar. Eine zweite komplexe Dokumentrepräsentation und verlustanfällige
Synchronisierung werden vermieden.

## Alternativen

Super Editor, WebView-Editor, Quill oder ein Fork.

## Konsequenzen

Begrenzte Rich-Text-Funktionen werden selbst umgesetzt. Der Adapter hält einen
späteren Wechsel möglich.

## Bekannte Risiken

IME, komplexe Auswahl über Blockgrenzen und umfangreiches Inline-Rich-Text sind
mit einzelnen Textfeldern begrenzt.
