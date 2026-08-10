import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PresentationMediaService {
  const PresentationMediaService();

  Future<String?> pickAndStoreImage(String sermonId) async {
    final picked = await openFile(
      confirmButtonText: 'Bild auswählen',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Bilder',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
    );
    if (picked == null) return null;
    // Keep presentation media beside the durable Sermonary database location.
    // App updates therefore retain it and paths stay inside the app container.
    final support = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(support.path, 'presentation_media', sermonId),
    );
    await directory.create(recursive: true);
    final extension = p.extension(picked.path).toLowerCase();
    final destination = p.join(
      directory.path,
      '${const Uuid().v4()}${extension.isEmpty ? '.jpg' : extension}',
    );
    await File(picked.path).copy(destination);
    return destination;
  }
}
