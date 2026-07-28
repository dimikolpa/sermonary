# ADR 001: Flutter als Plattform

## Kontext

Sermonary startet auf macOS und soll später iPadOS, Windows, Android und Web
unterstützen.

## Entscheidung

UI und Anwendungslogik werden mit aktuellem stabilem Flutter/Dart entwickelt.
Plattformspezifische Fähigkeiten werden über Schnittstellen gekapselt.

## Gründe

Gemeinsame Codebasis, gute Desktop- und Tastaturunterstützung sowie reife
Werkzeuge für Tests und barrierearme Widgets.

## Alternativen

Native Einzelanwendungen, Electron oder eine reine Webanwendung.

## Konsequenzen

Native Spezialfunktionen benötigen Adapter; Desktop-Interaktionen müssen
bewusst getestet werden.

## Bekannte Risiken

Einzelne Plugins können Plattformen unterschiedlich schnell unterstützen.
