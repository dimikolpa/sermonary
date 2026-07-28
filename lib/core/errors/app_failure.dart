sealed class AppFailure implements Exception {
  const AppFailure(this.userMessage, [this.cause]);
  final String userMessage;
  final Object? cause;
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.userMessage, [super.cause]);
}

class SerializationFailure extends AppFailure {
  const SerializationFailure(super.userMessage, [super.cause]);
}

class DocumentMigrationFailure extends AppFailure {
  const DocumentMigrationFailure(super.userMessage, [super.cause]);
}

class ExportFailure extends AppFailure {
  const ExportFailure(super.userMessage, [super.cause]);
}

class FileSystemFailure extends AppFailure {
  const FileSystemFailure(super.userMessage, [super.cause]);
}

class BibleProviderFailure extends AppFailure {
  const BibleProviderFailure(super.userMessage, [super.cause]);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.userMessage, [super.cause]);
}
