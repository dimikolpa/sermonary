abstract final class AppConfig {
  static const name = 'Sermonary';
  // Release identity: Never change this after the first public beta. macOS
  // derives the persistent sandbox container from this identifier.
  static const bundleIdentifier = 'app.sermonary.sermonary';
  static const databaseName = 'sermonary';
  static const databaseFileName = '$databaseName.sqlite';
  static const defaultWordsPerMinute = 120;
  static const autosaveDelay = Duration(milliseconds: 700);
}
