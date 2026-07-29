# ADR 006: Abgeleitete Archivnavigation

## Kontext

Das bestehende OneNote-Archiv ordnet Predigten zuerst nach Bibelbuch, danach
nach Bibelabschnitt. Vortragsreihen, Vorträge und Kurzthemen bilden getrennte
Bereiche.

## Entscheidung

Die Navigation wird aus strukturierten Fachdaten abgeleitet:

- Bibelbücher entstehen aus `primaryBibleReference.bookId`.
- Ihre Reihenfolge folgt dem kanonischen `BibleBookCatalog`.
- Predigten innerhalb eines Buches werden nach Kapitel und Startvers sortiert.
- Vortragsreihen entstehen aus vorhandenen `seriesId`-Werten.
- `ContentKind` unterscheidet Predigt, Vortrag und Kurzthema.

## Gründe

Es entstehen keine veralteten oder leeren Ordner. Umbenennungen und spätere
Importe verändern die Navigation automatisch, ohne eine zweite
Navigationsstruktur synchron halten zu müssen.

## Alternativen

Frei verwaltete Ordner, Tags für Archivbereiche oder eine fest codierte Liste
aller Bibelbücher.

## Konsequenzen

Eine Predigt erscheint erst unter einem Bibelbuch, wenn ihre Hauptbibelstelle
strukturiert erfasst ist. Predigten ohne Stelle bleiben unter „Alle Predigten“
sichtbar.

## Bekannte Risiken

Mehrere gleichrangige Hauptstellen benötigen später eine definierte
Sortierstrategie. Reihen werden derzeit über ihren Namen als ID geführt; eine
vollständige Reihenverwaltung soll künftig stabile IDs und separate Titel
verwenden.
