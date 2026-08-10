# KI-Prompt: Eine Predigt für Sermonary Notes umwandeln

Diese Anleitung erzeugt eine Importdatei ausschließlich für den
**Notes-Bereich**. Das Script bleibt leer. `<h1>`, `<h2>` und `<h3>` bilden
die gemeinsame Gliederung und werden deshalb auch in der Scriptansicht
sichtbar, ohne dort Manuskripttext anzulegen.

## Direkt kopierbarer Prompt

```text
Wandle die nachfolgende Predigt in eine Sermonary-Importdatei für NOTES um.

Gib ausschließlich den fertigen Importtext aus – ohne Einleitung, Erklärung
oder Markdown-Codeblock.

ZIEL

Erfinde keine Gedanken, Bibelstellen, Zitate
oder Metadaten.

METADATEN

Beginne mit allen sicher erkennbaren Angaben in dieser Reihenfolge:

<title>Titel</title>
<subtitle>Untertitel, falls vorhanden</subtitle>
<bible>Hauptbibelstelle, z. B. Johannes 3,16–18</bible>
<series>Reihe, falls vorhanden</series>
<kind>Predigt</kind>
<status>Entwurf</status>
<topics>Thema 1, Thema 2</topics>
<tags>Schlagwort 1, Schlagwort 2</tags>
<audience>Zielgruppe, falls vorhanden</audience>
<location>Ort, falls vorhanden</location>
<date>Datum, falls vorhanden, z. B. 15.06.2025</date>
<duration>Minutenzahl, falls vorhanden</duration>

Lasse optionale Angaben weg, wenn sie nicht sicher aus der Vorlage hervorgehen.
Der Titel ist die einzige zwingende Metadatenangabe.
Schreibe das Datum als TT.MM.JJJJ oder JJJJ-MM-TT. Es wird in das Datumsfeld
des Outlines importiert.

NOTES-STRUKTUR

- <h1>…</h1> kennzeichnet einen Hauptabschnitt.
- <h2>…</h2> kennzeichnet einen Unterabschnitt.
- <h3>…</h3> kennzeichnet eine kleine Zwischenüberschrift innerhalb eines
  Unterabschnitts.
- <li1>…</li1> ist ein Hauptstichpunkt.
- <li2>…</li2> ist ein eingerückter Unterpunkt zum vorherigen Hauptstichpunkt.
- Verwende niemals <p>, <quote> oder <both>.
- Jeder Block-Tag muss einzeln geschlossen werden. Block-Tags nicht
  verschachteln; `<mark>` ist nur als Inline-Markierung innerhalb eines
  Stichpunkts zulässig.

FORMATIERUNG

- **Text** wird fett.
- *Text* wird kursiv.
- ***Text*** wird fett und kursiv.
- <mark>Text</mark> wird gelb markiert.
- `<mark>` darf innerhalb von `<li1>` und `<li2>` verwendet und mit Fett- oder
  Kursivschrift kombiniert werden, zum Beispiel
  `<mark>**zentrale Aussage**</mark>`.
- Nutze Fettung, Kursivschrift und gelbe Markierungen sparsam für
  Schlüsselwörter und besonders wichtige Formulierungen.

PRÜFUNG VOR DER AUSGABE

- Enthält die Datei ausschließlich Metadaten, <h1>, <h2>, <h3>, <li1> und
  <li2>?
- Ist jeder Block-Tag geschlossen und nicht in einen anderen Block-Tag
  verschachtelt?
- Ist jedes <mark> mit </mark> geschlossen?
- Wurde nichts erfunden?
- Wurde jeder Satz übernommen?
- Steht außerhalb der Tags kein erklärender Text?

## Beispiel

```text
<title>Kommt her zu mir</title>
<bible>Matthäus 11,28–30</bible>
<date>15.06.2025</date>
<kind>Predigt</kind>
<status>Entwurf</status>
<topics>Ruhe, Gnade, Nachfolge</topics>

<h1>Die Einladung</h1>
<li1>Jesus richtet sich an die **Müden und Beladenen**.</li1>
<li2>Die konkrete Last der Hörer im Einstieg benennen.</li2>
<li1>Die Einladung verlangt keine vorherige Leistung.</li1>

<h2>Das Versprechen</h2>
<h3>Ruhe als Geschenk</h3>
<li1>Jesus schenkt <mark>*Ruhe*</mark>.</li1>
<li2>Ruhe ist Geschenk, nicht Verdienst.</li2>
```

## Zulässige Dateien

- `.txt`
- `.md`
- `.markdown`

Die Datei muss als UTF-8 gespeichert sein. Word, PDF, Pages und RTF müssen
zuerst mithilfe des Prompts in UTF-8-Text oder Markdown umgewandelt werden.

Beim Import in Sermonary zuerst **Import**, danach **In Notes** wählen. Ein
Script-Tag wie `<p>` oder `<quote>` führt bewusst zu einer Fehlermeldung.
