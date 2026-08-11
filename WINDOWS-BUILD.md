# Sermonary lokal unter Windows bauen

## Voraussetzungen

- Windows 10 oder Windows 11 (x64)
- Git
- Flutter 3.44.6 im Stable-Kanal
- Visual Studio mit dem Workload **Desktopentwicklung mit C++**

Nach der Installation sollte `flutter doctor -v` die Windows-Entwicklungsumgebung
ohne Fehler erkennen.

## Repository herunterladen

```powershell
git clone https://github.com/dimikolpa/sermonary.git
cd sermonary
```

## Release bauen

```powershell
flutter pub get
flutter build windows --release
```

Der fertige Build liegt anschließend hier:

```text
build\windows\x64\runner\Release\
```

Zum Start `Sermonary.exe` in diesem Ordner ausführen.

## Build weitergeben

Zur Weitergabe muss der **gesamte Inhalt des Release-Ordners** als ZIP gepackt
werden. Die EXE allein reicht nicht aus, weil Sermonary die danebenliegenden
DLL-Dateien und den Ordner `data` benötigt.

Da die Beta noch nicht digital signiert ist, kann Windows SmartScreen beim
ersten Start eine Warnung anzeigen.
