import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

enum SermonStatus { draft, inProgress, ready, preached, archived }

enum ContentKind { sermon, talk, shortTopic }

enum SermonType {
  expository,
  topical,
  evangelistic,
  devotional,
  bibleStudy,
  wedding,
  funeral,
  children,
  seminar,
  counseling,
  other,
}

class Sermon {
  const Sermon({
    required this.id,
    required this.schemaVersion,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.sermonType,
    required this.additionalBibleReferences,
    required this.topics,
    required this.tags,
    required this.preachedDates,
    required this.createdAt,
    required this.updatedAt,
    required this.lastOpenedAt,
    required this.isFavorite,
    required this.isDeleted,
    required this.revision,
    required this.document,
    this.primaryBibleReference,
    this.seriesId,
    this.seriesPosition,
    this.audience,
    this.location,
    this.scheduledAt,
    this.plannedDurationMinutes,
    this.actualDurationMinutes,
    this.deletedAt,
    this.contentKind = ContentKind.sermon,
  });

  final String id;
  final int schemaVersion;
  final String title;
  final String subtitle;
  final SermonStatus status;
  final SermonType sermonType;
  final ContentKind contentKind;
  final BibleReference? primaryBibleReference;
  final List<BibleReference> additionalBibleReferences;
  final String? seriesId;
  final int? seriesPosition;
  final List<String> topics;
  final List<String> tags;
  final String? audience;
  final String? location;
  final DateTime? scheduledAt;
  final List<DateTime> preachedDates;
  final int? plannedDurationMinutes;
  final int? actualDurationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastOpenedAt;
  final bool isFavorite;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int revision;
  final SermonDocument document;

  Sermon copyWith({
    String? title,
    String? subtitle,
    SermonStatus? status,
    SermonType? sermonType,
    ContentKind? contentKind,
    BibleReference? primaryBibleReference,
    bool clearPrimaryBibleReference = false,
    String? seriesId,
    int? seriesPosition,
    List<String>? topics,
    List<String>? tags,
    String? audience,
    String? location,
    DateTime? scheduledAt,
    int? plannedDurationMinutes,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    bool? isFavorite,
    bool? isDeleted,
    DateTime? deletedAt,
    int? revision,
    SermonDocument? document,
  }) => Sermon(
    id: id,
    schemaVersion: schemaVersion,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    status: status ?? this.status,
    sermonType: sermonType ?? this.sermonType,
    contentKind: contentKind ?? this.contentKind,
    primaryBibleReference: clearPrimaryBibleReference
        ? null
        : primaryBibleReference ?? this.primaryBibleReference,
    additionalBibleReferences: additionalBibleReferences,
    seriesId: seriesId ?? this.seriesId,
    seriesPosition: seriesPosition ?? this.seriesPosition,
    topics: topics ?? this.topics,
    tags: tags ?? this.tags,
    audience: audience ?? this.audience,
    location: location ?? this.location,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    preachedDates: preachedDates,
    plannedDurationMinutes:
        plannedDurationMinutes ?? this.plannedDurationMinutes,
    actualDurationMinutes: actualDurationMinutes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt ?? this.deletedAt,
    revision: revision ?? this.revision,
    document: document ?? this.document,
  );
}

class SermonSeries {
  const SermonSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.primaryBibleBook,
    required this.colorToken,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
  });
  final String id;
  final String title;
  final String description;
  final String? primaryBibleBook;
  final String colorToken;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
}
