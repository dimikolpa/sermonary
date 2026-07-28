# ADR 003: Strukturiertes Predigtdokument

## Kontext

Raw-, Script- und Livemode müssen dasselbe Dokument ohne Bindung an ein
Editorformat nutzen.

## Entscheidung

Ein eigenes versioniertes, typsicheres Blockmodell ist die fachliche Quelle der
Wahrheit. JSON ist nur die deterministische Speicherrepräsentation.

## Gründe

Verlustfreie Moduswechsel, kontrollierte Exporte, Migrationen und austauschbare
Editoren.

## Alternativen

Markdown, HTML, Quill Delta oder getrennte Dokumente je Modus.

## Konsequenzen

Adapter übersetzen zwischen Widgets und Domainblöcken.

## Bekannte Risiken

Inline-Formatierung und zukünftige Anhänge erfordern neue, abwärtskompatible
Schema-Versionen.
