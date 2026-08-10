# KI-Prompt: Eine Predigt für Sermonary Script umwandeln

Diese Anleitung erzeugt eine Importdatei ausschließlich für den
**Script-Bereich**. Notes bleibt leer. `<h1>`, `<h2>` und `<h3>` bilden die
gemeinsame Gliederung und werden deshalb auch in der Notesansicht sichtbar,
ohne dort Stichpunkte anzulegen.

## Direkt kopierbarer Prompt

```text
Wandle die nachfolgende Predigt in eine Sermonary-Importdatei für SCRIPT um.

Gib ausschließlich den fertigen Importtext aus – ohne Einleitung, Erklärung
oder Markdown-Codeblock.

ZIEL

Wandle das vorliegende Manuskript in ein lesbares Format um. Lasse nichts weg. Füge nichts hinzu. Erfinde keine Gedanken, Bibelstellen, Zitate, Beispiele oder Metadaten.

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
Schreibe das Datum als TT.MM.JJJJ oder JJJJ-MM-TT.

SCRIPT-STRUKTUR

- <h1>…</h1> kennzeichnet einen Hauptabschnitt.
- <h2>…</h2> kennzeichnet einen Unterabschnitt.
- <h3>…</h3> kennzeichnet eine kleine Zwischenüberschrift innerhalb eines
  Unterabschnitts.
- <p>…</p> enthält einen ausformulierten, gesprochenen Absatz.
- <quote>…</quote> enthält ein wörtliches Zitat.
- Verwende niemals <li1>, <li2> oder <both>.
- Jeder Block-Tag muss einzeln geschlossen werden. Block-Tags nicht
  verschachteln; `<mark>` ist nur als Inline-Markierung innerhalb eines
  Absatzes oder Zitats zulässig.

UMWANDLUNGSREGELN

1. Erhalte alle Passagen.
2. Bewahre direkte Zitate wortgetreu und setze sie in <quote>.
3. Verwende <h1>, <h2> und <h3> entsprechend der erkennbaren Gliederung.
4. Entferne reine Regiehinweise, sofern sie nicht gesprochen werden sollen.
5. Korrigiere offensichtliche Tippfehler, bewahre sonst alles.

FORMATIERUNG

- **Text** wird fett.
- *Text* wird kursiv.
- ***Text*** wird fett und kursiv.
- <mark>Text</mark> wird gelb markiert.
- `<mark>` darf innerhalb von `<p>` und `<quote>` verwendet und mit Fett- oder
  Kursivschrift kombiniert werden, zum Beispiel
  `<mark>**zentrale Aussage**</mark>`.
- Bewahre vorhandene Hervorhebungen und Markierungen.

PRÜFUNG VOR DER AUSGABE

- Enthält die Datei ausschließlich Metadaten, <h1>, <h2>, <h3>, <p> und
  <quote>?
- Ist jeder Block-Tag geschlossen und nicht in einen anderen Block-Tag
  verschachtelt?
- Ist jedes <mark> mit </mark> geschlossen?
- Wurde nichts erfunden?
- Wurde nichts weggelassen
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

<p>Jesus spricht nicht zuerst zu den **Starken**. Er richtet sich an die
*Müden und Beladenen*, an Menschen, die ihre Last tatsächlich spüren.</p>

<quote>Kommt her zu mir, alle ihr Mühseligen und Beladenen.</quote>

<h2>Das Versprechen</h2>
<h3>Ruhe als Geschenk</h3>

<p>Jesus verspricht <mark>Ruhe</mark>. Diese Ruhe wird nicht verdient, sondern geschenkt.
Darum beginnt Nachfolge nicht mit unserer Leistung, sondern mit seiner
Einladung.</p>
```

## Zulässige Dateien

- `.txt`
- `.md`
- `.markdown`

Die Datei muss als UTF-8 gespeichert sein. Word, PDF, Pages und RTF müssen
zuerst mithilfe des Prompts in UTF-8-Text oder Markdown umgewandelt werden.

Beim Import in Sermonary zuerst **Import**, danach **In Script** wählen. Ein
Notes-Tag wie `<li1>` oder `<li2>` führt bewusst zu einer Fehlermeldung.
