// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SermonRowsTable extends SermonRows
    with TableInfo<$SermonRowsTable, SermonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SermonRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sermonTypeMeta = const VerificationMeta(
    'sermonType',
  );
  @override
  late final GeneratedColumn<String> sermonType = GeneratedColumn<String>(
    'sermon_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentKindMeta = const VerificationMeta(
    'contentKind',
  );
  @override
  late final GeneratedColumn<String> contentKind = GeneratedColumn<String>(
    'content_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sermon'),
  );
  static const VerificationMeta _primaryBibleReferenceJsonMeta =
      const VerificationMeta('primaryBibleReferenceJson');
  @override
  late final GeneratedColumn<String> primaryBibleReferenceJson =
      GeneratedColumn<String>(
        'primary_bible_reference_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _additionalBibleReferencesJsonMeta =
      const VerificationMeta('additionalBibleReferencesJson');
  @override
  late final GeneratedColumn<String> additionalBibleReferencesJson =
      GeneratedColumn<String>(
        'additional_bible_references_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _documentJsonMeta = const VerificationMeta(
    'documentJson',
  );
  @override
  late final GeneratedColumn<String> documentJson = GeneratedColumn<String>(
    'document_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentPlainTextMeta = const VerificationMeta(
    'documentPlainText',
  );
  @override
  late final GeneratedColumn<String> documentPlainText =
      GeneratedColumn<String>(
        'document_plain_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesPositionMeta = const VerificationMeta(
    'seriesPosition',
  );
  @override
  late final GeneratedColumn<int> seriesPosition = GeneratedColumn<int>(
    'series_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicsJsonMeta = const VerificationMeta(
    'topicsJson',
  );
  @override
  late final GeneratedColumn<String> topicsJson = GeneratedColumn<String>(
    'topics_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _audienceMeta = const VerificationMeta(
    'audience',
  );
  @override
  late final GeneratedColumn<String> audience = GeneratedColumn<String>(
    'audience',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledAtMeta = const VerificationMeta(
    'scheduledAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
    'scheduled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preachedDatesJsonMeta = const VerificationMeta(
    'preachedDatesJson',
  );
  @override
  late final GeneratedColumn<String> preachedDatesJson =
      GeneratedColumn<String>(
        'preached_dates_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _plannedDurationMinutesMeta =
      const VerificationMeta('plannedDurationMinutes');
  @override
  late final GeneratedColumn<int> plannedDurationMinutes = GeneratedColumn<int>(
    'planned_duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualDurationMinutesMeta =
      const VerificationMeta('actualDurationMinutes');
  @override
  late final GeneratedColumn<int> actualDurationMinutes = GeneratedColumn<int>(
    'actual_duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schemaVersion,
    title,
    subtitle,
    status,
    sermonType,
    contentKind,
    primaryBibleReferenceJson,
    additionalBibleReferencesJson,
    documentJson,
    documentPlainText,
    seriesId,
    seriesPosition,
    topicsJson,
    tagsJson,
    audience,
    location,
    scheduledAt,
    preachedDatesJson,
    plannedDurationMinutes,
    actualDurationMinutes,
    createdAt,
    updatedAt,
    lastOpenedAt,
    isFavorite,
    isDeleted,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sermons';
  @override
  VerificationContext validateIntegrity(
    Insertable<SermonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sermon_type')) {
      context.handle(
        _sermonTypeMeta,
        sermonType.isAcceptableOrUnknown(data['sermon_type']!, _sermonTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sermonTypeMeta);
    }
    if (data.containsKey('content_kind')) {
      context.handle(
        _contentKindMeta,
        contentKind.isAcceptableOrUnknown(
          data['content_kind']!,
          _contentKindMeta,
        ),
      );
    }
    if (data.containsKey('primary_bible_reference_json')) {
      context.handle(
        _primaryBibleReferenceJsonMeta,
        primaryBibleReferenceJson.isAcceptableOrUnknown(
          data['primary_bible_reference_json']!,
          _primaryBibleReferenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('additional_bible_references_json')) {
      context.handle(
        _additionalBibleReferencesJsonMeta,
        additionalBibleReferencesJson.isAcceptableOrUnknown(
          data['additional_bible_references_json']!,
          _additionalBibleReferencesJsonMeta,
        ),
      );
    }
    if (data.containsKey('document_json')) {
      context.handle(
        _documentJsonMeta,
        documentJson.isAcceptableOrUnknown(
          data['document_json']!,
          _documentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentJsonMeta);
    }
    if (data.containsKey('document_plain_text')) {
      context.handle(
        _documentPlainTextMeta,
        documentPlainText.isAcceptableOrUnknown(
          data['document_plain_text']!,
          _documentPlainTextMeta,
        ),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('series_position')) {
      context.handle(
        _seriesPositionMeta,
        seriesPosition.isAcceptableOrUnknown(
          data['series_position']!,
          _seriesPositionMeta,
        ),
      );
    }
    if (data.containsKey('topics_json')) {
      context.handle(
        _topicsJsonMeta,
        topicsJson.isAcceptableOrUnknown(data['topics_json']!, _topicsJsonMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('audience')) {
      context.handle(
        _audienceMeta,
        audience.isAcceptableOrUnknown(data['audience']!, _audienceMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
        _scheduledAtMeta,
        scheduledAt.isAcceptableOrUnknown(
          data['scheduled_at']!,
          _scheduledAtMeta,
        ),
      );
    }
    if (data.containsKey('preached_dates_json')) {
      context.handle(
        _preachedDatesJsonMeta,
        preachedDatesJson.isAcceptableOrUnknown(
          data['preached_dates_json']!,
          _preachedDatesJsonMeta,
        ),
      );
    }
    if (data.containsKey('planned_duration_minutes')) {
      context.handle(
        _plannedDurationMinutesMeta,
        plannedDurationMinutes.isAcceptableOrUnknown(
          data['planned_duration_minutes']!,
          _plannedDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('actual_duration_minutes')) {
      context.handle(
        _actualDurationMinutesMeta,
        actualDurationMinutes.isAcceptableOrUnknown(
          data['actual_duration_minutes']!,
          _actualDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOpenedAtMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SermonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SermonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sermonType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sermon_type'],
      )!,
      contentKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_kind'],
      )!,
      primaryBibleReferenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_bible_reference_json'],
      ),
      additionalBibleReferencesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}additional_bible_references_json'],
      )!,
      documentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_json'],
      )!,
      documentPlainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_plain_text'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      ),
      seriesPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_position'],
      ),
      topicsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topics_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      audience: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audience'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      scheduledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_at'],
      ),
      preachedDatesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preached_dates_json'],
      )!,
      plannedDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_duration_minutes'],
      ),
      actualDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_duration_minutes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $SermonRowsTable createAlias(String alias) {
    return $SermonRowsTable(attachedDatabase, alias);
  }
}

class SermonRow extends DataClass implements Insertable<SermonRow> {
  final String id;
  final int schemaVersion;
  final String title;
  final String subtitle;
  final String status;
  final String sermonType;
  final String contentKind;
  final String? primaryBibleReferenceJson;
  final String additionalBibleReferencesJson;
  final String documentJson;
  final String documentPlainText;
  final String? seriesId;
  final int? seriesPosition;
  final String topicsJson;
  final String tagsJson;
  final String? audience;
  final String? location;
  final DateTime? scheduledAt;
  final String preachedDatesJson;
  final int? plannedDurationMinutes;
  final int? actualDurationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastOpenedAt;
  final bool isFavorite;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int revision;
  const SermonRow({
    required this.id,
    required this.schemaVersion,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.sermonType,
    required this.contentKind,
    this.primaryBibleReferenceJson,
    required this.additionalBibleReferencesJson,
    required this.documentJson,
    required this.documentPlainText,
    this.seriesId,
    this.seriesPosition,
    required this.topicsJson,
    required this.tagsJson,
    this.audience,
    this.location,
    this.scheduledAt,
    required this.preachedDatesJson,
    this.plannedDurationMinutes,
    this.actualDurationMinutes,
    required this.createdAt,
    required this.updatedAt,
    required this.lastOpenedAt,
    required this.isFavorite,
    required this.isDeleted,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['status'] = Variable<String>(status);
    map['sermon_type'] = Variable<String>(sermonType);
    map['content_kind'] = Variable<String>(contentKind);
    if (!nullToAbsent || primaryBibleReferenceJson != null) {
      map['primary_bible_reference_json'] = Variable<String>(
        primaryBibleReferenceJson,
      );
    }
    map['additional_bible_references_json'] = Variable<String>(
      additionalBibleReferencesJson,
    );
    map['document_json'] = Variable<String>(documentJson);
    map['document_plain_text'] = Variable<String>(documentPlainText);
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    if (!nullToAbsent || seriesPosition != null) {
      map['series_position'] = Variable<int>(seriesPosition);
    }
    map['topics_json'] = Variable<String>(topicsJson);
    map['tags_json'] = Variable<String>(tagsJson);
    if (!nullToAbsent || audience != null) {
      map['audience'] = Variable<String>(audience);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || scheduledAt != null) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    }
    map['preached_dates_json'] = Variable<String>(preachedDatesJson);
    if (!nullToAbsent || plannedDurationMinutes != null) {
      map['planned_duration_minutes'] = Variable<int>(plannedDurationMinutes);
    }
    if (!nullToAbsent || actualDurationMinutes != null) {
      map['actual_duration_minutes'] = Variable<int>(actualDurationMinutes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  SermonRowsCompanion toCompanion(bool nullToAbsent) {
    return SermonRowsCompanion(
      id: Value(id),
      schemaVersion: Value(schemaVersion),
      title: Value(title),
      subtitle: Value(subtitle),
      status: Value(status),
      sermonType: Value(sermonType),
      contentKind: Value(contentKind),
      primaryBibleReferenceJson:
          primaryBibleReferenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryBibleReferenceJson),
      additionalBibleReferencesJson: Value(additionalBibleReferencesJson),
      documentJson: Value(documentJson),
      documentPlainText: Value(documentPlainText),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      seriesPosition: seriesPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesPosition),
      topicsJson: Value(topicsJson),
      tagsJson: Value(tagsJson),
      audience: audience == null && nullToAbsent
          ? const Value.absent()
          : Value(audience),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      scheduledAt: scheduledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledAt),
      preachedDatesJson: Value(preachedDatesJson),
      plannedDurationMinutes: plannedDurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedDurationMinutes),
      actualDurationMinutes: actualDurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(actualDurationMinutes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: Value(lastOpenedAt),
      isFavorite: Value(isFavorite),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory SermonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SermonRow(
      id: serializer.fromJson<String>(json['id']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      status: serializer.fromJson<String>(json['status']),
      sermonType: serializer.fromJson<String>(json['sermonType']),
      contentKind: serializer.fromJson<String>(json['contentKind']),
      primaryBibleReferenceJson: serializer.fromJson<String?>(
        json['primaryBibleReferenceJson'],
      ),
      additionalBibleReferencesJson: serializer.fromJson<String>(
        json['additionalBibleReferencesJson'],
      ),
      documentJson: serializer.fromJson<String>(json['documentJson']),
      documentPlainText: serializer.fromJson<String>(json['documentPlainText']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      seriesPosition: serializer.fromJson<int?>(json['seriesPosition']),
      topicsJson: serializer.fromJson<String>(json['topicsJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      audience: serializer.fromJson<String?>(json['audience']),
      location: serializer.fromJson<String?>(json['location']),
      scheduledAt: serializer.fromJson<DateTime?>(json['scheduledAt']),
      preachedDatesJson: serializer.fromJson<String>(json['preachedDatesJson']),
      plannedDurationMinutes: serializer.fromJson<int?>(
        json['plannedDurationMinutes'],
      ),
      actualDurationMinutes: serializer.fromJson<int?>(
        json['actualDurationMinutes'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'status': serializer.toJson<String>(status),
      'sermonType': serializer.toJson<String>(sermonType),
      'contentKind': serializer.toJson<String>(contentKind),
      'primaryBibleReferenceJson': serializer.toJson<String?>(
        primaryBibleReferenceJson,
      ),
      'additionalBibleReferencesJson': serializer.toJson<String>(
        additionalBibleReferencesJson,
      ),
      'documentJson': serializer.toJson<String>(documentJson),
      'documentPlainText': serializer.toJson<String>(documentPlainText),
      'seriesId': serializer.toJson<String?>(seriesId),
      'seriesPosition': serializer.toJson<int?>(seriesPosition),
      'topicsJson': serializer.toJson<String>(topicsJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'audience': serializer.toJson<String?>(audience),
      'location': serializer.toJson<String?>(location),
      'scheduledAt': serializer.toJson<DateTime?>(scheduledAt),
      'preachedDatesJson': serializer.toJson<String>(preachedDatesJson),
      'plannedDurationMinutes': serializer.toJson<int?>(plannedDurationMinutes),
      'actualDurationMinutes': serializer.toJson<int?>(actualDurationMinutes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  SermonRow copyWith({
    String? id,
    int? schemaVersion,
    String? title,
    String? subtitle,
    String? status,
    String? sermonType,
    String? contentKind,
    Value<String?> primaryBibleReferenceJson = const Value.absent(),
    String? additionalBibleReferencesJson,
    String? documentJson,
    String? documentPlainText,
    Value<String?> seriesId = const Value.absent(),
    Value<int?> seriesPosition = const Value.absent(),
    String? topicsJson,
    String? tagsJson,
    Value<String?> audience = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<DateTime?> scheduledAt = const Value.absent(),
    String? preachedDatesJson,
    Value<int?> plannedDurationMinutes = const Value.absent(),
    Value<int?> actualDurationMinutes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    bool? isFavorite,
    bool? isDeleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => SermonRow(
    id: id ?? this.id,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    status: status ?? this.status,
    sermonType: sermonType ?? this.sermonType,
    contentKind: contentKind ?? this.contentKind,
    primaryBibleReferenceJson: primaryBibleReferenceJson.present
        ? primaryBibleReferenceJson.value
        : this.primaryBibleReferenceJson,
    additionalBibleReferencesJson:
        additionalBibleReferencesJson ?? this.additionalBibleReferencesJson,
    documentJson: documentJson ?? this.documentJson,
    documentPlainText: documentPlainText ?? this.documentPlainText,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    seriesPosition: seriesPosition.present
        ? seriesPosition.value
        : this.seriesPosition,
    topicsJson: topicsJson ?? this.topicsJson,
    tagsJson: tagsJson ?? this.tagsJson,
    audience: audience.present ? audience.value : this.audience,
    location: location.present ? location.value : this.location,
    scheduledAt: scheduledAt.present ? scheduledAt.value : this.scheduledAt,
    preachedDatesJson: preachedDatesJson ?? this.preachedDatesJson,
    plannedDurationMinutes: plannedDurationMinutes.present
        ? plannedDurationMinutes.value
        : this.plannedDurationMinutes,
    actualDurationMinutes: actualDurationMinutes.present
        ? actualDurationMinutes.value
        : this.actualDurationMinutes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  SermonRow copyWithCompanion(SermonRowsCompanion data) {
    return SermonRow(
      id: data.id.present ? data.id.value : this.id,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      status: data.status.present ? data.status.value : this.status,
      sermonType: data.sermonType.present
          ? data.sermonType.value
          : this.sermonType,
      contentKind: data.contentKind.present
          ? data.contentKind.value
          : this.contentKind,
      primaryBibleReferenceJson: data.primaryBibleReferenceJson.present
          ? data.primaryBibleReferenceJson.value
          : this.primaryBibleReferenceJson,
      additionalBibleReferencesJson: data.additionalBibleReferencesJson.present
          ? data.additionalBibleReferencesJson.value
          : this.additionalBibleReferencesJson,
      documentJson: data.documentJson.present
          ? data.documentJson.value
          : this.documentJson,
      documentPlainText: data.documentPlainText.present
          ? data.documentPlainText.value
          : this.documentPlainText,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      seriesPosition: data.seriesPosition.present
          ? data.seriesPosition.value
          : this.seriesPosition,
      topicsJson: data.topicsJson.present
          ? data.topicsJson.value
          : this.topicsJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      audience: data.audience.present ? data.audience.value : this.audience,
      location: data.location.present ? data.location.value : this.location,
      scheduledAt: data.scheduledAt.present
          ? data.scheduledAt.value
          : this.scheduledAt,
      preachedDatesJson: data.preachedDatesJson.present
          ? data.preachedDatesJson.value
          : this.preachedDatesJson,
      plannedDurationMinutes: data.plannedDurationMinutes.present
          ? data.plannedDurationMinutes.value
          : this.plannedDurationMinutes,
      actualDurationMinutes: data.actualDurationMinutes.present
          ? data.actualDurationMinutes.value
          : this.actualDurationMinutes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SermonRow(')
          ..write('id: $id, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('status: $status, ')
          ..write('sermonType: $sermonType, ')
          ..write('contentKind: $contentKind, ')
          ..write('primaryBibleReferenceJson: $primaryBibleReferenceJson, ')
          ..write(
            'additionalBibleReferencesJson: $additionalBibleReferencesJson, ',
          )
          ..write('documentJson: $documentJson, ')
          ..write('documentPlainText: $documentPlainText, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesPosition: $seriesPosition, ')
          ..write('topicsJson: $topicsJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('audience: $audience, ')
          ..write('location: $location, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('preachedDatesJson: $preachedDatesJson, ')
          ..write('plannedDurationMinutes: $plannedDurationMinutes, ')
          ..write('actualDurationMinutes: $actualDurationMinutes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    schemaVersion,
    title,
    subtitle,
    status,
    sermonType,
    contentKind,
    primaryBibleReferenceJson,
    additionalBibleReferencesJson,
    documentJson,
    documentPlainText,
    seriesId,
    seriesPosition,
    topicsJson,
    tagsJson,
    audience,
    location,
    scheduledAt,
    preachedDatesJson,
    plannedDurationMinutes,
    actualDurationMinutes,
    createdAt,
    updatedAt,
    lastOpenedAt,
    isFavorite,
    isDeleted,
    deletedAt,
    revision,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SermonRow &&
          other.id == this.id &&
          other.schemaVersion == this.schemaVersion &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.status == this.status &&
          other.sermonType == this.sermonType &&
          other.contentKind == this.contentKind &&
          other.primaryBibleReferenceJson == this.primaryBibleReferenceJson &&
          other.additionalBibleReferencesJson ==
              this.additionalBibleReferencesJson &&
          other.documentJson == this.documentJson &&
          other.documentPlainText == this.documentPlainText &&
          other.seriesId == this.seriesId &&
          other.seriesPosition == this.seriesPosition &&
          other.topicsJson == this.topicsJson &&
          other.tagsJson == this.tagsJson &&
          other.audience == this.audience &&
          other.location == this.location &&
          other.scheduledAt == this.scheduledAt &&
          other.preachedDatesJson == this.preachedDatesJson &&
          other.plannedDurationMinutes == this.plannedDurationMinutes &&
          other.actualDurationMinutes == this.actualDurationMinutes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.isFavorite == this.isFavorite &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class SermonRowsCompanion extends UpdateCompanion<SermonRow> {
  final Value<String> id;
  final Value<int> schemaVersion;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String> status;
  final Value<String> sermonType;
  final Value<String> contentKind;
  final Value<String?> primaryBibleReferenceJson;
  final Value<String> additionalBibleReferencesJson;
  final Value<String> documentJson;
  final Value<String> documentPlainText;
  final Value<String?> seriesId;
  final Value<int?> seriesPosition;
  final Value<String> topicsJson;
  final Value<String> tagsJson;
  final Value<String?> audience;
  final Value<String?> location;
  final Value<DateTime?> scheduledAt;
  final Value<String> preachedDatesJson;
  final Value<int?> plannedDurationMinutes;
  final Value<int?> actualDurationMinutes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> lastOpenedAt;
  final Value<bool> isFavorite;
  final Value<bool> isDeleted;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const SermonRowsCompanion({
    this.id = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.status = const Value.absent(),
    this.sermonType = const Value.absent(),
    this.contentKind = const Value.absent(),
    this.primaryBibleReferenceJson = const Value.absent(),
    this.additionalBibleReferencesJson = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.documentPlainText = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seriesPosition = const Value.absent(),
    this.topicsJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.audience = const Value.absent(),
    this.location = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.preachedDatesJson = const Value.absent(),
    this.plannedDurationMinutes = const Value.absent(),
    this.actualDurationMinutes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SermonRowsCompanion.insert({
    required String id,
    required int schemaVersion,
    required String title,
    this.subtitle = const Value.absent(),
    required String status,
    required String sermonType,
    this.contentKind = const Value.absent(),
    this.primaryBibleReferenceJson = const Value.absent(),
    this.additionalBibleReferencesJson = const Value.absent(),
    required String documentJson,
    this.documentPlainText = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seriesPosition = const Value.absent(),
    this.topicsJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.audience = const Value.absent(),
    this.location = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.preachedDatesJson = const Value.absent(),
    this.plannedDurationMinutes = const Value.absent(),
    this.actualDurationMinutes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime lastOpenedAt,
    this.isFavorite = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       schemaVersion = Value(schemaVersion),
       title = Value(title),
       status = Value(status),
       sermonType = Value(sermonType),
       documentJson = Value(documentJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastOpenedAt = Value(lastOpenedAt);
  static Insertable<SermonRow> custom({
    Expression<String>? id,
    Expression<int>? schemaVersion,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? status,
    Expression<String>? sermonType,
    Expression<String>? contentKind,
    Expression<String>? primaryBibleReferenceJson,
    Expression<String>? additionalBibleReferencesJson,
    Expression<String>? documentJson,
    Expression<String>? documentPlainText,
    Expression<String>? seriesId,
    Expression<int>? seriesPosition,
    Expression<String>? topicsJson,
    Expression<String>? tagsJson,
    Expression<String>? audience,
    Expression<String>? location,
    Expression<DateTime>? scheduledAt,
    Expression<String>? preachedDatesJson,
    Expression<int>? plannedDurationMinutes,
    Expression<int>? actualDurationMinutes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<bool>? isFavorite,
    Expression<bool>? isDeleted,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (status != null) 'status': status,
      if (sermonType != null) 'sermon_type': sermonType,
      if (contentKind != null) 'content_kind': contentKind,
      if (primaryBibleReferenceJson != null)
        'primary_bible_reference_json': primaryBibleReferenceJson,
      if (additionalBibleReferencesJson != null)
        'additional_bible_references_json': additionalBibleReferencesJson,
      if (documentJson != null) 'document_json': documentJson,
      if (documentPlainText != null) 'document_plain_text': documentPlainText,
      if (seriesId != null) 'series_id': seriesId,
      if (seriesPosition != null) 'series_position': seriesPosition,
      if (topicsJson != null) 'topics_json': topicsJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (audience != null) 'audience': audience,
      if (location != null) 'location': location,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (preachedDatesJson != null) 'preached_dates_json': preachedDatesJson,
      if (plannedDurationMinutes != null)
        'planned_duration_minutes': plannedDurationMinutes,
      if (actualDurationMinutes != null)
        'actual_duration_minutes': actualDurationMinutes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SermonRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? schemaVersion,
    Value<String>? title,
    Value<String>? subtitle,
    Value<String>? status,
    Value<String>? sermonType,
    Value<String>? contentKind,
    Value<String?>? primaryBibleReferenceJson,
    Value<String>? additionalBibleReferencesJson,
    Value<String>? documentJson,
    Value<String>? documentPlainText,
    Value<String?>? seriesId,
    Value<int?>? seriesPosition,
    Value<String>? topicsJson,
    Value<String>? tagsJson,
    Value<String?>? audience,
    Value<String?>? location,
    Value<DateTime?>? scheduledAt,
    Value<String>? preachedDatesJson,
    Value<int?>? plannedDurationMinutes,
    Value<int?>? actualDurationMinutes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? lastOpenedAt,
    Value<bool>? isFavorite,
    Value<bool>? isDeleted,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return SermonRowsCompanion(
      id: id ?? this.id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      sermonType: sermonType ?? this.sermonType,
      contentKind: contentKind ?? this.contentKind,
      primaryBibleReferenceJson:
          primaryBibleReferenceJson ?? this.primaryBibleReferenceJson,
      additionalBibleReferencesJson:
          additionalBibleReferencesJson ?? this.additionalBibleReferencesJson,
      documentJson: documentJson ?? this.documentJson,
      documentPlainText: documentPlainText ?? this.documentPlainText,
      seriesId: seriesId ?? this.seriesId,
      seriesPosition: seriesPosition ?? this.seriesPosition,
      topicsJson: topicsJson ?? this.topicsJson,
      tagsJson: tagsJson ?? this.tagsJson,
      audience: audience ?? this.audience,
      location: location ?? this.location,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      preachedDatesJson: preachedDatesJson ?? this.preachedDatesJson,
      plannedDurationMinutes:
          plannedDurationMinutes ?? this.plannedDurationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sermonType.present) {
      map['sermon_type'] = Variable<String>(sermonType.value);
    }
    if (contentKind.present) {
      map['content_kind'] = Variable<String>(contentKind.value);
    }
    if (primaryBibleReferenceJson.present) {
      map['primary_bible_reference_json'] = Variable<String>(
        primaryBibleReferenceJson.value,
      );
    }
    if (additionalBibleReferencesJson.present) {
      map['additional_bible_references_json'] = Variable<String>(
        additionalBibleReferencesJson.value,
      );
    }
    if (documentJson.present) {
      map['document_json'] = Variable<String>(documentJson.value);
    }
    if (documentPlainText.present) {
      map['document_plain_text'] = Variable<String>(documentPlainText.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (seriesPosition.present) {
      map['series_position'] = Variable<int>(seriesPosition.value);
    }
    if (topicsJson.present) {
      map['topics_json'] = Variable<String>(topicsJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (audience.present) {
      map['audience'] = Variable<String>(audience.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (preachedDatesJson.present) {
      map['preached_dates_json'] = Variable<String>(preachedDatesJson.value);
    }
    if (plannedDurationMinutes.present) {
      map['planned_duration_minutes'] = Variable<int>(
        plannedDurationMinutes.value,
      );
    }
    if (actualDurationMinutes.present) {
      map['actual_duration_minutes'] = Variable<int>(
        actualDurationMinutes.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SermonRowsCompanion(')
          ..write('id: $id, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('status: $status, ')
          ..write('sermonType: $sermonType, ')
          ..write('contentKind: $contentKind, ')
          ..write('primaryBibleReferenceJson: $primaryBibleReferenceJson, ')
          ..write(
            'additionalBibleReferencesJson: $additionalBibleReferencesJson, ',
          )
          ..write('documentJson: $documentJson, ')
          ..write('documentPlainText: $documentPlainText, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesPosition: $seriesPosition, ')
          ..write('topicsJson: $topicsJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('audience: $audience, ')
          ..write('location: $location, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('preachedDatesJson: $preachedDatesJson, ')
          ..write('plannedDurationMinutes: $plannedDurationMinutes, ')
          ..write('actualDurationMinutes: $actualDurationMinutes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SermonSeriesRowsTable extends SermonSeriesRows
    with TableInfo<$SermonSeriesRowsTable, SermonSeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SermonSeriesRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _primaryBibleBookMeta = const VerificationMeta(
    'primaryBibleBook',
  );
  @override
  late final GeneratedColumn<String> primaryBibleBook = GeneratedColumn<String>(
    'primary_bible_book',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorTokenMeta = const VerificationMeta(
    'colorToken',
  );
  @override
  late final GeneratedColumn<String> colorToken = GeneratedColumn<String>(
    'color_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('forest'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    primaryBibleBook,
    colorToken,
    createdAt,
    updatedAt,
    isArchived,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sermon_series';
  @override
  VerificationContext validateIntegrity(
    Insertable<SermonSeriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('primary_bible_book')) {
      context.handle(
        _primaryBibleBookMeta,
        primaryBibleBook.isAcceptableOrUnknown(
          data['primary_bible_book']!,
          _primaryBibleBookMeta,
        ),
      );
    }
    if (data.containsKey('color_token')) {
      context.handle(
        _colorTokenMeta,
        colorToken.isAcceptableOrUnknown(data['color_token']!, _colorTokenMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SermonSeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SermonSeriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      primaryBibleBook: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_bible_book'],
      ),
      colorToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_token'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $SermonSeriesRowsTable createAlias(String alias) {
    return $SermonSeriesRowsTable(attachedDatabase, alias);
  }
}

class SermonSeriesRow extends DataClass implements Insertable<SermonSeriesRow> {
  final String id;
  final String title;
  final String description;
  final String? primaryBibleBook;
  final String colorToken;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final int revision;
  const SermonSeriesRow({
    required this.id,
    required this.title,
    required this.description,
    this.primaryBibleBook,
    required this.colorToken,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || primaryBibleBook != null) {
      map['primary_bible_book'] = Variable<String>(primaryBibleBook);
    }
    map['color_token'] = Variable<String>(colorToken);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_archived'] = Variable<bool>(isArchived);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  SermonSeriesRowsCompanion toCompanion(bool nullToAbsent) {
    return SermonSeriesRowsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      primaryBibleBook: primaryBibleBook == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryBibleBook),
      colorToken: Value(colorToken),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isArchived: Value(isArchived),
      revision: Value(revision),
    );
  }

  factory SermonSeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SermonSeriesRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      primaryBibleBook: serializer.fromJson<String?>(json['primaryBibleBook']),
      colorToken: serializer.fromJson<String>(json['colorToken']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'primaryBibleBook': serializer.toJson<String?>(primaryBibleBook),
      'colorToken': serializer.toJson<String>(colorToken),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isArchived': serializer.toJson<bool>(isArchived),
      'revision': serializer.toJson<int>(revision),
    };
  }

  SermonSeriesRow copyWith({
    String? id,
    String? title,
    String? description,
    Value<String?> primaryBibleBook = const Value.absent(),
    String? colorToken,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    int? revision,
  }) => SermonSeriesRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    primaryBibleBook: primaryBibleBook.present
        ? primaryBibleBook.value
        : this.primaryBibleBook,
    colorToken: colorToken ?? this.colorToken,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isArchived: isArchived ?? this.isArchived,
    revision: revision ?? this.revision,
  );
  SermonSeriesRow copyWithCompanion(SermonSeriesRowsCompanion data) {
    return SermonSeriesRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      primaryBibleBook: data.primaryBibleBook.present
          ? data.primaryBibleBook.value
          : this.primaryBibleBook,
      colorToken: data.colorToken.present
          ? data.colorToken.value
          : this.colorToken,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SermonSeriesRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('primaryBibleBook: $primaryBibleBook, ')
          ..write('colorToken: $colorToken, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    primaryBibleBook,
    colorToken,
    createdAt,
    updatedAt,
    isArchived,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SermonSeriesRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.primaryBibleBook == this.primaryBibleBook &&
          other.colorToken == this.colorToken &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isArchived == this.isArchived &&
          other.revision == this.revision);
}

class SermonSeriesRowsCompanion extends UpdateCompanion<SermonSeriesRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String?> primaryBibleBook;
  final Value<String> colorToken;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isArchived;
  final Value<int> revision;
  final Value<int> rowid;
  const SermonSeriesRowsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.primaryBibleBook = const Value.absent(),
    this.colorToken = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SermonSeriesRowsCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.primaryBibleBook = const Value.absent(),
    this.colorToken = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isArchived = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SermonSeriesRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? primaryBibleBook,
    Expression<String>? colorToken,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isArchived,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (primaryBibleBook != null) 'primary_bible_book': primaryBibleBook,
      if (colorToken != null) 'color_token': colorToken,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SermonSeriesRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String?>? primaryBibleBook,
    Value<String>? colorToken,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isArchived,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return SermonSeriesRowsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      primaryBibleBook: primaryBibleBook ?? this.primaryBibleBook,
      colorToken: colorToken ?? this.colorToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (primaryBibleBook.present) {
      map['primary_bible_book'] = Variable<String>(primaryBibleBook.value);
    }
    if (colorToken.present) {
      map['color_token'] = Variable<String>(colorToken.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SermonSeriesRowsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('primaryBibleBook: $primaryBibleBook, ')
          ..write('colorToken: $colorToken, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SermonTopicsTable extends SermonTopics
    with TableInfo<$SermonTopicsTable, SermonTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SermonTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sermonIdMeta = const VerificationMeta(
    'sermonId',
  );
  @override
  late final GeneratedColumn<String> sermonId = GeneratedColumn<String>(
    'sermon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sermons (id)',
    ),
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sermonId, topic];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sermon_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<SermonTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sermon_id')) {
      context.handle(
        _sermonIdMeta,
        sermonId.isAcceptableOrUnknown(data['sermon_id']!, _sermonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sermonIdMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    } else if (isInserting) {
      context.missing(_topicMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sermonId, topic};
  @override
  SermonTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SermonTopic(
      sermonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sermon_id'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      )!,
    );
  }

  @override
  $SermonTopicsTable createAlias(String alias) {
    return $SermonTopicsTable(attachedDatabase, alias);
  }
}

class SermonTopic extends DataClass implements Insertable<SermonTopic> {
  final String sermonId;
  final String topic;
  const SermonTopic({required this.sermonId, required this.topic});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sermon_id'] = Variable<String>(sermonId);
    map['topic'] = Variable<String>(topic);
    return map;
  }

  SermonTopicsCompanion toCompanion(bool nullToAbsent) {
    return SermonTopicsCompanion(
      sermonId: Value(sermonId),
      topic: Value(topic),
    );
  }

  factory SermonTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SermonTopic(
      sermonId: serializer.fromJson<String>(json['sermonId']),
      topic: serializer.fromJson<String>(json['topic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sermonId': serializer.toJson<String>(sermonId),
      'topic': serializer.toJson<String>(topic),
    };
  }

  SermonTopic copyWith({String? sermonId, String? topic}) => SermonTopic(
    sermonId: sermonId ?? this.sermonId,
    topic: topic ?? this.topic,
  );
  SermonTopic copyWithCompanion(SermonTopicsCompanion data) {
    return SermonTopic(
      sermonId: data.sermonId.present ? data.sermonId.value : this.sermonId,
      topic: data.topic.present ? data.topic.value : this.topic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SermonTopic(')
          ..write('sermonId: $sermonId, ')
          ..write('topic: $topic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sermonId, topic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SermonTopic &&
          other.sermonId == this.sermonId &&
          other.topic == this.topic);
}

class SermonTopicsCompanion extends UpdateCompanion<SermonTopic> {
  final Value<String> sermonId;
  final Value<String> topic;
  final Value<int> rowid;
  const SermonTopicsCompanion({
    this.sermonId = const Value.absent(),
    this.topic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SermonTopicsCompanion.insert({
    required String sermonId,
    required String topic,
    this.rowid = const Value.absent(),
  }) : sermonId = Value(sermonId),
       topic = Value(topic);
  static Insertable<SermonTopic> custom({
    Expression<String>? sermonId,
    Expression<String>? topic,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sermonId != null) 'sermon_id': sermonId,
      if (topic != null) 'topic': topic,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SermonTopicsCompanion copyWith({
    Value<String>? sermonId,
    Value<String>? topic,
    Value<int>? rowid,
  }) {
    return SermonTopicsCompanion(
      sermonId: sermonId ?? this.sermonId,
      topic: topic ?? this.topic,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sermonId.present) {
      map['sermon_id'] = Variable<String>(sermonId.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SermonTopicsCompanion(')
          ..write('sermonId: $sermonId, ')
          ..write('topic: $topic, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SermonTagsTable extends SermonTags
    with TableInfo<$SermonTagsTable, SermonTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SermonTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sermonIdMeta = const VerificationMeta(
    'sermonId',
  );
  @override
  late final GeneratedColumn<String> sermonId = GeneratedColumn<String>(
    'sermon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sermons (id)',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sermonId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sermon_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<SermonTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sermon_id')) {
      context.handle(
        _sermonIdMeta,
        sermonId.isAcceptableOrUnknown(data['sermon_id']!, _sermonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sermonIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sermonId, tag};
  @override
  SermonTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SermonTag(
      sermonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sermon_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $SermonTagsTable createAlias(String alias) {
    return $SermonTagsTable(attachedDatabase, alias);
  }
}

class SermonTag extends DataClass implements Insertable<SermonTag> {
  final String sermonId;
  final String tag;
  const SermonTag({required this.sermonId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sermon_id'] = Variable<String>(sermonId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  SermonTagsCompanion toCompanion(bool nullToAbsent) {
    return SermonTagsCompanion(sermonId: Value(sermonId), tag: Value(tag));
  }

  factory SermonTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SermonTag(
      sermonId: serializer.fromJson<String>(json['sermonId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sermonId': serializer.toJson<String>(sermonId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  SermonTag copyWith({String? sermonId, String? tag}) =>
      SermonTag(sermonId: sermonId ?? this.sermonId, tag: tag ?? this.tag);
  SermonTag copyWithCompanion(SermonTagsCompanion data) {
    return SermonTag(
      sermonId: data.sermonId.present ? data.sermonId.value : this.sermonId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SermonTag(')
          ..write('sermonId: $sermonId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sermonId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SermonTag &&
          other.sermonId == this.sermonId &&
          other.tag == this.tag);
}

class SermonTagsCompanion extends UpdateCompanion<SermonTag> {
  final Value<String> sermonId;
  final Value<String> tag;
  final Value<int> rowid;
  const SermonTagsCompanion({
    this.sermonId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SermonTagsCompanion.insert({
    required String sermonId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : sermonId = Value(sermonId),
       tag = Value(tag);
  static Insertable<SermonTag> custom({
    Expression<String>? sermonId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sermonId != null) 'sermon_id': sermonId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SermonTagsCompanion copyWith({
    Value<String>? sermonId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return SermonTagsCompanion(
      sermonId: sermonId ?? this.sermonId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sermonId.present) {
      map['sermon_id'] = Variable<String>(sermonId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SermonTagsCompanion(')
          ..write('sermonId: $sermonId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SermonPreachedDatesTable extends SermonPreachedDates
    with TableInfo<$SermonPreachedDatesTable, SermonPreachedDate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SermonPreachedDatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sermonIdMeta = const VerificationMeta(
    'sermonId',
  );
  @override
  late final GeneratedColumn<String> sermonId = GeneratedColumn<String>(
    'sermon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sermons (id)',
    ),
  );
  static const VerificationMeta _preachedAtMeta = const VerificationMeta(
    'preachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> preachedAt = GeneratedColumn<DateTime>(
    'preached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sermonId, preachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sermon_preached_dates';
  @override
  VerificationContext validateIntegrity(
    Insertable<SermonPreachedDate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sermon_id')) {
      context.handle(
        _sermonIdMeta,
        sermonId.isAcceptableOrUnknown(data['sermon_id']!, _sermonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sermonIdMeta);
    }
    if (data.containsKey('preached_at')) {
      context.handle(
        _preachedAtMeta,
        preachedAt.isAcceptableOrUnknown(data['preached_at']!, _preachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_preachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SermonPreachedDate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SermonPreachedDate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sermonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sermon_id'],
      )!,
      preachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}preached_at'],
      )!,
    );
  }

  @override
  $SermonPreachedDatesTable createAlias(String alias) {
    return $SermonPreachedDatesTable(attachedDatabase, alias);
  }
}

class SermonPreachedDate extends DataClass
    implements Insertable<SermonPreachedDate> {
  final int id;
  final String sermonId;
  final DateTime preachedAt;
  const SermonPreachedDate({
    required this.id,
    required this.sermonId,
    required this.preachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sermon_id'] = Variable<String>(sermonId);
    map['preached_at'] = Variable<DateTime>(preachedAt);
    return map;
  }

  SermonPreachedDatesCompanion toCompanion(bool nullToAbsent) {
    return SermonPreachedDatesCompanion(
      id: Value(id),
      sermonId: Value(sermonId),
      preachedAt: Value(preachedAt),
    );
  }

  factory SermonPreachedDate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SermonPreachedDate(
      id: serializer.fromJson<int>(json['id']),
      sermonId: serializer.fromJson<String>(json['sermonId']),
      preachedAt: serializer.fromJson<DateTime>(json['preachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sermonId': serializer.toJson<String>(sermonId),
      'preachedAt': serializer.toJson<DateTime>(preachedAt),
    };
  }

  SermonPreachedDate copyWith({
    int? id,
    String? sermonId,
    DateTime? preachedAt,
  }) => SermonPreachedDate(
    id: id ?? this.id,
    sermonId: sermonId ?? this.sermonId,
    preachedAt: preachedAt ?? this.preachedAt,
  );
  SermonPreachedDate copyWithCompanion(SermonPreachedDatesCompanion data) {
    return SermonPreachedDate(
      id: data.id.present ? data.id.value : this.id,
      sermonId: data.sermonId.present ? data.sermonId.value : this.sermonId,
      preachedAt: data.preachedAt.present
          ? data.preachedAt.value
          : this.preachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SermonPreachedDate(')
          ..write('id: $id, ')
          ..write('sermonId: $sermonId, ')
          ..write('preachedAt: $preachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sermonId, preachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SermonPreachedDate &&
          other.id == this.id &&
          other.sermonId == this.sermonId &&
          other.preachedAt == this.preachedAt);
}

class SermonPreachedDatesCompanion extends UpdateCompanion<SermonPreachedDate> {
  final Value<int> id;
  final Value<String> sermonId;
  final Value<DateTime> preachedAt;
  const SermonPreachedDatesCompanion({
    this.id = const Value.absent(),
    this.sermonId = const Value.absent(),
    this.preachedAt = const Value.absent(),
  });
  SermonPreachedDatesCompanion.insert({
    this.id = const Value.absent(),
    required String sermonId,
    required DateTime preachedAt,
  }) : sermonId = Value(sermonId),
       preachedAt = Value(preachedAt);
  static Insertable<SermonPreachedDate> custom({
    Expression<int>? id,
    Expression<String>? sermonId,
    Expression<DateTime>? preachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sermonId != null) 'sermon_id': sermonId,
      if (preachedAt != null) 'preached_at': preachedAt,
    });
  }

  SermonPreachedDatesCompanion copyWith({
    Value<int>? id,
    Value<String>? sermonId,
    Value<DateTime>? preachedAt,
  }) {
    return SermonPreachedDatesCompanion(
      id: id ?? this.id,
      sermonId: sermonId ?? this.sermonId,
      preachedAt: preachedAt ?? this.preachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sermonId.present) {
      map['sermon_id'] = Variable<String>(sermonId.value);
    }
    if (preachedAt.present) {
      map['preached_at'] = Variable<DateTime>(preachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SermonPreachedDatesCompanion(')
          ..write('id: $id, ')
          ..write('sermonId: $sermonId, ')
          ..write('preachedAt: $preachedAt')
          ..write(')'))
        .toString();
  }
}

class $DocumentVersionsTable extends DocumentVersions
    with TableInfo<$DocumentVersionsTable, DocumentVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sermonIdMeta = const VerificationMeta(
    'sermonId',
  );
  @override
  late final GeneratedColumn<String> sermonId = GeneratedColumn<String>(
    'sermon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sermons (id)',
    ),
  );
  static const VerificationMeta _documentSchemaVersionMeta =
      const VerificationMeta('documentSchemaVersion');
  @override
  late final GeneratedColumn<int> documentSchemaVersion = GeneratedColumn<int>(
    'document_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentJsonMeta = const VerificationMeta(
    'documentJson',
  );
  @override
  late final GeneratedColumn<String> documentJson = GeneratedColumn<String>(
    'document_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sermonId,
    documentSchemaVersion,
    documentJson,
    reason,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sermon_id')) {
      context.handle(
        _sermonIdMeta,
        sermonId.isAcceptableOrUnknown(data['sermon_id']!, _sermonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sermonIdMeta);
    }
    if (data.containsKey('document_schema_version')) {
      context.handle(
        _documentSchemaVersionMeta,
        documentSchemaVersion.isAcceptableOrUnknown(
          data['document_schema_version']!,
          _documentSchemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentSchemaVersionMeta);
    }
    if (data.containsKey('document_json')) {
      context.handle(
        _documentJsonMeta,
        documentJson.isAcceptableOrUnknown(
          data['document_json']!,
          _documentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentJsonMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentVersion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sermonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sermon_id'],
      )!,
      documentSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}document_schema_version'],
      )!,
      documentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_json'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DocumentVersionsTable createAlias(String alias) {
    return $DocumentVersionsTable(attachedDatabase, alias);
  }
}

class DocumentVersion extends DataClass implements Insertable<DocumentVersion> {
  final int id;
  final String sermonId;
  final int documentSchemaVersion;
  final String documentJson;
  final String reason;
  final DateTime createdAt;
  const DocumentVersion({
    required this.id,
    required this.sermonId,
    required this.documentSchemaVersion,
    required this.documentJson,
    required this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sermon_id'] = Variable<String>(sermonId);
    map['document_schema_version'] = Variable<int>(documentSchemaVersion);
    map['document_json'] = Variable<String>(documentJson);
    map['reason'] = Variable<String>(reason);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DocumentVersionsCompanion toCompanion(bool nullToAbsent) {
    return DocumentVersionsCompanion(
      id: Value(id),
      sermonId: Value(sermonId),
      documentSchemaVersion: Value(documentSchemaVersion),
      documentJson: Value(documentJson),
      reason: Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory DocumentVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentVersion(
      id: serializer.fromJson<int>(json['id']),
      sermonId: serializer.fromJson<String>(json['sermonId']),
      documentSchemaVersion: serializer.fromJson<int>(
        json['documentSchemaVersion'],
      ),
      documentJson: serializer.fromJson<String>(json['documentJson']),
      reason: serializer.fromJson<String>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sermonId': serializer.toJson<String>(sermonId),
      'documentSchemaVersion': serializer.toJson<int>(documentSchemaVersion),
      'documentJson': serializer.toJson<String>(documentJson),
      'reason': serializer.toJson<String>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DocumentVersion copyWith({
    int? id,
    String? sermonId,
    int? documentSchemaVersion,
    String? documentJson,
    String? reason,
    DateTime? createdAt,
  }) => DocumentVersion(
    id: id ?? this.id,
    sermonId: sermonId ?? this.sermonId,
    documentSchemaVersion: documentSchemaVersion ?? this.documentSchemaVersion,
    documentJson: documentJson ?? this.documentJson,
    reason: reason ?? this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  DocumentVersion copyWithCompanion(DocumentVersionsCompanion data) {
    return DocumentVersion(
      id: data.id.present ? data.id.value : this.id,
      sermonId: data.sermonId.present ? data.sermonId.value : this.sermonId,
      documentSchemaVersion: data.documentSchemaVersion.present
          ? data.documentSchemaVersion.value
          : this.documentSchemaVersion,
      documentJson: data.documentJson.present
          ? data.documentJson.value
          : this.documentJson,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentVersion(')
          ..write('id: $id, ')
          ..write('sermonId: $sermonId, ')
          ..write('documentSchemaVersion: $documentSchemaVersion, ')
          ..write('documentJson: $documentJson, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sermonId,
    documentSchemaVersion,
    documentJson,
    reason,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentVersion &&
          other.id == this.id &&
          other.sermonId == this.sermonId &&
          other.documentSchemaVersion == this.documentSchemaVersion &&
          other.documentJson == this.documentJson &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class DocumentVersionsCompanion extends UpdateCompanion<DocumentVersion> {
  final Value<int> id;
  final Value<String> sermonId;
  final Value<int> documentSchemaVersion;
  final Value<String> documentJson;
  final Value<String> reason;
  final Value<DateTime> createdAt;
  const DocumentVersionsCompanion({
    this.id = const Value.absent(),
    this.sermonId = const Value.absent(),
    this.documentSchemaVersion = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DocumentVersionsCompanion.insert({
    this.id = const Value.absent(),
    required String sermonId,
    required int documentSchemaVersion,
    required String documentJson,
    required String reason,
    required DateTime createdAt,
  }) : sermonId = Value(sermonId),
       documentSchemaVersion = Value(documentSchemaVersion),
       documentJson = Value(documentJson),
       reason = Value(reason),
       createdAt = Value(createdAt);
  static Insertable<DocumentVersion> custom({
    Expression<int>? id,
    Expression<String>? sermonId,
    Expression<int>? documentSchemaVersion,
    Expression<String>? documentJson,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sermonId != null) 'sermon_id': sermonId,
      if (documentSchemaVersion != null)
        'document_schema_version': documentSchemaVersion,
      if (documentJson != null) 'document_json': documentJson,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DocumentVersionsCompanion copyWith({
    Value<int>? id,
    Value<String>? sermonId,
    Value<int>? documentSchemaVersion,
    Value<String>? documentJson,
    Value<String>? reason,
    Value<DateTime>? createdAt,
  }) {
    return DocumentVersionsCompanion(
      id: id ?? this.id,
      sermonId: sermonId ?? this.sermonId,
      documentSchemaVersion:
          documentSchemaVersion ?? this.documentSchemaVersion,
      documentJson: documentJson ?? this.documentJson,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sermonId.present) {
      map['sermon_id'] = Variable<String>(sermonId.value);
    }
    if (documentSchemaVersion.present) {
      map['document_schema_version'] = Variable<int>(
        documentSchemaVersion.value,
      );
    }
    if (documentJson.present) {
      map['document_json'] = Variable<String>(documentJson.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentVersionsCompanion(')
          ..write('id: $id, ')
          ..write('sermonId: $sermonId, ')
          ..write('documentSchemaVersion: $documentSchemaVersion, ')
          ..write('documentJson: $documentJson, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String valueJson;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? valueJson, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        valueJson: valueJson ?? this.valueJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String valueJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SermonRowsTable sermonRows = $SermonRowsTable(this);
  late final $SermonSeriesRowsTable sermonSeriesRows = $SermonSeriesRowsTable(
    this,
  );
  late final $SermonTopicsTable sermonTopics = $SermonTopicsTable(this);
  late final $SermonTagsTable sermonTags = $SermonTagsTable(this);
  late final $SermonPreachedDatesTable sermonPreachedDates =
      $SermonPreachedDatesTable(this);
  late final $DocumentVersionsTable documentVersions = $DocumentVersionsTable(
    this,
  );
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sermonRows,
    sermonSeriesRows,
    sermonTopics,
    sermonTags,
    sermonPreachedDates,
    documentVersions,
    appSettings,
  ];
}

typedef $$SermonRowsTableCreateCompanionBuilder =
    SermonRowsCompanion Function({
      required String id,
      required int schemaVersion,
      required String title,
      Value<String> subtitle,
      required String status,
      required String sermonType,
      Value<String> contentKind,
      Value<String?> primaryBibleReferenceJson,
      Value<String> additionalBibleReferencesJson,
      required String documentJson,
      Value<String> documentPlainText,
      Value<String?> seriesId,
      Value<int?> seriesPosition,
      Value<String> topicsJson,
      Value<String> tagsJson,
      Value<String?> audience,
      Value<String?> location,
      Value<DateTime?> scheduledAt,
      Value<String> preachedDatesJson,
      Value<int?> plannedDurationMinutes,
      Value<int?> actualDurationMinutes,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime lastOpenedAt,
      Value<bool> isFavorite,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$SermonRowsTableUpdateCompanionBuilder =
    SermonRowsCompanion Function({
      Value<String> id,
      Value<int> schemaVersion,
      Value<String> title,
      Value<String> subtitle,
      Value<String> status,
      Value<String> sermonType,
      Value<String> contentKind,
      Value<String?> primaryBibleReferenceJson,
      Value<String> additionalBibleReferencesJson,
      Value<String> documentJson,
      Value<String> documentPlainText,
      Value<String?> seriesId,
      Value<int?> seriesPosition,
      Value<String> topicsJson,
      Value<String> tagsJson,
      Value<String?> audience,
      Value<String?> location,
      Value<DateTime?> scheduledAt,
      Value<String> preachedDatesJson,
      Value<int?> plannedDurationMinutes,
      Value<int?> actualDurationMinutes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime> lastOpenedAt,
      Value<bool> isFavorite,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$SermonRowsTableReferences
    extends BaseReferences<_$AppDatabase, $SermonRowsTable, SermonRow> {
  $$SermonRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SermonTopicsTable, List<SermonTopic>>
  _sermonTopicsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sermonTopics,
    aliasName: 'sermons__id__sermon_topics__sermon_id',
  );

  $$SermonTopicsTableProcessedTableManager get sermonTopicsRefs {
    final manager = $$SermonTopicsTableTableManager(
      $_db,
      $_db.sermonTopics,
    ).filter((f) => f.sermonId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sermonTopicsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SermonTagsTable, List<SermonTag>>
  _sermonTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sermonTags,
    aliasName: 'sermons__id__sermon_tags__sermon_id',
  );

  $$SermonTagsTableProcessedTableManager get sermonTagsRefs {
    final manager = $$SermonTagsTableTableManager(
      $_db,
      $_db.sermonTags,
    ).filter((f) => f.sermonId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sermonTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SermonPreachedDatesTable,
    List<SermonPreachedDate>
  >
  _sermonPreachedDatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sermonPreachedDates,
        aliasName: 'sermons__id__sermon_preached_dates__sermon_id',
      );

  $$SermonPreachedDatesTableProcessedTableManager get sermonPreachedDatesRefs {
    final manager = $$SermonPreachedDatesTableTableManager(
      $_db,
      $_db.sermonPreachedDates,
    ).filter((f) => f.sermonId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sermonPreachedDatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentVersionsTable, List<DocumentVersion>>
  _documentVersionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documentVersions,
    aliasName: 'sermons__id__document_versions__sermon_id',
  );

  $$DocumentVersionsTableProcessedTableManager get documentVersionsRefs {
    final manager = $$DocumentVersionsTableTableManager(
      $_db,
      $_db.documentVersions,
    ).filter((f) => f.sermonId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _documentVersionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SermonRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SermonRowsTable> {
  $$SermonRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sermonType => $composableBuilder(
    column: $table.sermonType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentKind => $composableBuilder(
    column: $table.contentKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryBibleReferenceJson => $composableBuilder(
    column: $table.primaryBibleReferenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get additionalBibleReferencesJson => $composableBuilder(
    column: $table.additionalBibleReferencesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentPlainText => $composableBuilder(
    column: $table.documentPlainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seriesPosition => $composableBuilder(
    column: $table.seriesPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicsJson => $composableBuilder(
    column: $table.topicsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audience => $composableBuilder(
    column: $table.audience,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preachedDatesJson => $composableBuilder(
    column: $table.preachedDatesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedDurationMinutes => $composableBuilder(
    column: $table.plannedDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualDurationMinutes => $composableBuilder(
    column: $table.actualDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sermonTopicsRefs(
    Expression<bool> Function($$SermonTopicsTableFilterComposer f) f,
  ) {
    final $$SermonTopicsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sermonTopics,
      getReferencedColumn: (t) => t.sermonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonTopicsTableFilterComposer(
            $db: $db,
            $table: $db.sermonTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sermonTagsRefs(
    Expression<bool> Function($$SermonTagsTableFilterComposer f) f,
  ) {
    final $$SermonTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sermonTags,
      getReferencedColumn: (t) => t.sermonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonTagsTableFilterComposer(
            $db: $db,
            $table: $db.sermonTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sermonPreachedDatesRefs(
    Expression<bool> Function($$SermonPreachedDatesTableFilterComposer f) f,
  ) {
    final $$SermonPreachedDatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sermonPreachedDates,
      getReferencedColumn: (t) => t.sermonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonPreachedDatesTableFilterComposer(
            $db: $db,
            $table: $db.sermonPreachedDates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> documentVersionsRefs(
    Expression<bool> Function($$DocumentVersionsTableFilterComposer f) f,
  ) {
    final $$DocumentVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentVersions,
      getReferencedColumn: (t) => t.sermonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentVersionsTableFilterComposer(
            $db: $db,
            $table: $db.documentVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SermonRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SermonRowsTable> {
  $$SermonRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sermonType => $composableBuilder(
    column: $table.sermonType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentKind => $composableBuilder(
    column: $table.contentKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryBibleReferenceJson => $composableBuilder(
    column: $table.primaryBibleReferenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get additionalBibleReferencesJson =>
      $composableBuilder(
        column: $table.additionalBibleReferencesJson,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentPlainText => $composableBuilder(
    column: $table.documentPlainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesPosition => $composableBuilder(
    column: $table.seriesPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicsJson => $composableBuilder(
    column: $table.topicsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audience => $composableBuilder(
    column: $table.audience,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preachedDatesJson => $composableBuilder(
    column: $table.preachedDatesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedDurationMinutes => $composableBuilder(
    column: $table.plannedDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualDurationMinutes => $composableBuilder(
    column: $table.actualDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SermonRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SermonRowsTable> {
  $$SermonRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get sermonType => $composableBuilder(
    column: $table.sermonType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentKind => $composableBuilder(
    column: $table.contentKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryBibleReferenceJson => $composableBuilder(
    column: $table.primaryBibleReferenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get additionalBibleReferencesJson =>
      $composableBuilder(
        column: $table.additionalBibleReferencesJson,
        builder: (column) => column,
      );

  GeneratedColumn<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentPlainText => $composableBuilder(
    column: $table.documentPlainText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get seriesPosition => $composableBuilder(
    column: $table.seriesPosition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topicsJson => $composableBuilder(
    column: $table.topicsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get audience =>
      $composableBuilder(column: $table.audience, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preachedDatesJson => $composableBuilder(
    column: $table.preachedDatesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedDurationMinutes => $composableBuilder(
    column: $table.plannedDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualDurationMinutes => $composableBuilder(
    column: $table.actualDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  Expression<T> sermonTopicsRefs<T extends Object>(
    Expression<T> Function($$SermonTopicsTableAnnotationComposer a) f,
  ) {
    final $$SermonTopicsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sermonTopics,
      getReferencedColumn: (t) => t.sermonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonTopicsTableAnnotationComposer(
            $db: $db,
            $table: $db.sermonTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sermonTagsRefs<T extends Object>(
    Expression<T> Function($$SermonTagsTableAnnotationComposer a) f,
  ) {
    final $$SermonTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sermonTags,
      getReferencedColumn: (t) => t.sermonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.sermonTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sermonPreachedDatesRefs<T extends Object>(
    Expression<T> Function($$SermonPreachedDatesTableAnnotationComposer a) f,
  ) {
    final $$SermonPreachedDatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.sermonPreachedDates,
          getReferencedColumn: (t) => t.sermonId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SermonPreachedDatesTableAnnotationComposer(
                $db: $db,
                $table: $db.sermonPreachedDates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> documentVersionsRefs<T extends Object>(
    Expression<T> Function($$DocumentVersionsTableAnnotationComposer a) f,
  ) {
    final $$DocumentVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentVersions,
      getReferencedColumn: (t) => t.sermonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.documentVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SermonRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SermonRowsTable,
          SermonRow,
          $$SermonRowsTableFilterComposer,
          $$SermonRowsTableOrderingComposer,
          $$SermonRowsTableAnnotationComposer,
          $$SermonRowsTableCreateCompanionBuilder,
          $$SermonRowsTableUpdateCompanionBuilder,
          (SermonRow, $$SermonRowsTableReferences),
          SermonRow,
          PrefetchHooks Function({
            bool sermonTopicsRefs,
            bool sermonTagsRefs,
            bool sermonPreachedDatesRefs,
            bool documentVersionsRefs,
          })
        > {
  $$SermonRowsTableTableManager(_$AppDatabase db, $SermonRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SermonRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SermonRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SermonRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> sermonType = const Value.absent(),
                Value<String> contentKind = const Value.absent(),
                Value<String?> primaryBibleReferenceJson = const Value.absent(),
                Value<String> additionalBibleReferencesJson =
                    const Value.absent(),
                Value<String> documentJson = const Value.absent(),
                Value<String> documentPlainText = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<int?> seriesPosition = const Value.absent(),
                Value<String> topicsJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> audience = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<DateTime?> scheduledAt = const Value.absent(),
                Value<String> preachedDatesJson = const Value.absent(),
                Value<int?> plannedDurationMinutes = const Value.absent(),
                Value<int?> actualDurationMinutes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SermonRowsCompanion(
                id: id,
                schemaVersion: schemaVersion,
                title: title,
                subtitle: subtitle,
                status: status,
                sermonType: sermonType,
                contentKind: contentKind,
                primaryBibleReferenceJson: primaryBibleReferenceJson,
                additionalBibleReferencesJson: additionalBibleReferencesJson,
                documentJson: documentJson,
                documentPlainText: documentPlainText,
                seriesId: seriesId,
                seriesPosition: seriesPosition,
                topicsJson: topicsJson,
                tagsJson: tagsJson,
                audience: audience,
                location: location,
                scheduledAt: scheduledAt,
                preachedDatesJson: preachedDatesJson,
                plannedDurationMinutes: plannedDurationMinutes,
                actualDurationMinutes: actualDurationMinutes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                isFavorite: isFavorite,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int schemaVersion,
                required String title,
                Value<String> subtitle = const Value.absent(),
                required String status,
                required String sermonType,
                Value<String> contentKind = const Value.absent(),
                Value<String?> primaryBibleReferenceJson = const Value.absent(),
                Value<String> additionalBibleReferencesJson =
                    const Value.absent(),
                required String documentJson,
                Value<String> documentPlainText = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<int?> seriesPosition = const Value.absent(),
                Value<String> topicsJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> audience = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<DateTime?> scheduledAt = const Value.absent(),
                Value<String> preachedDatesJson = const Value.absent(),
                Value<int?> plannedDurationMinutes = const Value.absent(),
                Value<int?> actualDurationMinutes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                required DateTime lastOpenedAt,
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SermonRowsCompanion.insert(
                id: id,
                schemaVersion: schemaVersion,
                title: title,
                subtitle: subtitle,
                status: status,
                sermonType: sermonType,
                contentKind: contentKind,
                primaryBibleReferenceJson: primaryBibleReferenceJson,
                additionalBibleReferencesJson: additionalBibleReferencesJson,
                documentJson: documentJson,
                documentPlainText: documentPlainText,
                seriesId: seriesId,
                seriesPosition: seriesPosition,
                topicsJson: topicsJson,
                tagsJson: tagsJson,
                audience: audience,
                location: location,
                scheduledAt: scheduledAt,
                preachedDatesJson: preachedDatesJson,
                plannedDurationMinutes: plannedDurationMinutes,
                actualDurationMinutes: actualDurationMinutes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                isFavorite: isFavorite,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SermonRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sermonTopicsRefs = false,
                sermonTagsRefs = false,
                sermonPreachedDatesRefs = false,
                documentVersionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sermonTopicsRefs) db.sermonTopics,
                    if (sermonTagsRefs) db.sermonTags,
                    if (sermonPreachedDatesRefs) db.sermonPreachedDates,
                    if (documentVersionsRefs) db.documentVersions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sermonTopicsRefs)
                        await $_getPrefetchedData<
                          SermonRow,
                          $SermonRowsTable,
                          SermonTopic
                        >(
                          currentTable: table,
                          referencedTable: $$SermonRowsTableReferences
                              ._sermonTopicsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SermonRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).sermonTopicsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sermonId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sermonTagsRefs)
                        await $_getPrefetchedData<
                          SermonRow,
                          $SermonRowsTable,
                          SermonTag
                        >(
                          currentTable: table,
                          referencedTable: $$SermonRowsTableReferences
                              ._sermonTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SermonRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).sermonTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sermonId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sermonPreachedDatesRefs)
                        await $_getPrefetchedData<
                          SermonRow,
                          $SermonRowsTable,
                          SermonPreachedDate
                        >(
                          currentTable: table,
                          referencedTable: $$SermonRowsTableReferences
                              ._sermonPreachedDatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SermonRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).sermonPreachedDatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sermonId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentVersionsRefs)
                        await $_getPrefetchedData<
                          SermonRow,
                          $SermonRowsTable,
                          DocumentVersion
                        >(
                          currentTable: table,
                          referencedTable: $$SermonRowsTableReferences
                              ._documentVersionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SermonRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentVersionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sermonId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SermonRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SermonRowsTable,
      SermonRow,
      $$SermonRowsTableFilterComposer,
      $$SermonRowsTableOrderingComposer,
      $$SermonRowsTableAnnotationComposer,
      $$SermonRowsTableCreateCompanionBuilder,
      $$SermonRowsTableUpdateCompanionBuilder,
      (SermonRow, $$SermonRowsTableReferences),
      SermonRow,
      PrefetchHooks Function({
        bool sermonTopicsRefs,
        bool sermonTagsRefs,
        bool sermonPreachedDatesRefs,
        bool documentVersionsRefs,
      })
    >;
typedef $$SermonSeriesRowsTableCreateCompanionBuilder =
    SermonSeriesRowsCompanion Function({
      required String id,
      required String title,
      Value<String> description,
      Value<String?> primaryBibleBook,
      Value<String> colorToken,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isArchived,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$SermonSeriesRowsTableUpdateCompanionBuilder =
    SermonSeriesRowsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> description,
      Value<String?> primaryBibleBook,
      Value<String> colorToken,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isArchived,
      Value<int> revision,
      Value<int> rowid,
    });

class $$SermonSeriesRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SermonSeriesRowsTable> {
  $$SermonSeriesRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryBibleBook => $composableBuilder(
    column: $table.primaryBibleBook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SermonSeriesRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SermonSeriesRowsTable> {
  $$SermonSeriesRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryBibleBook => $composableBuilder(
    column: $table.primaryBibleBook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SermonSeriesRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SermonSeriesRowsTable> {
  $$SermonSeriesRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryBibleBook => $composableBuilder(
    column: $table.primaryBibleBook,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$SermonSeriesRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SermonSeriesRowsTable,
          SermonSeriesRow,
          $$SermonSeriesRowsTableFilterComposer,
          $$SermonSeriesRowsTableOrderingComposer,
          $$SermonSeriesRowsTableAnnotationComposer,
          $$SermonSeriesRowsTableCreateCompanionBuilder,
          $$SermonSeriesRowsTableUpdateCompanionBuilder,
          (
            SermonSeriesRow,
            BaseReferences<
              _$AppDatabase,
              $SermonSeriesRowsTable,
              SermonSeriesRow
            >,
          ),
          SermonSeriesRow,
          PrefetchHooks Function()
        > {
  $$SermonSeriesRowsTableTableManager(
    _$AppDatabase db,
    $SermonSeriesRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SermonSeriesRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SermonSeriesRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SermonSeriesRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> primaryBibleBook = const Value.absent(),
                Value<String> colorToken = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SermonSeriesRowsCompanion(
                id: id,
                title: title,
                description: description,
                primaryBibleBook: primaryBibleBook,
                colorToken: colorToken,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: isArchived,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> description = const Value.absent(),
                Value<String?> primaryBibleBook = const Value.absent(),
                Value<String> colorToken = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> isArchived = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SermonSeriesRowsCompanion.insert(
                id: id,
                title: title,
                description: description,
                primaryBibleBook: primaryBibleBook,
                colorToken: colorToken,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: isArchived,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SermonSeriesRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SermonSeriesRowsTable,
      SermonSeriesRow,
      $$SermonSeriesRowsTableFilterComposer,
      $$SermonSeriesRowsTableOrderingComposer,
      $$SermonSeriesRowsTableAnnotationComposer,
      $$SermonSeriesRowsTableCreateCompanionBuilder,
      $$SermonSeriesRowsTableUpdateCompanionBuilder,
      (
        SermonSeriesRow,
        BaseReferences<_$AppDatabase, $SermonSeriesRowsTable, SermonSeriesRow>,
      ),
      SermonSeriesRow,
      PrefetchHooks Function()
    >;
typedef $$SermonTopicsTableCreateCompanionBuilder =
    SermonTopicsCompanion Function({
      required String sermonId,
      required String topic,
      Value<int> rowid,
    });
typedef $$SermonTopicsTableUpdateCompanionBuilder =
    SermonTopicsCompanion Function({
      Value<String> sermonId,
      Value<String> topic,
      Value<int> rowid,
    });

final class $$SermonTopicsTableReferences
    extends BaseReferences<_$AppDatabase, $SermonTopicsTable, SermonTopic> {
  $$SermonTopicsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SermonRowsTable _sermonIdTable(_$AppDatabase db) =>
      db.sermonRows.createAlias('sermon_topics__sermon_id__sermons__id');

  $$SermonRowsTableProcessedTableManager get sermonId {
    final $_column = $_itemColumn<String>('sermon_id')!;

    final manager = $$SermonRowsTableTableManager(
      $_db,
      $_db.sermonRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sermonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SermonTopicsTableFilterComposer
    extends Composer<_$AppDatabase, $SermonTopicsTable> {
  $$SermonTopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  $$SermonRowsTableFilterComposer get sermonId {
    final $$SermonRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableFilterComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonTopicsTableOrderingComposer
    extends Composer<_$AppDatabase, $SermonTopicsTable> {
  $$SermonTopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  $$SermonRowsTableOrderingComposer get sermonId {
    final $$SermonRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableOrderingComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonTopicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SermonTopicsTable> {
  $$SermonTopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  $$SermonRowsTableAnnotationComposer get sermonId {
    final $$SermonRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonTopicsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SermonTopicsTable,
          SermonTopic,
          $$SermonTopicsTableFilterComposer,
          $$SermonTopicsTableOrderingComposer,
          $$SermonTopicsTableAnnotationComposer,
          $$SermonTopicsTableCreateCompanionBuilder,
          $$SermonTopicsTableUpdateCompanionBuilder,
          (SermonTopic, $$SermonTopicsTableReferences),
          SermonTopic,
          PrefetchHooks Function({bool sermonId})
        > {
  $$SermonTopicsTableTableManager(_$AppDatabase db, $SermonTopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SermonTopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SermonTopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SermonTopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sermonId = const Value.absent(),
                Value<String> topic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SermonTopicsCompanion(
                sermonId: sermonId,
                topic: topic,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sermonId,
                required String topic,
                Value<int> rowid = const Value.absent(),
              }) => SermonTopicsCompanion.insert(
                sermonId: sermonId,
                topic: topic,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SermonTopicsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sermonId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sermonId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sermonId,
                                referencedTable: $$SermonTopicsTableReferences
                                    ._sermonIdTable(db),
                                referencedColumn: $$SermonTopicsTableReferences
                                    ._sermonIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SermonTopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SermonTopicsTable,
      SermonTopic,
      $$SermonTopicsTableFilterComposer,
      $$SermonTopicsTableOrderingComposer,
      $$SermonTopicsTableAnnotationComposer,
      $$SermonTopicsTableCreateCompanionBuilder,
      $$SermonTopicsTableUpdateCompanionBuilder,
      (SermonTopic, $$SermonTopicsTableReferences),
      SermonTopic,
      PrefetchHooks Function({bool sermonId})
    >;
typedef $$SermonTagsTableCreateCompanionBuilder =
    SermonTagsCompanion Function({
      required String sermonId,
      required String tag,
      Value<int> rowid,
    });
typedef $$SermonTagsTableUpdateCompanionBuilder =
    SermonTagsCompanion Function({
      Value<String> sermonId,
      Value<String> tag,
      Value<int> rowid,
    });

final class $$SermonTagsTableReferences
    extends BaseReferences<_$AppDatabase, $SermonTagsTable, SermonTag> {
  $$SermonTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SermonRowsTable _sermonIdTable(_$AppDatabase db) =>
      db.sermonRows.createAlias('sermon_tags__sermon_id__sermons__id');

  $$SermonRowsTableProcessedTableManager get sermonId {
    final $_column = $_itemColumn<String>('sermon_id')!;

    final manager = $$SermonRowsTableTableManager(
      $_db,
      $_db.sermonRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sermonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SermonTagsTableFilterComposer
    extends Composer<_$AppDatabase, $SermonTagsTable> {
  $$SermonTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$SermonRowsTableFilterComposer get sermonId {
    final $$SermonRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableFilterComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $SermonTagsTable> {
  $$SermonTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$SermonRowsTableOrderingComposer get sermonId {
    final $$SermonRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableOrderingComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SermonTagsTable> {
  $$SermonTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$SermonRowsTableAnnotationComposer get sermonId {
    final $$SermonRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SermonTagsTable,
          SermonTag,
          $$SermonTagsTableFilterComposer,
          $$SermonTagsTableOrderingComposer,
          $$SermonTagsTableAnnotationComposer,
          $$SermonTagsTableCreateCompanionBuilder,
          $$SermonTagsTableUpdateCompanionBuilder,
          (SermonTag, $$SermonTagsTableReferences),
          SermonTag,
          PrefetchHooks Function({bool sermonId})
        > {
  $$SermonTagsTableTableManager(_$AppDatabase db, $SermonTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SermonTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SermonTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SermonTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sermonId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SermonTagsCompanion(
                sermonId: sermonId,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sermonId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => SermonTagsCompanion.insert(
                sermonId: sermonId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SermonTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sermonId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sermonId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sermonId,
                                referencedTable: $$SermonTagsTableReferences
                                    ._sermonIdTable(db),
                                referencedColumn: $$SermonTagsTableReferences
                                    ._sermonIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SermonTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SermonTagsTable,
      SermonTag,
      $$SermonTagsTableFilterComposer,
      $$SermonTagsTableOrderingComposer,
      $$SermonTagsTableAnnotationComposer,
      $$SermonTagsTableCreateCompanionBuilder,
      $$SermonTagsTableUpdateCompanionBuilder,
      (SermonTag, $$SermonTagsTableReferences),
      SermonTag,
      PrefetchHooks Function({bool sermonId})
    >;
typedef $$SermonPreachedDatesTableCreateCompanionBuilder =
    SermonPreachedDatesCompanion Function({
      Value<int> id,
      required String sermonId,
      required DateTime preachedAt,
    });
typedef $$SermonPreachedDatesTableUpdateCompanionBuilder =
    SermonPreachedDatesCompanion Function({
      Value<int> id,
      Value<String> sermonId,
      Value<DateTime> preachedAt,
    });

final class $$SermonPreachedDatesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SermonPreachedDatesTable,
          SermonPreachedDate
        > {
  $$SermonPreachedDatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SermonRowsTable _sermonIdTable(_$AppDatabase db) => db.sermonRows
      .createAlias('sermon_preached_dates__sermon_id__sermons__id');

  $$SermonRowsTableProcessedTableManager get sermonId {
    final $_column = $_itemColumn<String>('sermon_id')!;

    final manager = $$SermonRowsTableTableManager(
      $_db,
      $_db.sermonRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sermonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SermonPreachedDatesTableFilterComposer
    extends Composer<_$AppDatabase, $SermonPreachedDatesTable> {
  $$SermonPreachedDatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get preachedAt => $composableBuilder(
    column: $table.preachedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SermonRowsTableFilterComposer get sermonId {
    final $$SermonRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableFilterComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonPreachedDatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SermonPreachedDatesTable> {
  $$SermonPreachedDatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get preachedAt => $composableBuilder(
    column: $table.preachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SermonRowsTableOrderingComposer get sermonId {
    final $$SermonRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableOrderingComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonPreachedDatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SermonPreachedDatesTable> {
  $$SermonPreachedDatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get preachedAt => $composableBuilder(
    column: $table.preachedAt,
    builder: (column) => column,
  );

  $$SermonRowsTableAnnotationComposer get sermonId {
    final $$SermonRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SermonPreachedDatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SermonPreachedDatesTable,
          SermonPreachedDate,
          $$SermonPreachedDatesTableFilterComposer,
          $$SermonPreachedDatesTableOrderingComposer,
          $$SermonPreachedDatesTableAnnotationComposer,
          $$SermonPreachedDatesTableCreateCompanionBuilder,
          $$SermonPreachedDatesTableUpdateCompanionBuilder,
          (SermonPreachedDate, $$SermonPreachedDatesTableReferences),
          SermonPreachedDate,
          PrefetchHooks Function({bool sermonId})
        > {
  $$SermonPreachedDatesTableTableManager(
    _$AppDatabase db,
    $SermonPreachedDatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SermonPreachedDatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SermonPreachedDatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SermonPreachedDatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sermonId = const Value.absent(),
                Value<DateTime> preachedAt = const Value.absent(),
              }) => SermonPreachedDatesCompanion(
                id: id,
                sermonId: sermonId,
                preachedAt: preachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sermonId,
                required DateTime preachedAt,
              }) => SermonPreachedDatesCompanion.insert(
                id: id,
                sermonId: sermonId,
                preachedAt: preachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SermonPreachedDatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sermonId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sermonId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sermonId,
                                referencedTable:
                                    $$SermonPreachedDatesTableReferences
                                        ._sermonIdTable(db),
                                referencedColumn:
                                    $$SermonPreachedDatesTableReferences
                                        ._sermonIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SermonPreachedDatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SermonPreachedDatesTable,
      SermonPreachedDate,
      $$SermonPreachedDatesTableFilterComposer,
      $$SermonPreachedDatesTableOrderingComposer,
      $$SermonPreachedDatesTableAnnotationComposer,
      $$SermonPreachedDatesTableCreateCompanionBuilder,
      $$SermonPreachedDatesTableUpdateCompanionBuilder,
      (SermonPreachedDate, $$SermonPreachedDatesTableReferences),
      SermonPreachedDate,
      PrefetchHooks Function({bool sermonId})
    >;
typedef $$DocumentVersionsTableCreateCompanionBuilder =
    DocumentVersionsCompanion Function({
      Value<int> id,
      required String sermonId,
      required int documentSchemaVersion,
      required String documentJson,
      required String reason,
      required DateTime createdAt,
    });
typedef $$DocumentVersionsTableUpdateCompanionBuilder =
    DocumentVersionsCompanion Function({
      Value<int> id,
      Value<String> sermonId,
      Value<int> documentSchemaVersion,
      Value<String> documentJson,
      Value<String> reason,
      Value<DateTime> createdAt,
    });

final class $$DocumentVersionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DocumentVersionsTable, DocumentVersion> {
  $$DocumentVersionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SermonRowsTable _sermonIdTable(_$AppDatabase db) =>
      db.sermonRows.createAlias('document_versions__sermon_id__sermons__id');

  $$SermonRowsTableProcessedTableManager get sermonId {
    final $_column = $_itemColumn<String>('sermon_id')!;

    final manager = $$SermonRowsTableTableManager(
      $_db,
      $_db.sermonRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sermonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentVersionsTable> {
  $$DocumentVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get documentSchemaVersion => $composableBuilder(
    column: $table.documentSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SermonRowsTableFilterComposer get sermonId {
    final $$SermonRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableFilterComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentVersionsTable> {
  $$DocumentVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get documentSchemaVersion => $composableBuilder(
    column: $table.documentSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SermonRowsTableOrderingComposer get sermonId {
    final $$SermonRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableOrderingComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentVersionsTable> {
  $$DocumentVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get documentSchemaVersion => $composableBuilder(
    column: $table.documentSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SermonRowsTableAnnotationComposer get sermonId {
    final $$SermonRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sermonId,
      referencedTable: $db.sermonRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SermonRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.sermonRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentVersionsTable,
          DocumentVersion,
          $$DocumentVersionsTableFilterComposer,
          $$DocumentVersionsTableOrderingComposer,
          $$DocumentVersionsTableAnnotationComposer,
          $$DocumentVersionsTableCreateCompanionBuilder,
          $$DocumentVersionsTableUpdateCompanionBuilder,
          (DocumentVersion, $$DocumentVersionsTableReferences),
          DocumentVersion,
          PrefetchHooks Function({bool sermonId})
        > {
  $$DocumentVersionsTableTableManager(
    _$AppDatabase db,
    $DocumentVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sermonId = const Value.absent(),
                Value<int> documentSchemaVersion = const Value.absent(),
                Value<String> documentJson = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DocumentVersionsCompanion(
                id: id,
                sermonId: sermonId,
                documentSchemaVersion: documentSchemaVersion,
                documentJson: documentJson,
                reason: reason,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sermonId,
                required int documentSchemaVersion,
                required String documentJson,
                required String reason,
                required DateTime createdAt,
              }) => DocumentVersionsCompanion.insert(
                id: id,
                sermonId: sermonId,
                documentSchemaVersion: documentSchemaVersion,
                documentJson: documentJson,
                reason: reason,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentVersionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sermonId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sermonId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sermonId,
                                referencedTable:
                                    $$DocumentVersionsTableReferences
                                        ._sermonIdTable(db),
                                referencedColumn:
                                    $$DocumentVersionsTableReferences
                                        ._sermonIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentVersionsTable,
      DocumentVersion,
      $$DocumentVersionsTableFilterComposer,
      $$DocumentVersionsTableOrderingComposer,
      $$DocumentVersionsTableAnnotationComposer,
      $$DocumentVersionsTableCreateCompanionBuilder,
      $$DocumentVersionsTableUpdateCompanionBuilder,
      (DocumentVersion, $$DocumentVersionsTableReferences),
      DocumentVersion,
      PrefetchHooks Function({bool sermonId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String valueJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SermonRowsTableTableManager get sermonRows =>
      $$SermonRowsTableTableManager(_db, _db.sermonRows);
  $$SermonSeriesRowsTableTableManager get sermonSeriesRows =>
      $$SermonSeriesRowsTableTableManager(_db, _db.sermonSeriesRows);
  $$SermonTopicsTableTableManager get sermonTopics =>
      $$SermonTopicsTableTableManager(_db, _db.sermonTopics);
  $$SermonTagsTableTableManager get sermonTags =>
      $$SermonTagsTableTableManager(_db, _db.sermonTags);
  $$SermonPreachedDatesTableTableManager get sermonPreachedDates =>
      $$SermonPreachedDatesTableTableManager(_db, _db.sermonPreachedDates);
  $$DocumentVersionsTableTableManager get documentVersions =>
      $$DocumentVersionsTableTableManager(_db, _db.documentVersions);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
