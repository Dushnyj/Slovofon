// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedTitleMeta = const VerificationMeta(
    'normalizedTitle',
  );
  @override
  late final GeneratedColumn<String> normalizedTitle = GeneratedColumn<String>(
    'normalized_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayTitleMeta = const VerificationMeta(
    'displayTitle',
  );
  @override
  late final GeneratedColumn<String> displayTitle = GeneratedColumn<String>(
    'display_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorsJsonMeta = const VerificationMeta(
    'authorsJson',
  );
  @override
  late final GeneratedColumn<String> authorsJson = GeneratedColumn<String>(
    'authors_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesTitleMeta = const VerificationMeta(
    'seriesTitle',
  );
  @override
  late final GeneratedColumn<String> seriesTitle = GeneratedColumn<String>(
    'series_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesNumberMeta = const VerificationMeta(
    'seriesNumber',
  );
  @override
  late final GeneratedColumn<double> seriesNumber = GeneratedColumn<double>(
    'series_number',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bestCoverUrlMeta = const VerificationMeta(
    'bestCoverUrl',
  );
  @override
  late final GeneratedColumn<String> bestCoverUrl = GeneratedColumn<String>(
    'best_cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bestLocalCoverPathMeta =
      const VerificationMeta('bestLocalCoverPath');
  @override
  late final GeneratedColumn<String> bestLocalCoverPath =
      GeneratedColumn<String>(
        'best_local_cover_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bestDescriptionMeta = const VerificationMeta(
    'bestDescription',
  );
  @override
  late final GeneratedColumn<String> bestDescription = GeneratedColumn<String>(
    'best_description',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    normalizedTitle,
    displayTitle,
    authorsJson,
    seriesTitle,
    seriesNumber,
    year,
    bestCoverUrl,
    bestLocalCoverPath,
    bestDescription,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('normalized_title')) {
      context.handle(
        _normalizedTitleMeta,
        normalizedTitle.isAcceptableOrUnknown(
          data['normalized_title']!,
          _normalizedTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedTitleMeta);
    }
    if (data.containsKey('display_title')) {
      context.handle(
        _displayTitleMeta,
        displayTitle.isAcceptableOrUnknown(
          data['display_title']!,
          _displayTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayTitleMeta);
    }
    if (data.containsKey('authors_json')) {
      context.handle(
        _authorsJsonMeta,
        authorsJson.isAcceptableOrUnknown(
          data['authors_json']!,
          _authorsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_authorsJsonMeta);
    }
    if (data.containsKey('series_title')) {
      context.handle(
        _seriesTitleMeta,
        seriesTitle.isAcceptableOrUnknown(
          data['series_title']!,
          _seriesTitleMeta,
        ),
      );
    }
    if (data.containsKey('series_number')) {
      context.handle(
        _seriesNumberMeta,
        seriesNumber.isAcceptableOrUnknown(
          data['series_number']!,
          _seriesNumberMeta,
        ),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('best_cover_url')) {
      context.handle(
        _bestCoverUrlMeta,
        bestCoverUrl.isAcceptableOrUnknown(
          data['best_cover_url']!,
          _bestCoverUrlMeta,
        ),
      );
    }
    if (data.containsKey('best_local_cover_path')) {
      context.handle(
        _bestLocalCoverPathMeta,
        bestLocalCoverPath.isAcceptableOrUnknown(
          data['best_local_cover_path']!,
          _bestLocalCoverPathMeta,
        ),
      );
    }
    if (data.containsKey('best_description')) {
      context.handle(
        _bestDescriptionMeta,
        bestDescription.isAcceptableOrUnknown(
          data['best_description']!,
          _bestDescriptionMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      normalizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_title'],
      )!,
      displayTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_title'],
      )!,
      authorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}authors_json'],
      )!,
      seriesTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_title'],
      ),
      seriesNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}series_number'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      bestCoverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}best_cover_url'],
      ),
      bestLocalCoverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}best_local_cover_path'],
      ),
      bestDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}best_description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookRow extends DataClass implements Insertable<BookRow> {
  final String id;
  final String normalizedTitle;
  final String displayTitle;
  final String authorsJson;
  final String? seriesTitle;
  final double? seriesNumber;
  final int? year;
  final String? bestCoverUrl;
  final String? bestLocalCoverPath;
  final String? bestDescription;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BookRow({
    required this.id,
    required this.normalizedTitle,
    required this.displayTitle,
    required this.authorsJson,
    this.seriesTitle,
    this.seriesNumber,
    this.year,
    this.bestCoverUrl,
    this.bestLocalCoverPath,
    this.bestDescription,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['normalized_title'] = Variable<String>(normalizedTitle);
    map['display_title'] = Variable<String>(displayTitle);
    map['authors_json'] = Variable<String>(authorsJson);
    if (!nullToAbsent || seriesTitle != null) {
      map['series_title'] = Variable<String>(seriesTitle);
    }
    if (!nullToAbsent || seriesNumber != null) {
      map['series_number'] = Variable<double>(seriesNumber);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || bestCoverUrl != null) {
      map['best_cover_url'] = Variable<String>(bestCoverUrl);
    }
    if (!nullToAbsent || bestLocalCoverPath != null) {
      map['best_local_cover_path'] = Variable<String>(bestLocalCoverPath);
    }
    if (!nullToAbsent || bestDescription != null) {
      map['best_description'] = Variable<String>(bestDescription);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      normalizedTitle: Value(normalizedTitle),
      displayTitle: Value(displayTitle),
      authorsJson: Value(authorsJson),
      seriesTitle: seriesTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesTitle),
      seriesNumber: seriesNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesNumber),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      bestCoverUrl: bestCoverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(bestCoverUrl),
      bestLocalCoverPath: bestLocalCoverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(bestLocalCoverPath),
      bestDescription: bestDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(bestDescription),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRow(
      id: serializer.fromJson<String>(json['id']),
      normalizedTitle: serializer.fromJson<String>(json['normalizedTitle']),
      displayTitle: serializer.fromJson<String>(json['displayTitle']),
      authorsJson: serializer.fromJson<String>(json['authorsJson']),
      seriesTitle: serializer.fromJson<String?>(json['seriesTitle']),
      seriesNumber: serializer.fromJson<double?>(json['seriesNumber']),
      year: serializer.fromJson<int?>(json['year']),
      bestCoverUrl: serializer.fromJson<String?>(json['bestCoverUrl']),
      bestLocalCoverPath: serializer.fromJson<String?>(
        json['bestLocalCoverPath'],
      ),
      bestDescription: serializer.fromJson<String?>(json['bestDescription']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'normalizedTitle': serializer.toJson<String>(normalizedTitle),
      'displayTitle': serializer.toJson<String>(displayTitle),
      'authorsJson': serializer.toJson<String>(authorsJson),
      'seriesTitle': serializer.toJson<String?>(seriesTitle),
      'seriesNumber': serializer.toJson<double?>(seriesNumber),
      'year': serializer.toJson<int?>(year),
      'bestCoverUrl': serializer.toJson<String?>(bestCoverUrl),
      'bestLocalCoverPath': serializer.toJson<String?>(bestLocalCoverPath),
      'bestDescription': serializer.toJson<String?>(bestDescription),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookRow copyWith({
    String? id,
    String? normalizedTitle,
    String? displayTitle,
    String? authorsJson,
    Value<String?> seriesTitle = const Value.absent(),
    Value<double?> seriesNumber = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> bestCoverUrl = const Value.absent(),
    Value<String?> bestLocalCoverPath = const Value.absent(),
    Value<String?> bestDescription = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookRow(
    id: id ?? this.id,
    normalizedTitle: normalizedTitle ?? this.normalizedTitle,
    displayTitle: displayTitle ?? this.displayTitle,
    authorsJson: authorsJson ?? this.authorsJson,
    seriesTitle: seriesTitle.present ? seriesTitle.value : this.seriesTitle,
    seriesNumber: seriesNumber.present ? seriesNumber.value : this.seriesNumber,
    year: year.present ? year.value : this.year,
    bestCoverUrl: bestCoverUrl.present ? bestCoverUrl.value : this.bestCoverUrl,
    bestLocalCoverPath: bestLocalCoverPath.present
        ? bestLocalCoverPath.value
        : this.bestLocalCoverPath,
    bestDescription: bestDescription.present
        ? bestDescription.value
        : this.bestDescription,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookRow copyWithCompanion(BooksCompanion data) {
    return BookRow(
      id: data.id.present ? data.id.value : this.id,
      normalizedTitle: data.normalizedTitle.present
          ? data.normalizedTitle.value
          : this.normalizedTitle,
      displayTitle: data.displayTitle.present
          ? data.displayTitle.value
          : this.displayTitle,
      authorsJson: data.authorsJson.present
          ? data.authorsJson.value
          : this.authorsJson,
      seriesTitle: data.seriesTitle.present
          ? data.seriesTitle.value
          : this.seriesTitle,
      seriesNumber: data.seriesNumber.present
          ? data.seriesNumber.value
          : this.seriesNumber,
      year: data.year.present ? data.year.value : this.year,
      bestCoverUrl: data.bestCoverUrl.present
          ? data.bestCoverUrl.value
          : this.bestCoverUrl,
      bestLocalCoverPath: data.bestLocalCoverPath.present
          ? data.bestLocalCoverPath.value
          : this.bestLocalCoverPath,
      bestDescription: data.bestDescription.present
          ? data.bestDescription.value
          : this.bestDescription,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRow(')
          ..write('id: $id, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('displayTitle: $displayTitle, ')
          ..write('authorsJson: $authorsJson, ')
          ..write('seriesTitle: $seriesTitle, ')
          ..write('seriesNumber: $seriesNumber, ')
          ..write('year: $year, ')
          ..write('bestCoverUrl: $bestCoverUrl, ')
          ..write('bestLocalCoverPath: $bestLocalCoverPath, ')
          ..write('bestDescription: $bestDescription, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    normalizedTitle,
    displayTitle,
    authorsJson,
    seriesTitle,
    seriesNumber,
    year,
    bestCoverUrl,
    bestLocalCoverPath,
    bestDescription,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRow &&
          other.id == this.id &&
          other.normalizedTitle == this.normalizedTitle &&
          other.displayTitle == this.displayTitle &&
          other.authorsJson == this.authorsJson &&
          other.seriesTitle == this.seriesTitle &&
          other.seriesNumber == this.seriesNumber &&
          other.year == this.year &&
          other.bestCoverUrl == this.bestCoverUrl &&
          other.bestLocalCoverPath == this.bestLocalCoverPath &&
          other.bestDescription == this.bestDescription &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BooksCompanion extends UpdateCompanion<BookRow> {
  final Value<String> id;
  final Value<String> normalizedTitle;
  final Value<String> displayTitle;
  final Value<String> authorsJson;
  final Value<String?> seriesTitle;
  final Value<double?> seriesNumber;
  final Value<int?> year;
  final Value<String?> bestCoverUrl;
  final Value<String?> bestLocalCoverPath;
  final Value<String?> bestDescription;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.normalizedTitle = const Value.absent(),
    this.displayTitle = const Value.absent(),
    this.authorsJson = const Value.absent(),
    this.seriesTitle = const Value.absent(),
    this.seriesNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.bestCoverUrl = const Value.absent(),
    this.bestLocalCoverPath = const Value.absent(),
    this.bestDescription = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String normalizedTitle,
    required String displayTitle,
    required String authorsJson,
    this.seriesTitle = const Value.absent(),
    this.seriesNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.bestCoverUrl = const Value.absent(),
    this.bestLocalCoverPath = const Value.absent(),
    this.bestDescription = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       normalizedTitle = Value(normalizedTitle),
       displayTitle = Value(displayTitle),
       authorsJson = Value(authorsJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookRow> custom({
    Expression<String>? id,
    Expression<String>? normalizedTitle,
    Expression<String>? displayTitle,
    Expression<String>? authorsJson,
    Expression<String>? seriesTitle,
    Expression<double>? seriesNumber,
    Expression<int>? year,
    Expression<String>? bestCoverUrl,
    Expression<String>? bestLocalCoverPath,
    Expression<String>? bestDescription,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (normalizedTitle != null) 'normalized_title': normalizedTitle,
      if (displayTitle != null) 'display_title': displayTitle,
      if (authorsJson != null) 'authors_json': authorsJson,
      if (seriesTitle != null) 'series_title': seriesTitle,
      if (seriesNumber != null) 'series_number': seriesNumber,
      if (year != null) 'year': year,
      if (bestCoverUrl != null) 'best_cover_url': bestCoverUrl,
      if (bestLocalCoverPath != null)
        'best_local_cover_path': bestLocalCoverPath,
      if (bestDescription != null) 'best_description': bestDescription,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? normalizedTitle,
    Value<String>? displayTitle,
    Value<String>? authorsJson,
    Value<String?>? seriesTitle,
    Value<double?>? seriesNumber,
    Value<int?>? year,
    Value<String?>? bestCoverUrl,
    Value<String?>? bestLocalCoverPath,
    Value<String?>? bestDescription,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      displayTitle: displayTitle ?? this.displayTitle,
      authorsJson: authorsJson ?? this.authorsJson,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      year: year ?? this.year,
      bestCoverUrl: bestCoverUrl ?? this.bestCoverUrl,
      bestLocalCoverPath: bestLocalCoverPath ?? this.bestLocalCoverPath,
      bestDescription: bestDescription ?? this.bestDescription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (normalizedTitle.present) {
      map['normalized_title'] = Variable<String>(normalizedTitle.value);
    }
    if (displayTitle.present) {
      map['display_title'] = Variable<String>(displayTitle.value);
    }
    if (authorsJson.present) {
      map['authors_json'] = Variable<String>(authorsJson.value);
    }
    if (seriesTitle.present) {
      map['series_title'] = Variable<String>(seriesTitle.value);
    }
    if (seriesNumber.present) {
      map['series_number'] = Variable<double>(seriesNumber.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (bestCoverUrl.present) {
      map['best_cover_url'] = Variable<String>(bestCoverUrl.value);
    }
    if (bestLocalCoverPath.present) {
      map['best_local_cover_path'] = Variable<String>(bestLocalCoverPath.value);
    }
    if (bestDescription.present) {
      map['best_description'] = Variable<String>(bestDescription.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('displayTitle: $displayTitle, ')
          ..write('authorsJson: $authorsJson, ')
          ..write('seriesTitle: $seriesTitle, ')
          ..write('seriesNumber: $seriesNumber, ')
          ..write('year: $year, ')
          ..write('bestCoverUrl: $bestCoverUrl, ')
          ..write('bestLocalCoverPath: $bestLocalCoverPath, ')
          ..write('bestDescription: $bestDescription, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookVersionsTable extends BookVersions
    with TableInfo<$BookVersionsTable, BookVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceBookIdMeta = const VerificationMeta(
    'sourceBookId',
  );
  @override
  late final GeneratedColumn<String> sourceBookId = GeneratedColumn<String>(
    'source_book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _normalizedTitleMeta = const VerificationMeta(
    'normalizedTitle',
  );
  @override
  late final GeneratedColumn<String> normalizedTitle = GeneratedColumn<String>(
    'normalized_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorsJsonMeta = const VerificationMeta(
    'authorsJson',
  );
  @override
  late final GeneratedColumn<String> authorsJson = GeneratedColumn<String>(
    'authors_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _narratorsJsonMeta = const VerificationMeta(
    'narratorsJson',
  );
  @override
  late final GeneratedColumn<String> narratorsJson = GeneratedColumn<String>(
    'narrators_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translatorsJsonMeta = const VerificationMeta(
    'translatorsJson',
  );
  @override
  late final GeneratedColumn<String> translatorsJson = GeneratedColumn<String>(
    'translators_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _seriesTitleMeta = const VerificationMeta(
    'seriesTitle',
  );
  @override
  late final GeneratedColumn<String> seriesTitle = GeneratedColumn<String>(
    'series_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesNumberMeta = const VerificationMeta(
    'seriesNumber',
  );
  @override
  late final GeneratedColumn<double> seriesNumber = GeneratedColumn<double>(
    'series_number',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresJsonMeta = const VerificationMeta(
    'genresJson',
  );
  @override
  late final GeneratedColumn<String> genresJson = GeneratedColumn<String>(
    'genres_json',
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localCoverPathMeta = const VerificationMeta(
    'localCoverPath',
  );
  @override
  late final GeneratedColumn<String> localCoverPath = GeneratedColumn<String>(
    'local_cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationTextMeta = const VerificationMeta(
    'durationText',
  );
  @override
  late final GeneratedColumn<String> durationText = GeneratedColumn<String>(
    'duration_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedYearMeta = const VerificationMeta(
    'publishedYear',
  );
  @override
  late final GeneratedColumn<int> publishedYear = GeneratedColumn<int>(
    'published_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioYearMeta = const VerificationMeta(
    'audioYear',
  );
  @override
  late final GeneratedColumn<int> audioYear = GeneratedColumn<int>(
    'audio_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingValueMeta = const VerificationMeta(
    'ratingValue',
  );
  @override
  late final GeneratedColumn<double> ratingValue = GeneratedColumn<double>(
    'rating_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingCountMeta = const VerificationMeta(
    'ratingCount',
  );
  @override
  late final GeneratedColumn<int> ratingCount = GeneratedColumn<int>(
    'rating_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessTypeMeta = const VerificationMeta(
    'accessType',
  );
  @override
  late final GeneratedColumn<String> accessType = GeneratedColumn<String>(
    'access_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackAccessMeta = const VerificationMeta(
    'playbackAccess',
  );
  @override
  late final GeneratedColumn<String> playbackAccess = GeneratedColumn<String>(
    'playback_access',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFullMeta = const VerificationMeta('isFull');
  @override
  late final GeneratedColumn<bool> isFull = GeneratedColumn<bool>(
    'is_full',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_full" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFragmentMeta = const VerificationMeta(
    'isFragment',
  );
  @override
  late final GeneratedColumn<bool> isFragment = GeneratedColumn<bool>(
    'is_fragment',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_fragment" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPaidMeta = const VerificationMeta('isPaid');
  @override
  late final GeneratedColumn<bool> isPaid = GeneratedColumn<bool>(
    'is_paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_paid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isSubscriptionMeta = const VerificationMeta(
    'isSubscription',
  );
  @override
  late final GeneratedColumn<bool> isSubscription = GeneratedColumn<bool>(
    'is_subscription',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_subscription" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isAccessibleForFreeMeta =
      const VerificationMeta('isAccessibleForFree');
  @override
  late final GeneratedColumn<bool> isAccessibleForFree = GeneratedColumn<bool>(
    'is_accessible_for_free',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_accessible_for_free" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _canStreamMeta = const VerificationMeta(
    'canStream',
  );
  @override
  late final GeneratedColumn<bool> canStream = GeneratedColumn<bool>(
    'can_stream',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("can_stream" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _canDownloadMeta = const VerificationMeta(
    'canDownload',
  );
  @override
  late final GeneratedColumn<bool> canDownload = GeneratedColumn<bool>(
    'can_download',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("can_download" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rawSourceDataJsonMeta = const VerificationMeta(
    'rawSourceDataJson',
  );
  @override
  late final GeneratedColumn<String> rawSourceDataJson =
      GeneratedColumn<String>(
        'raw_source_data_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastResolvedAtMeta = const VerificationMeta(
    'lastResolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastResolvedAt =
      GeneratedColumn<DateTime>(
        'last_resolved_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    sourceId,
    sourceBookId,
    sourceUrl,
    title,
    normalizedTitle,
    authorsJson,
    narratorsJson,
    translatorsJson,
    seriesTitle,
    seriesNumber,
    genresJson,
    tagsJson,
    description,
    coverUrl,
    localCoverPath,
    durationMs,
    durationText,
    publishedYear,
    audioYear,
    ratingValue,
    ratingCount,
    accessType,
    playbackAccess,
    isFull,
    isFragment,
    isPaid,
    isSubscription,
    isAccessibleForFree,
    canStream,
    canDownload,
    rawSourceDataJson,
    lastResolvedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_book_id')) {
      context.handle(
        _sourceBookIdMeta,
        sourceBookId.isAcceptableOrUnknown(
          data['source_book_id']!,
          _sourceBookIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceBookIdMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('normalized_title')) {
      context.handle(
        _normalizedTitleMeta,
        normalizedTitle.isAcceptableOrUnknown(
          data['normalized_title']!,
          _normalizedTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedTitleMeta);
    }
    if (data.containsKey('authors_json')) {
      context.handle(
        _authorsJsonMeta,
        authorsJson.isAcceptableOrUnknown(
          data['authors_json']!,
          _authorsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_authorsJsonMeta);
    }
    if (data.containsKey('narrators_json')) {
      context.handle(
        _narratorsJsonMeta,
        narratorsJson.isAcceptableOrUnknown(
          data['narrators_json']!,
          _narratorsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_narratorsJsonMeta);
    }
    if (data.containsKey('translators_json')) {
      context.handle(
        _translatorsJsonMeta,
        translatorsJson.isAcceptableOrUnknown(
          data['translators_json']!,
          _translatorsJsonMeta,
        ),
      );
    }
    if (data.containsKey('series_title')) {
      context.handle(
        _seriesTitleMeta,
        seriesTitle.isAcceptableOrUnknown(
          data['series_title']!,
          _seriesTitleMeta,
        ),
      );
    }
    if (data.containsKey('series_number')) {
      context.handle(
        _seriesNumberMeta,
        seriesNumber.isAcceptableOrUnknown(
          data['series_number']!,
          _seriesNumberMeta,
        ),
      );
    }
    if (data.containsKey('genres_json')) {
      context.handle(
        _genresJsonMeta,
        genresJson.isAcceptableOrUnknown(data['genres_json']!, _genresJsonMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
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
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('local_cover_path')) {
      context.handle(
        _localCoverPathMeta,
        localCoverPath.isAcceptableOrUnknown(
          data['local_cover_path']!,
          _localCoverPathMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('duration_text')) {
      context.handle(
        _durationTextMeta,
        durationText.isAcceptableOrUnknown(
          data['duration_text']!,
          _durationTextMeta,
        ),
      );
    }
    if (data.containsKey('published_year')) {
      context.handle(
        _publishedYearMeta,
        publishedYear.isAcceptableOrUnknown(
          data['published_year']!,
          _publishedYearMeta,
        ),
      );
    }
    if (data.containsKey('audio_year')) {
      context.handle(
        _audioYearMeta,
        audioYear.isAcceptableOrUnknown(data['audio_year']!, _audioYearMeta),
      );
    }
    if (data.containsKey('rating_value')) {
      context.handle(
        _ratingValueMeta,
        ratingValue.isAcceptableOrUnknown(
          data['rating_value']!,
          _ratingValueMeta,
        ),
      );
    }
    if (data.containsKey('rating_count')) {
      context.handle(
        _ratingCountMeta,
        ratingCount.isAcceptableOrUnknown(
          data['rating_count']!,
          _ratingCountMeta,
        ),
      );
    }
    if (data.containsKey('access_type')) {
      context.handle(
        _accessTypeMeta,
        accessType.isAcceptableOrUnknown(data['access_type']!, _accessTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_accessTypeMeta);
    }
    if (data.containsKey('playback_access')) {
      context.handle(
        _playbackAccessMeta,
        playbackAccess.isAcceptableOrUnknown(
          data['playback_access']!,
          _playbackAccessMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playbackAccessMeta);
    }
    if (data.containsKey('is_full')) {
      context.handle(
        _isFullMeta,
        isFull.isAcceptableOrUnknown(data['is_full']!, _isFullMeta),
      );
    }
    if (data.containsKey('is_fragment')) {
      context.handle(
        _isFragmentMeta,
        isFragment.isAcceptableOrUnknown(data['is_fragment']!, _isFragmentMeta),
      );
    }
    if (data.containsKey('is_paid')) {
      context.handle(
        _isPaidMeta,
        isPaid.isAcceptableOrUnknown(data['is_paid']!, _isPaidMeta),
      );
    }
    if (data.containsKey('is_subscription')) {
      context.handle(
        _isSubscriptionMeta,
        isSubscription.isAcceptableOrUnknown(
          data['is_subscription']!,
          _isSubscriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_accessible_for_free')) {
      context.handle(
        _isAccessibleForFreeMeta,
        isAccessibleForFree.isAcceptableOrUnknown(
          data['is_accessible_for_free']!,
          _isAccessibleForFreeMeta,
        ),
      );
    }
    if (data.containsKey('can_stream')) {
      context.handle(
        _canStreamMeta,
        canStream.isAcceptableOrUnknown(data['can_stream']!, _canStreamMeta),
      );
    }
    if (data.containsKey('can_download')) {
      context.handle(
        _canDownloadMeta,
        canDownload.isAcceptableOrUnknown(
          data['can_download']!,
          _canDownloadMeta,
        ),
      );
    }
    if (data.containsKey('raw_source_data_json')) {
      context.handle(
        _rawSourceDataJsonMeta,
        rawSourceDataJson.isAcceptableOrUnknown(
          data['raw_source_data_json']!,
          _rawSourceDataJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_resolved_at')) {
      context.handle(
        _lastResolvedAtMeta,
        lastResolvedAt.isAcceptableOrUnknown(
          data['last_resolved_at']!,
          _lastResolvedAtMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookVersionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_book_id'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      normalizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_title'],
      )!,
      authorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}authors_json'],
      )!,
      narratorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrators_json'],
      )!,
      translatorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translators_json'],
      )!,
      seriesTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_title'],
      ),
      seriesNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}series_number'],
      ),
      genresJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      localCoverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_cover_path'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      durationText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duration_text'],
      ),
      publishedYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_year'],
      ),
      audioYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_year'],
      ),
      ratingValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating_value'],
      ),
      ratingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating_count'],
      ),
      accessType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_type'],
      )!,
      playbackAccess: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_access'],
      )!,
      isFull: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_full'],
      )!,
      isFragment: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_fragment'],
      )!,
      isPaid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_paid'],
      )!,
      isSubscription: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_subscription'],
      )!,
      isAccessibleForFree: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_accessible_for_free'],
      )!,
      canStream: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}can_stream'],
      )!,
      canDownload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}can_download'],
      )!,
      rawSourceDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_source_data_json'],
      ),
      lastResolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_resolved_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookVersionsTable createAlias(String alias) {
    return $BookVersionsTable(attachedDatabase, alias);
  }
}

class BookVersionRow extends DataClass implements Insertable<BookVersionRow> {
  final String id;
  final String bookId;
  final String sourceId;
  final String sourceBookId;
  final String? sourceUrl;
  final String title;
  final String normalizedTitle;
  final String authorsJson;
  final String narratorsJson;
  final String translatorsJson;
  final String? seriesTitle;
  final double? seriesNumber;
  final String genresJson;
  final String tagsJson;
  final String? description;
  final String? coverUrl;
  final String? localCoverPath;
  final int? durationMs;
  final String? durationText;
  final int? publishedYear;
  final int? audioYear;
  final double? ratingValue;
  final int? ratingCount;
  final String accessType;
  final String playbackAccess;
  final bool isFull;
  final bool isFragment;
  final bool isPaid;
  final bool isSubscription;
  final bool isAccessibleForFree;
  final bool canStream;
  final bool canDownload;
  final String? rawSourceDataJson;
  final DateTime? lastResolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BookVersionRow({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.sourceBookId,
    this.sourceUrl,
    required this.title,
    required this.normalizedTitle,
    required this.authorsJson,
    required this.narratorsJson,
    required this.translatorsJson,
    this.seriesTitle,
    this.seriesNumber,
    required this.genresJson,
    required this.tagsJson,
    this.description,
    this.coverUrl,
    this.localCoverPath,
    this.durationMs,
    this.durationText,
    this.publishedYear,
    this.audioYear,
    this.ratingValue,
    this.ratingCount,
    required this.accessType,
    required this.playbackAccess,
    required this.isFull,
    required this.isFragment,
    required this.isPaid,
    required this.isSubscription,
    required this.isAccessibleForFree,
    required this.canStream,
    required this.canDownload,
    this.rawSourceDataJson,
    this.lastResolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['source_book_id'] = Variable<String>(sourceBookId);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['title'] = Variable<String>(title);
    map['normalized_title'] = Variable<String>(normalizedTitle);
    map['authors_json'] = Variable<String>(authorsJson);
    map['narrators_json'] = Variable<String>(narratorsJson);
    map['translators_json'] = Variable<String>(translatorsJson);
    if (!nullToAbsent || seriesTitle != null) {
      map['series_title'] = Variable<String>(seriesTitle);
    }
    if (!nullToAbsent || seriesNumber != null) {
      map['series_number'] = Variable<double>(seriesNumber);
    }
    map['genres_json'] = Variable<String>(genresJson);
    map['tags_json'] = Variable<String>(tagsJson);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || localCoverPath != null) {
      map['local_cover_path'] = Variable<String>(localCoverPath);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || durationText != null) {
      map['duration_text'] = Variable<String>(durationText);
    }
    if (!nullToAbsent || publishedYear != null) {
      map['published_year'] = Variable<int>(publishedYear);
    }
    if (!nullToAbsent || audioYear != null) {
      map['audio_year'] = Variable<int>(audioYear);
    }
    if (!nullToAbsent || ratingValue != null) {
      map['rating_value'] = Variable<double>(ratingValue);
    }
    if (!nullToAbsent || ratingCount != null) {
      map['rating_count'] = Variable<int>(ratingCount);
    }
    map['access_type'] = Variable<String>(accessType);
    map['playback_access'] = Variable<String>(playbackAccess);
    map['is_full'] = Variable<bool>(isFull);
    map['is_fragment'] = Variable<bool>(isFragment);
    map['is_paid'] = Variable<bool>(isPaid);
    map['is_subscription'] = Variable<bool>(isSubscription);
    map['is_accessible_for_free'] = Variable<bool>(isAccessibleForFree);
    map['can_stream'] = Variable<bool>(canStream);
    map['can_download'] = Variable<bool>(canDownload);
    if (!nullToAbsent || rawSourceDataJson != null) {
      map['raw_source_data_json'] = Variable<String>(rawSourceDataJson);
    }
    if (!nullToAbsent || lastResolvedAt != null) {
      map['last_resolved_at'] = Variable<DateTime>(lastResolvedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookVersionsCompanion toCompanion(bool nullToAbsent) {
    return BookVersionsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      sourceBookId: Value(sourceBookId),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      title: Value(title),
      normalizedTitle: Value(normalizedTitle),
      authorsJson: Value(authorsJson),
      narratorsJson: Value(narratorsJson),
      translatorsJson: Value(translatorsJson),
      seriesTitle: seriesTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesTitle),
      seriesNumber: seriesNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesNumber),
      genresJson: Value(genresJson),
      tagsJson: Value(tagsJson),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      localCoverPath: localCoverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localCoverPath),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      durationText: durationText == null && nullToAbsent
          ? const Value.absent()
          : Value(durationText),
      publishedYear: publishedYear == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedYear),
      audioYear: audioYear == null && nullToAbsent
          ? const Value.absent()
          : Value(audioYear),
      ratingValue: ratingValue == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingValue),
      ratingCount: ratingCount == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingCount),
      accessType: Value(accessType),
      playbackAccess: Value(playbackAccess),
      isFull: Value(isFull),
      isFragment: Value(isFragment),
      isPaid: Value(isPaid),
      isSubscription: Value(isSubscription),
      isAccessibleForFree: Value(isAccessibleForFree),
      canStream: Value(canStream),
      canDownload: Value(canDownload),
      rawSourceDataJson: rawSourceDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawSourceDataJson),
      lastResolvedAt: lastResolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastResolvedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookVersionRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceBookId: serializer.fromJson<String>(json['sourceBookId']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      title: serializer.fromJson<String>(json['title']),
      normalizedTitle: serializer.fromJson<String>(json['normalizedTitle']),
      authorsJson: serializer.fromJson<String>(json['authorsJson']),
      narratorsJson: serializer.fromJson<String>(json['narratorsJson']),
      translatorsJson: serializer.fromJson<String>(json['translatorsJson']),
      seriesTitle: serializer.fromJson<String?>(json['seriesTitle']),
      seriesNumber: serializer.fromJson<double?>(json['seriesNumber']),
      genresJson: serializer.fromJson<String>(json['genresJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      description: serializer.fromJson<String?>(json['description']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      localCoverPath: serializer.fromJson<String?>(json['localCoverPath']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      durationText: serializer.fromJson<String?>(json['durationText']),
      publishedYear: serializer.fromJson<int?>(json['publishedYear']),
      audioYear: serializer.fromJson<int?>(json['audioYear']),
      ratingValue: serializer.fromJson<double?>(json['ratingValue']),
      ratingCount: serializer.fromJson<int?>(json['ratingCount']),
      accessType: serializer.fromJson<String>(json['accessType']),
      playbackAccess: serializer.fromJson<String>(json['playbackAccess']),
      isFull: serializer.fromJson<bool>(json['isFull']),
      isFragment: serializer.fromJson<bool>(json['isFragment']),
      isPaid: serializer.fromJson<bool>(json['isPaid']),
      isSubscription: serializer.fromJson<bool>(json['isSubscription']),
      isAccessibleForFree: serializer.fromJson<bool>(
        json['isAccessibleForFree'],
      ),
      canStream: serializer.fromJson<bool>(json['canStream']),
      canDownload: serializer.fromJson<bool>(json['canDownload']),
      rawSourceDataJson: serializer.fromJson<String?>(
        json['rawSourceDataJson'],
      ),
      lastResolvedAt: serializer.fromJson<DateTime?>(json['lastResolvedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceBookId': serializer.toJson<String>(sourceBookId),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'title': serializer.toJson<String>(title),
      'normalizedTitle': serializer.toJson<String>(normalizedTitle),
      'authorsJson': serializer.toJson<String>(authorsJson),
      'narratorsJson': serializer.toJson<String>(narratorsJson),
      'translatorsJson': serializer.toJson<String>(translatorsJson),
      'seriesTitle': serializer.toJson<String?>(seriesTitle),
      'seriesNumber': serializer.toJson<double?>(seriesNumber),
      'genresJson': serializer.toJson<String>(genresJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'description': serializer.toJson<String?>(description),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'localCoverPath': serializer.toJson<String?>(localCoverPath),
      'durationMs': serializer.toJson<int?>(durationMs),
      'durationText': serializer.toJson<String?>(durationText),
      'publishedYear': serializer.toJson<int?>(publishedYear),
      'audioYear': serializer.toJson<int?>(audioYear),
      'ratingValue': serializer.toJson<double?>(ratingValue),
      'ratingCount': serializer.toJson<int?>(ratingCount),
      'accessType': serializer.toJson<String>(accessType),
      'playbackAccess': serializer.toJson<String>(playbackAccess),
      'isFull': serializer.toJson<bool>(isFull),
      'isFragment': serializer.toJson<bool>(isFragment),
      'isPaid': serializer.toJson<bool>(isPaid),
      'isSubscription': serializer.toJson<bool>(isSubscription),
      'isAccessibleForFree': serializer.toJson<bool>(isAccessibleForFree),
      'canStream': serializer.toJson<bool>(canStream),
      'canDownload': serializer.toJson<bool>(canDownload),
      'rawSourceDataJson': serializer.toJson<String?>(rawSourceDataJson),
      'lastResolvedAt': serializer.toJson<DateTime?>(lastResolvedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookVersionRow copyWith({
    String? id,
    String? bookId,
    String? sourceId,
    String? sourceBookId,
    Value<String?> sourceUrl = const Value.absent(),
    String? title,
    String? normalizedTitle,
    String? authorsJson,
    String? narratorsJson,
    String? translatorsJson,
    Value<String?> seriesTitle = const Value.absent(),
    Value<double?> seriesNumber = const Value.absent(),
    String? genresJson,
    String? tagsJson,
    Value<String?> description = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> localCoverPath = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> durationText = const Value.absent(),
    Value<int?> publishedYear = const Value.absent(),
    Value<int?> audioYear = const Value.absent(),
    Value<double?> ratingValue = const Value.absent(),
    Value<int?> ratingCount = const Value.absent(),
    String? accessType,
    String? playbackAccess,
    bool? isFull,
    bool? isFragment,
    bool? isPaid,
    bool? isSubscription,
    bool? isAccessibleForFree,
    bool? canStream,
    bool? canDownload,
    Value<String?> rawSourceDataJson = const Value.absent(),
    Value<DateTime?> lastResolvedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookVersionRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    sourceBookId: sourceBookId ?? this.sourceBookId,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    title: title ?? this.title,
    normalizedTitle: normalizedTitle ?? this.normalizedTitle,
    authorsJson: authorsJson ?? this.authorsJson,
    narratorsJson: narratorsJson ?? this.narratorsJson,
    translatorsJson: translatorsJson ?? this.translatorsJson,
    seriesTitle: seriesTitle.present ? seriesTitle.value : this.seriesTitle,
    seriesNumber: seriesNumber.present ? seriesNumber.value : this.seriesNumber,
    genresJson: genresJson ?? this.genresJson,
    tagsJson: tagsJson ?? this.tagsJson,
    description: description.present ? description.value : this.description,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    localCoverPath: localCoverPath.present
        ? localCoverPath.value
        : this.localCoverPath,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    durationText: durationText.present ? durationText.value : this.durationText,
    publishedYear: publishedYear.present
        ? publishedYear.value
        : this.publishedYear,
    audioYear: audioYear.present ? audioYear.value : this.audioYear,
    ratingValue: ratingValue.present ? ratingValue.value : this.ratingValue,
    ratingCount: ratingCount.present ? ratingCount.value : this.ratingCount,
    accessType: accessType ?? this.accessType,
    playbackAccess: playbackAccess ?? this.playbackAccess,
    isFull: isFull ?? this.isFull,
    isFragment: isFragment ?? this.isFragment,
    isPaid: isPaid ?? this.isPaid,
    isSubscription: isSubscription ?? this.isSubscription,
    isAccessibleForFree: isAccessibleForFree ?? this.isAccessibleForFree,
    canStream: canStream ?? this.canStream,
    canDownload: canDownload ?? this.canDownload,
    rawSourceDataJson: rawSourceDataJson.present
        ? rawSourceDataJson.value
        : this.rawSourceDataJson,
    lastResolvedAt: lastResolvedAt.present
        ? lastResolvedAt.value
        : this.lastResolvedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookVersionRow copyWithCompanion(BookVersionsCompanion data) {
    return BookVersionRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceBookId: data.sourceBookId.present
          ? data.sourceBookId.value
          : this.sourceBookId,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      title: data.title.present ? data.title.value : this.title,
      normalizedTitle: data.normalizedTitle.present
          ? data.normalizedTitle.value
          : this.normalizedTitle,
      authorsJson: data.authorsJson.present
          ? data.authorsJson.value
          : this.authorsJson,
      narratorsJson: data.narratorsJson.present
          ? data.narratorsJson.value
          : this.narratorsJson,
      translatorsJson: data.translatorsJson.present
          ? data.translatorsJson.value
          : this.translatorsJson,
      seriesTitle: data.seriesTitle.present
          ? data.seriesTitle.value
          : this.seriesTitle,
      seriesNumber: data.seriesNumber.present
          ? data.seriesNumber.value
          : this.seriesNumber,
      genresJson: data.genresJson.present
          ? data.genresJson.value
          : this.genresJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      description: data.description.present
          ? data.description.value
          : this.description,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      localCoverPath: data.localCoverPath.present
          ? data.localCoverPath.value
          : this.localCoverPath,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      durationText: data.durationText.present
          ? data.durationText.value
          : this.durationText,
      publishedYear: data.publishedYear.present
          ? data.publishedYear.value
          : this.publishedYear,
      audioYear: data.audioYear.present ? data.audioYear.value : this.audioYear,
      ratingValue: data.ratingValue.present
          ? data.ratingValue.value
          : this.ratingValue,
      ratingCount: data.ratingCount.present
          ? data.ratingCount.value
          : this.ratingCount,
      accessType: data.accessType.present
          ? data.accessType.value
          : this.accessType,
      playbackAccess: data.playbackAccess.present
          ? data.playbackAccess.value
          : this.playbackAccess,
      isFull: data.isFull.present ? data.isFull.value : this.isFull,
      isFragment: data.isFragment.present
          ? data.isFragment.value
          : this.isFragment,
      isPaid: data.isPaid.present ? data.isPaid.value : this.isPaid,
      isSubscription: data.isSubscription.present
          ? data.isSubscription.value
          : this.isSubscription,
      isAccessibleForFree: data.isAccessibleForFree.present
          ? data.isAccessibleForFree.value
          : this.isAccessibleForFree,
      canStream: data.canStream.present ? data.canStream.value : this.canStream,
      canDownload: data.canDownload.present
          ? data.canDownload.value
          : this.canDownload,
      rawSourceDataJson: data.rawSourceDataJson.present
          ? data.rawSourceDataJson.value
          : this.rawSourceDataJson,
      lastResolvedAt: data.lastResolvedAt.present
          ? data.lastResolvedAt.value
          : this.lastResolvedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookVersionRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('title: $title, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('authorsJson: $authorsJson, ')
          ..write('narratorsJson: $narratorsJson, ')
          ..write('translatorsJson: $translatorsJson, ')
          ..write('seriesTitle: $seriesTitle, ')
          ..write('seriesNumber: $seriesNumber, ')
          ..write('genresJson: $genresJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('description: $description, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('localCoverPath: $localCoverPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('durationText: $durationText, ')
          ..write('publishedYear: $publishedYear, ')
          ..write('audioYear: $audioYear, ')
          ..write('ratingValue: $ratingValue, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('accessType: $accessType, ')
          ..write('playbackAccess: $playbackAccess, ')
          ..write('isFull: $isFull, ')
          ..write('isFragment: $isFragment, ')
          ..write('isPaid: $isPaid, ')
          ..write('isSubscription: $isSubscription, ')
          ..write('isAccessibleForFree: $isAccessibleForFree, ')
          ..write('canStream: $canStream, ')
          ..write('canDownload: $canDownload, ')
          ..write('rawSourceDataJson: $rawSourceDataJson, ')
          ..write('lastResolvedAt: $lastResolvedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    bookId,
    sourceId,
    sourceBookId,
    sourceUrl,
    title,
    normalizedTitle,
    authorsJson,
    narratorsJson,
    translatorsJson,
    seriesTitle,
    seriesNumber,
    genresJson,
    tagsJson,
    description,
    coverUrl,
    localCoverPath,
    durationMs,
    durationText,
    publishedYear,
    audioYear,
    ratingValue,
    ratingCount,
    accessType,
    playbackAccess,
    isFull,
    isFragment,
    isPaid,
    isSubscription,
    isAccessibleForFree,
    canStream,
    canDownload,
    rawSourceDataJson,
    lastResolvedAt,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookVersionRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.sourceBookId == this.sourceBookId &&
          other.sourceUrl == this.sourceUrl &&
          other.title == this.title &&
          other.normalizedTitle == this.normalizedTitle &&
          other.authorsJson == this.authorsJson &&
          other.narratorsJson == this.narratorsJson &&
          other.translatorsJson == this.translatorsJson &&
          other.seriesTitle == this.seriesTitle &&
          other.seriesNumber == this.seriesNumber &&
          other.genresJson == this.genresJson &&
          other.tagsJson == this.tagsJson &&
          other.description == this.description &&
          other.coverUrl == this.coverUrl &&
          other.localCoverPath == this.localCoverPath &&
          other.durationMs == this.durationMs &&
          other.durationText == this.durationText &&
          other.publishedYear == this.publishedYear &&
          other.audioYear == this.audioYear &&
          other.ratingValue == this.ratingValue &&
          other.ratingCount == this.ratingCount &&
          other.accessType == this.accessType &&
          other.playbackAccess == this.playbackAccess &&
          other.isFull == this.isFull &&
          other.isFragment == this.isFragment &&
          other.isPaid == this.isPaid &&
          other.isSubscription == this.isSubscription &&
          other.isAccessibleForFree == this.isAccessibleForFree &&
          other.canStream == this.canStream &&
          other.canDownload == this.canDownload &&
          other.rawSourceDataJson == this.rawSourceDataJson &&
          other.lastResolvedAt == this.lastResolvedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookVersionsCompanion extends UpdateCompanion<BookVersionRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<String> sourceBookId;
  final Value<String?> sourceUrl;
  final Value<String> title;
  final Value<String> normalizedTitle;
  final Value<String> authorsJson;
  final Value<String> narratorsJson;
  final Value<String> translatorsJson;
  final Value<String?> seriesTitle;
  final Value<double?> seriesNumber;
  final Value<String> genresJson;
  final Value<String> tagsJson;
  final Value<String?> description;
  final Value<String?> coverUrl;
  final Value<String?> localCoverPath;
  final Value<int?> durationMs;
  final Value<String?> durationText;
  final Value<int?> publishedYear;
  final Value<int?> audioYear;
  final Value<double?> ratingValue;
  final Value<int?> ratingCount;
  final Value<String> accessType;
  final Value<String> playbackAccess;
  final Value<bool> isFull;
  final Value<bool> isFragment;
  final Value<bool> isPaid;
  final Value<bool> isSubscription;
  final Value<bool> isAccessibleForFree;
  final Value<bool> canStream;
  final Value<bool> canDownload;
  final Value<String?> rawSourceDataJson;
  final Value<DateTime?> lastResolvedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookVersionsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceBookId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.normalizedTitle = const Value.absent(),
    this.authorsJson = const Value.absent(),
    this.narratorsJson = const Value.absent(),
    this.translatorsJson = const Value.absent(),
    this.seriesTitle = const Value.absent(),
    this.seriesNumber = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.description = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.localCoverPath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.durationText = const Value.absent(),
    this.publishedYear = const Value.absent(),
    this.audioYear = const Value.absent(),
    this.ratingValue = const Value.absent(),
    this.ratingCount = const Value.absent(),
    this.accessType = const Value.absent(),
    this.playbackAccess = const Value.absent(),
    this.isFull = const Value.absent(),
    this.isFragment = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.isSubscription = const Value.absent(),
    this.isAccessibleForFree = const Value.absent(),
    this.canStream = const Value.absent(),
    this.canDownload = const Value.absent(),
    this.rawSourceDataJson = const Value.absent(),
    this.lastResolvedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookVersionsCompanion.insert({
    required String id,
    required String bookId,
    required String sourceId,
    required String sourceBookId,
    this.sourceUrl = const Value.absent(),
    required String title,
    required String normalizedTitle,
    required String authorsJson,
    required String narratorsJson,
    this.translatorsJson = const Value.absent(),
    this.seriesTitle = const Value.absent(),
    this.seriesNumber = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.description = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.localCoverPath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.durationText = const Value.absent(),
    this.publishedYear = const Value.absent(),
    this.audioYear = const Value.absent(),
    this.ratingValue = const Value.absent(),
    this.ratingCount = const Value.absent(),
    required String accessType,
    required String playbackAccess,
    this.isFull = const Value.absent(),
    this.isFragment = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.isSubscription = const Value.absent(),
    this.isAccessibleForFree = const Value.absent(),
    this.canStream = const Value.absent(),
    this.canDownload = const Value.absent(),
    this.rawSourceDataJson = const Value.absent(),
    this.lastResolvedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       sourceId = Value(sourceId),
       sourceBookId = Value(sourceBookId),
       title = Value(title),
       normalizedTitle = Value(normalizedTitle),
       authorsJson = Value(authorsJson),
       narratorsJson = Value(narratorsJson),
       accessType = Value(accessType),
       playbackAccess = Value(playbackAccess),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookVersionRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? sourceBookId,
    Expression<String>? sourceUrl,
    Expression<String>? title,
    Expression<String>? normalizedTitle,
    Expression<String>? authorsJson,
    Expression<String>? narratorsJson,
    Expression<String>? translatorsJson,
    Expression<String>? seriesTitle,
    Expression<double>? seriesNumber,
    Expression<String>? genresJson,
    Expression<String>? tagsJson,
    Expression<String>? description,
    Expression<String>? coverUrl,
    Expression<String>? localCoverPath,
    Expression<int>? durationMs,
    Expression<String>? durationText,
    Expression<int>? publishedYear,
    Expression<int>? audioYear,
    Expression<double>? ratingValue,
    Expression<int>? ratingCount,
    Expression<String>? accessType,
    Expression<String>? playbackAccess,
    Expression<bool>? isFull,
    Expression<bool>? isFragment,
    Expression<bool>? isPaid,
    Expression<bool>? isSubscription,
    Expression<bool>? isAccessibleForFree,
    Expression<bool>? canStream,
    Expression<bool>? canDownload,
    Expression<String>? rawSourceDataJson,
    Expression<DateTime>? lastResolvedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceBookId != null) 'source_book_id': sourceBookId,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (title != null) 'title': title,
      if (normalizedTitle != null) 'normalized_title': normalizedTitle,
      if (authorsJson != null) 'authors_json': authorsJson,
      if (narratorsJson != null) 'narrators_json': narratorsJson,
      if (translatorsJson != null) 'translators_json': translatorsJson,
      if (seriesTitle != null) 'series_title': seriesTitle,
      if (seriesNumber != null) 'series_number': seriesNumber,
      if (genresJson != null) 'genres_json': genresJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (description != null) 'description': description,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (localCoverPath != null) 'local_cover_path': localCoverPath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (durationText != null) 'duration_text': durationText,
      if (publishedYear != null) 'published_year': publishedYear,
      if (audioYear != null) 'audio_year': audioYear,
      if (ratingValue != null) 'rating_value': ratingValue,
      if (ratingCount != null) 'rating_count': ratingCount,
      if (accessType != null) 'access_type': accessType,
      if (playbackAccess != null) 'playback_access': playbackAccess,
      if (isFull != null) 'is_full': isFull,
      if (isFragment != null) 'is_fragment': isFragment,
      if (isPaid != null) 'is_paid': isPaid,
      if (isSubscription != null) 'is_subscription': isSubscription,
      if (isAccessibleForFree != null)
        'is_accessible_for_free': isAccessibleForFree,
      if (canStream != null) 'can_stream': canStream,
      if (canDownload != null) 'can_download': canDownload,
      if (rawSourceDataJson != null) 'raw_source_data_json': rawSourceDataJson,
      if (lastResolvedAt != null) 'last_resolved_at': lastResolvedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookVersionsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<String>? sourceBookId,
    Value<String?>? sourceUrl,
    Value<String>? title,
    Value<String>? normalizedTitle,
    Value<String>? authorsJson,
    Value<String>? narratorsJson,
    Value<String>? translatorsJson,
    Value<String?>? seriesTitle,
    Value<double?>? seriesNumber,
    Value<String>? genresJson,
    Value<String>? tagsJson,
    Value<String?>? description,
    Value<String?>? coverUrl,
    Value<String?>? localCoverPath,
    Value<int?>? durationMs,
    Value<String?>? durationText,
    Value<int?>? publishedYear,
    Value<int?>? audioYear,
    Value<double?>? ratingValue,
    Value<int?>? ratingCount,
    Value<String>? accessType,
    Value<String>? playbackAccess,
    Value<bool>? isFull,
    Value<bool>? isFragment,
    Value<bool>? isPaid,
    Value<bool>? isSubscription,
    Value<bool>? isAccessibleForFree,
    Value<bool>? canStream,
    Value<bool>? canDownload,
    Value<String?>? rawSourceDataJson,
    Value<DateTime?>? lastResolvedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookVersionsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      sourceBookId: sourceBookId ?? this.sourceBookId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      title: title ?? this.title,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      authorsJson: authorsJson ?? this.authorsJson,
      narratorsJson: narratorsJson ?? this.narratorsJson,
      translatorsJson: translatorsJson ?? this.translatorsJson,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      genresJson: genresJson ?? this.genresJson,
      tagsJson: tagsJson ?? this.tagsJson,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      durationMs: durationMs ?? this.durationMs,
      durationText: durationText ?? this.durationText,
      publishedYear: publishedYear ?? this.publishedYear,
      audioYear: audioYear ?? this.audioYear,
      ratingValue: ratingValue ?? this.ratingValue,
      ratingCount: ratingCount ?? this.ratingCount,
      accessType: accessType ?? this.accessType,
      playbackAccess: playbackAccess ?? this.playbackAccess,
      isFull: isFull ?? this.isFull,
      isFragment: isFragment ?? this.isFragment,
      isPaid: isPaid ?? this.isPaid,
      isSubscription: isSubscription ?? this.isSubscription,
      isAccessibleForFree: isAccessibleForFree ?? this.isAccessibleForFree,
      canStream: canStream ?? this.canStream,
      canDownload: canDownload ?? this.canDownload,
      rawSourceDataJson: rawSourceDataJson ?? this.rawSourceDataJson,
      lastResolvedAt: lastResolvedAt ?? this.lastResolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceBookId.present) {
      map['source_book_id'] = Variable<String>(sourceBookId.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (normalizedTitle.present) {
      map['normalized_title'] = Variable<String>(normalizedTitle.value);
    }
    if (authorsJson.present) {
      map['authors_json'] = Variable<String>(authorsJson.value);
    }
    if (narratorsJson.present) {
      map['narrators_json'] = Variable<String>(narratorsJson.value);
    }
    if (translatorsJson.present) {
      map['translators_json'] = Variable<String>(translatorsJson.value);
    }
    if (seriesTitle.present) {
      map['series_title'] = Variable<String>(seriesTitle.value);
    }
    if (seriesNumber.present) {
      map['series_number'] = Variable<double>(seriesNumber.value);
    }
    if (genresJson.present) {
      map['genres_json'] = Variable<String>(genresJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (localCoverPath.present) {
      map['local_cover_path'] = Variable<String>(localCoverPath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (durationText.present) {
      map['duration_text'] = Variable<String>(durationText.value);
    }
    if (publishedYear.present) {
      map['published_year'] = Variable<int>(publishedYear.value);
    }
    if (audioYear.present) {
      map['audio_year'] = Variable<int>(audioYear.value);
    }
    if (ratingValue.present) {
      map['rating_value'] = Variable<double>(ratingValue.value);
    }
    if (ratingCount.present) {
      map['rating_count'] = Variable<int>(ratingCount.value);
    }
    if (accessType.present) {
      map['access_type'] = Variable<String>(accessType.value);
    }
    if (playbackAccess.present) {
      map['playback_access'] = Variable<String>(playbackAccess.value);
    }
    if (isFull.present) {
      map['is_full'] = Variable<bool>(isFull.value);
    }
    if (isFragment.present) {
      map['is_fragment'] = Variable<bool>(isFragment.value);
    }
    if (isPaid.present) {
      map['is_paid'] = Variable<bool>(isPaid.value);
    }
    if (isSubscription.present) {
      map['is_subscription'] = Variable<bool>(isSubscription.value);
    }
    if (isAccessibleForFree.present) {
      map['is_accessible_for_free'] = Variable<bool>(isAccessibleForFree.value);
    }
    if (canStream.present) {
      map['can_stream'] = Variable<bool>(canStream.value);
    }
    if (canDownload.present) {
      map['can_download'] = Variable<bool>(canDownload.value);
    }
    if (rawSourceDataJson.present) {
      map['raw_source_data_json'] = Variable<String>(rawSourceDataJson.value);
    }
    if (lastResolvedAt.present) {
      map['last_resolved_at'] = Variable<DateTime>(lastResolvedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('BookVersionsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('title: $title, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('authorsJson: $authorsJson, ')
          ..write('narratorsJson: $narratorsJson, ')
          ..write('translatorsJson: $translatorsJson, ')
          ..write('seriesTitle: $seriesTitle, ')
          ..write('seriesNumber: $seriesNumber, ')
          ..write('genresJson: $genresJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('description: $description, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('localCoverPath: $localCoverPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('durationText: $durationText, ')
          ..write('publishedYear: $publishedYear, ')
          ..write('audioYear: $audioYear, ')
          ..write('ratingValue: $ratingValue, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('accessType: $accessType, ')
          ..write('playbackAccess: $playbackAccess, ')
          ..write('isFull: $isFull, ')
          ..write('isFragment: $isFragment, ')
          ..write('isPaid: $isPaid, ')
          ..write('isSubscription: $isSubscription, ')
          ..write('isAccessibleForFree: $isAccessibleForFree, ')
          ..write('canStream: $canStream, ')
          ..write('canDownload: $canDownload, ')
          ..write('rawSourceDataJson: $rawSourceDataJson, ')
          ..write('lastResolvedAt: $lastResolvedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters
    with TableInfo<$ChaptersTable, ChapterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookVersionIdMeta = const VerificationMeta(
    'bookVersionId',
  );
  @override
  late final GeneratedColumn<String> bookVersionId = GeneratedColumn<String>(
    'book_version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceBookIdMeta = const VerificationMeta(
    'sourceBookId',
  );
  @override
  late final GeneratedColumn<String> sourceBookId = GeneratedColumn<String>(
    'source_book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceChapterIdMeta = const VerificationMeta(
    'sourceChapterId',
  );
  @override
  late final GeneratedColumn<String> sourceChapterId = GeneratedColumn<String>(
    'source_chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _indexMeta = const VerificationMeta('index');
  @override
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
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
  static const VerificationMeta _normalizedTitleMeta = const VerificationMeta(
    'normalizedTitle',
  );
  @override
  late final GeneratedColumn<String> normalizedTitle = GeneratedColumn<String>(
    'normalized_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamRefMeta = const VerificationMeta(
    'streamRef',
  );
  @override
  late final GeneratedColumn<String> streamRef = GeneratedColumn<String>(
    'stream_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedStreamUrlMeta = const VerificationMeta(
    'cachedStreamUrl',
  );
  @override
  late final GeneratedColumn<String> cachedStreamUrl = GeneratedColumn<String>(
    'cached_stream_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedStreamUrlUpdatedAtMeta =
      const VerificationMeta('cachedStreamUrlUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> cachedStreamUrlUpdatedAt =
      GeneratedColumn<DateTime>(
        'cached_stream_url_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cachedStreamUrlExpiresAtMeta =
      const VerificationMeta('cachedStreamUrlExpiresAt');
  @override
  late final GeneratedColumn<DateTime> cachedStreamUrlExpiresAt =
      GeneratedColumn<DateTime>(
        'cached_stream_url_expires_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _audioFormatMeta = const VerificationMeta(
    'audioFormat',
  );
  @override
  late final GeneratedColumn<String> audioFormat = GeneratedColumn<String>(
    'audio_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawSourceDataJsonMeta = const VerificationMeta(
    'rawSourceDataJson',
  );
  @override
  late final GeneratedColumn<String> rawSourceDataJson =
      GeneratedColumn<String>(
        'raw_source_data_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadStatusMeta = const VerificationMeta(
    'downloadStatus',
  );
  @override
  late final GeneratedColumn<String> downloadStatus = GeneratedColumn<String>(
    'download_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _downloadProgressMeta = const VerificationMeta(
    'downloadProgress',
  );
  @override
  late final GeneratedColumn<double> downloadProgress = GeneratedColumn<double>(
    'download_progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playbackPositionMsMeta =
      const VerificationMeta('playbackPositionMs');
  @override
  late final GeneratedColumn<int> playbackPositionMs = GeneratedColumn<int>(
    'playback_position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFinishedMeta = const VerificationMeta(
    'isFinished',
  );
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
    'is_finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookVersionId,
    sourceId,
    sourceBookId,
    sourceChapterId,
    index,
    title,
    normalizedTitle,
    durationMs,
    streamRef,
    cachedStreamUrl,
    cachedStreamUrlUpdatedAt,
    cachedStreamUrlExpiresAt,
    audioFormat,
    mimeType,
    rawSourceDataJson,
    localPath,
    fileSizeBytes,
    downloadStatus,
    downloadProgress,
    playbackPositionMs,
    isFinished,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_version_id')) {
      context.handle(
        _bookVersionIdMeta,
        bookVersionId.isAcceptableOrUnknown(
          data['book_version_id']!,
          _bookVersionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookVersionIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_book_id')) {
      context.handle(
        _sourceBookIdMeta,
        sourceBookId.isAcceptableOrUnknown(
          data['source_book_id']!,
          _sourceBookIdMeta,
        ),
      );
    }
    if (data.containsKey('source_chapter_id')) {
      context.handle(
        _sourceChapterIdMeta,
        sourceChapterId.isAcceptableOrUnknown(
          data['source_chapter_id']!,
          _sourceChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('index')) {
      context.handle(
        _indexMeta,
        index.isAcceptableOrUnknown(data['index']!, _indexMeta),
      );
    } else if (isInserting) {
      context.missing(_indexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('normalized_title')) {
      context.handle(
        _normalizedTitleMeta,
        normalizedTitle.isAcceptableOrUnknown(
          data['normalized_title']!,
          _normalizedTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedTitleMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('stream_ref')) {
      context.handle(
        _streamRefMeta,
        streamRef.isAcceptableOrUnknown(data['stream_ref']!, _streamRefMeta),
      );
    }
    if (data.containsKey('cached_stream_url')) {
      context.handle(
        _cachedStreamUrlMeta,
        cachedStreamUrl.isAcceptableOrUnknown(
          data['cached_stream_url']!,
          _cachedStreamUrlMeta,
        ),
      );
    }
    if (data.containsKey('cached_stream_url_updated_at')) {
      context.handle(
        _cachedStreamUrlUpdatedAtMeta,
        cachedStreamUrlUpdatedAt.isAcceptableOrUnknown(
          data['cached_stream_url_updated_at']!,
          _cachedStreamUrlUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_stream_url_expires_at')) {
      context.handle(
        _cachedStreamUrlExpiresAtMeta,
        cachedStreamUrlExpiresAt.isAcceptableOrUnknown(
          data['cached_stream_url_expires_at']!,
          _cachedStreamUrlExpiresAtMeta,
        ),
      );
    }
    if (data.containsKey('audio_format')) {
      context.handle(
        _audioFormatMeta,
        audioFormat.isAcceptableOrUnknown(
          data['audio_format']!,
          _audioFormatMeta,
        ),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('raw_source_data_json')) {
      context.handle(
        _rawSourceDataJsonMeta,
        rawSourceDataJson.isAcceptableOrUnknown(
          data['raw_source_data_json']!,
          _rawSourceDataJsonMeta,
        ),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('download_status')) {
      context.handle(
        _downloadStatusMeta,
        downloadStatus.isAcceptableOrUnknown(
          data['download_status']!,
          _downloadStatusMeta,
        ),
      );
    }
    if (data.containsKey('download_progress')) {
      context.handle(
        _downloadProgressMeta,
        downloadProgress.isAcceptableOrUnknown(
          data['download_progress']!,
          _downloadProgressMeta,
        ),
      );
    }
    if (data.containsKey('playback_position_ms')) {
      context.handle(
        _playbackPositionMsMeta,
        playbackPositionMs.isAcceptableOrUnknown(
          data['playback_position_ms']!,
          _playbackPositionMsMeta,
        ),
      );
    }
    if (data.containsKey('is_finished')) {
      context.handle(
        _isFinishedMeta,
        isFinished.isAcceptableOrUnknown(data['is_finished']!, _isFinishedMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChapterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_version_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_book_id'],
      ),
      sourceChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_chapter_id'],
      ),
      index: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      normalizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_title'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      streamRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_ref'],
      ),
      cachedStreamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cached_stream_url'],
      ),
      cachedStreamUrlUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_stream_url_updated_at'],
      ),
      cachedStreamUrlExpiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_stream_url_expires_at'],
      ),
      audioFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_format'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      rawSourceDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_source_data_json'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      ),
      downloadStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_status'],
      )!,
      downloadProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}download_progress'],
      )!,
      playbackPositionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playback_position_ms'],
      )!,
      isFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finished'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class ChapterRow extends DataClass implements Insertable<ChapterRow> {
  final String id;
  final String bookVersionId;
  final String sourceId;
  final String? sourceBookId;
  final String? sourceChapterId;
  final int index;
  final String title;
  final String normalizedTitle;
  final int? durationMs;
  final String? streamRef;
  final String? cachedStreamUrl;
  final DateTime? cachedStreamUrlUpdatedAt;
  final DateTime? cachedStreamUrlExpiresAt;
  final String? audioFormat;
  final String? mimeType;
  final String? rawSourceDataJson;
  final String? localPath;
  final int? fileSizeBytes;
  final String downloadStatus;
  final double downloadProgress;
  final int playbackPositionMs;
  final bool isFinished;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChapterRow({
    required this.id,
    required this.bookVersionId,
    required this.sourceId,
    this.sourceBookId,
    this.sourceChapterId,
    required this.index,
    required this.title,
    required this.normalizedTitle,
    this.durationMs,
    this.streamRef,
    this.cachedStreamUrl,
    this.cachedStreamUrlUpdatedAt,
    this.cachedStreamUrlExpiresAt,
    this.audioFormat,
    this.mimeType,
    this.rawSourceDataJson,
    this.localPath,
    this.fileSizeBytes,
    required this.downloadStatus,
    required this.downloadProgress,
    required this.playbackPositionMs,
    required this.isFinished,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_version_id'] = Variable<String>(bookVersionId);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || sourceBookId != null) {
      map['source_book_id'] = Variable<String>(sourceBookId);
    }
    if (!nullToAbsent || sourceChapterId != null) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId);
    }
    map['index'] = Variable<int>(index);
    map['title'] = Variable<String>(title);
    map['normalized_title'] = Variable<String>(normalizedTitle);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || streamRef != null) {
      map['stream_ref'] = Variable<String>(streamRef);
    }
    if (!nullToAbsent || cachedStreamUrl != null) {
      map['cached_stream_url'] = Variable<String>(cachedStreamUrl);
    }
    if (!nullToAbsent || cachedStreamUrlUpdatedAt != null) {
      map['cached_stream_url_updated_at'] = Variable<DateTime>(
        cachedStreamUrlUpdatedAt,
      );
    }
    if (!nullToAbsent || cachedStreamUrlExpiresAt != null) {
      map['cached_stream_url_expires_at'] = Variable<DateTime>(
        cachedStreamUrlExpiresAt,
      );
    }
    if (!nullToAbsent || audioFormat != null) {
      map['audio_format'] = Variable<String>(audioFormat);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || rawSourceDataJson != null) {
      map['raw_source_data_json'] = Variable<String>(rawSourceDataJson);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    map['download_status'] = Variable<String>(downloadStatus);
    map['download_progress'] = Variable<double>(downloadProgress);
    map['playback_position_ms'] = Variable<int>(playbackPositionMs);
    map['is_finished'] = Variable<bool>(isFinished);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      bookVersionId: Value(bookVersionId),
      sourceId: Value(sourceId),
      sourceBookId: sourceBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceBookId),
      sourceChapterId: sourceChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceChapterId),
      index: Value(index),
      title: Value(title),
      normalizedTitle: Value(normalizedTitle),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      streamRef: streamRef == null && nullToAbsent
          ? const Value.absent()
          : Value(streamRef),
      cachedStreamUrl: cachedStreamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedStreamUrl),
      cachedStreamUrlUpdatedAt: cachedStreamUrlUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedStreamUrlUpdatedAt),
      cachedStreamUrlExpiresAt: cachedStreamUrlExpiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedStreamUrlExpiresAt),
      audioFormat: audioFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFormat),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      rawSourceDataJson: rawSourceDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawSourceDataJson),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      downloadStatus: Value(downloadStatus),
      downloadProgress: Value(downloadProgress),
      playbackPositionMs: Value(playbackPositionMs),
      isFinished: Value(isFinished),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterRow(
      id: serializer.fromJson<String>(json['id']),
      bookVersionId: serializer.fromJson<String>(json['bookVersionId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceBookId: serializer.fromJson<String?>(json['sourceBookId']),
      sourceChapterId: serializer.fromJson<String?>(json['sourceChapterId']),
      index: serializer.fromJson<int>(json['index']),
      title: serializer.fromJson<String>(json['title']),
      normalizedTitle: serializer.fromJson<String>(json['normalizedTitle']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      streamRef: serializer.fromJson<String?>(json['streamRef']),
      cachedStreamUrl: serializer.fromJson<String?>(json['cachedStreamUrl']),
      cachedStreamUrlUpdatedAt: serializer.fromJson<DateTime?>(
        json['cachedStreamUrlUpdatedAt'],
      ),
      cachedStreamUrlExpiresAt: serializer.fromJson<DateTime?>(
        json['cachedStreamUrlExpiresAt'],
      ),
      audioFormat: serializer.fromJson<String?>(json['audioFormat']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      rawSourceDataJson: serializer.fromJson<String?>(
        json['rawSourceDataJson'],
      ),
      localPath: serializer.fromJson<String?>(json['localPath']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      downloadStatus: serializer.fromJson<String>(json['downloadStatus']),
      downloadProgress: serializer.fromJson<double>(json['downloadProgress']),
      playbackPositionMs: serializer.fromJson<int>(json['playbackPositionMs']),
      isFinished: serializer.fromJson<bool>(json['isFinished']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookVersionId': serializer.toJson<String>(bookVersionId),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceBookId': serializer.toJson<String?>(sourceBookId),
      'sourceChapterId': serializer.toJson<String?>(sourceChapterId),
      'index': serializer.toJson<int>(index),
      'title': serializer.toJson<String>(title),
      'normalizedTitle': serializer.toJson<String>(normalizedTitle),
      'durationMs': serializer.toJson<int?>(durationMs),
      'streamRef': serializer.toJson<String?>(streamRef),
      'cachedStreamUrl': serializer.toJson<String?>(cachedStreamUrl),
      'cachedStreamUrlUpdatedAt': serializer.toJson<DateTime?>(
        cachedStreamUrlUpdatedAt,
      ),
      'cachedStreamUrlExpiresAt': serializer.toJson<DateTime?>(
        cachedStreamUrlExpiresAt,
      ),
      'audioFormat': serializer.toJson<String?>(audioFormat),
      'mimeType': serializer.toJson<String?>(mimeType),
      'rawSourceDataJson': serializer.toJson<String?>(rawSourceDataJson),
      'localPath': serializer.toJson<String?>(localPath),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'downloadStatus': serializer.toJson<String>(downloadStatus),
      'downloadProgress': serializer.toJson<double>(downloadProgress),
      'playbackPositionMs': serializer.toJson<int>(playbackPositionMs),
      'isFinished': serializer.toJson<bool>(isFinished),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChapterRow copyWith({
    String? id,
    String? bookVersionId,
    String? sourceId,
    Value<String?> sourceBookId = const Value.absent(),
    Value<String?> sourceChapterId = const Value.absent(),
    int? index,
    String? title,
    String? normalizedTitle,
    Value<int?> durationMs = const Value.absent(),
    Value<String?> streamRef = const Value.absent(),
    Value<String?> cachedStreamUrl = const Value.absent(),
    Value<DateTime?> cachedStreamUrlUpdatedAt = const Value.absent(),
    Value<DateTime?> cachedStreamUrlExpiresAt = const Value.absent(),
    Value<String?> audioFormat = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<String?> rawSourceDataJson = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<int?> fileSizeBytes = const Value.absent(),
    String? downloadStatus,
    double? downloadProgress,
    int? playbackPositionMs,
    bool? isFinished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChapterRow(
    id: id ?? this.id,
    bookVersionId: bookVersionId ?? this.bookVersionId,
    sourceId: sourceId ?? this.sourceId,
    sourceBookId: sourceBookId.present ? sourceBookId.value : this.sourceBookId,
    sourceChapterId: sourceChapterId.present
        ? sourceChapterId.value
        : this.sourceChapterId,
    index: index ?? this.index,
    title: title ?? this.title,
    normalizedTitle: normalizedTitle ?? this.normalizedTitle,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    streamRef: streamRef.present ? streamRef.value : this.streamRef,
    cachedStreamUrl: cachedStreamUrl.present
        ? cachedStreamUrl.value
        : this.cachedStreamUrl,
    cachedStreamUrlUpdatedAt: cachedStreamUrlUpdatedAt.present
        ? cachedStreamUrlUpdatedAt.value
        : this.cachedStreamUrlUpdatedAt,
    cachedStreamUrlExpiresAt: cachedStreamUrlExpiresAt.present
        ? cachedStreamUrlExpiresAt.value
        : this.cachedStreamUrlExpiresAt,
    audioFormat: audioFormat.present ? audioFormat.value : this.audioFormat,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    rawSourceDataJson: rawSourceDataJson.present
        ? rawSourceDataJson.value
        : this.rawSourceDataJson,
    localPath: localPath.present ? localPath.value : this.localPath,
    fileSizeBytes: fileSizeBytes.present
        ? fileSizeBytes.value
        : this.fileSizeBytes,
    downloadStatus: downloadStatus ?? this.downloadStatus,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
    isFinished: isFinished ?? this.isFinished,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChapterRow copyWithCompanion(ChaptersCompanion data) {
    return ChapterRow(
      id: data.id.present ? data.id.value : this.id,
      bookVersionId: data.bookVersionId.present
          ? data.bookVersionId.value
          : this.bookVersionId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceBookId: data.sourceBookId.present
          ? data.sourceBookId.value
          : this.sourceBookId,
      sourceChapterId: data.sourceChapterId.present
          ? data.sourceChapterId.value
          : this.sourceChapterId,
      index: data.index.present ? data.index.value : this.index,
      title: data.title.present ? data.title.value : this.title,
      normalizedTitle: data.normalizedTitle.present
          ? data.normalizedTitle.value
          : this.normalizedTitle,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      streamRef: data.streamRef.present ? data.streamRef.value : this.streamRef,
      cachedStreamUrl: data.cachedStreamUrl.present
          ? data.cachedStreamUrl.value
          : this.cachedStreamUrl,
      cachedStreamUrlUpdatedAt: data.cachedStreamUrlUpdatedAt.present
          ? data.cachedStreamUrlUpdatedAt.value
          : this.cachedStreamUrlUpdatedAt,
      cachedStreamUrlExpiresAt: data.cachedStreamUrlExpiresAt.present
          ? data.cachedStreamUrlExpiresAt.value
          : this.cachedStreamUrlExpiresAt,
      audioFormat: data.audioFormat.present
          ? data.audioFormat.value
          : this.audioFormat,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      rawSourceDataJson: data.rawSourceDataJson.present
          ? data.rawSourceDataJson.value
          : this.rawSourceDataJson,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      downloadStatus: data.downloadStatus.present
          ? data.downloadStatus.value
          : this.downloadStatus,
      downloadProgress: data.downloadProgress.present
          ? data.downloadProgress.value
          : this.downloadProgress,
      playbackPositionMs: data.playbackPositionMs.present
          ? data.playbackPositionMs.value
          : this.playbackPositionMs,
      isFinished: data.isFinished.present
          ? data.isFinished.value
          : this.isFinished,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterRow(')
          ..write('id: $id, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('index: $index, ')
          ..write('title: $title, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('durationMs: $durationMs, ')
          ..write('streamRef: $streamRef, ')
          ..write('cachedStreamUrl: $cachedStreamUrl, ')
          ..write('cachedStreamUrlUpdatedAt: $cachedStreamUrlUpdatedAt, ')
          ..write('cachedStreamUrlExpiresAt: $cachedStreamUrlExpiresAt, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('mimeType: $mimeType, ')
          ..write('rawSourceDataJson: $rawSourceDataJson, ')
          ..write('localPath: $localPath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('downloadProgress: $downloadProgress, ')
          ..write('playbackPositionMs: $playbackPositionMs, ')
          ..write('isFinished: $isFinished, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    bookVersionId,
    sourceId,
    sourceBookId,
    sourceChapterId,
    index,
    title,
    normalizedTitle,
    durationMs,
    streamRef,
    cachedStreamUrl,
    cachedStreamUrlUpdatedAt,
    cachedStreamUrlExpiresAt,
    audioFormat,
    mimeType,
    rawSourceDataJson,
    localPath,
    fileSizeBytes,
    downloadStatus,
    downloadProgress,
    playbackPositionMs,
    isFinished,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterRow &&
          other.id == this.id &&
          other.bookVersionId == this.bookVersionId &&
          other.sourceId == this.sourceId &&
          other.sourceBookId == this.sourceBookId &&
          other.sourceChapterId == this.sourceChapterId &&
          other.index == this.index &&
          other.title == this.title &&
          other.normalizedTitle == this.normalizedTitle &&
          other.durationMs == this.durationMs &&
          other.streamRef == this.streamRef &&
          other.cachedStreamUrl == this.cachedStreamUrl &&
          other.cachedStreamUrlUpdatedAt == this.cachedStreamUrlUpdatedAt &&
          other.cachedStreamUrlExpiresAt == this.cachedStreamUrlExpiresAt &&
          other.audioFormat == this.audioFormat &&
          other.mimeType == this.mimeType &&
          other.rawSourceDataJson == this.rawSourceDataJson &&
          other.localPath == this.localPath &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.downloadStatus == this.downloadStatus &&
          other.downloadProgress == this.downloadProgress &&
          other.playbackPositionMs == this.playbackPositionMs &&
          other.isFinished == this.isFinished &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChaptersCompanion extends UpdateCompanion<ChapterRow> {
  final Value<String> id;
  final Value<String> bookVersionId;
  final Value<String> sourceId;
  final Value<String?> sourceBookId;
  final Value<String?> sourceChapterId;
  final Value<int> index;
  final Value<String> title;
  final Value<String> normalizedTitle;
  final Value<int?> durationMs;
  final Value<String?> streamRef;
  final Value<String?> cachedStreamUrl;
  final Value<DateTime?> cachedStreamUrlUpdatedAt;
  final Value<DateTime?> cachedStreamUrlExpiresAt;
  final Value<String?> audioFormat;
  final Value<String?> mimeType;
  final Value<String?> rawSourceDataJson;
  final Value<String?> localPath;
  final Value<int?> fileSizeBytes;
  final Value<String> downloadStatus;
  final Value<double> downloadProgress;
  final Value<int> playbackPositionMs;
  final Value<bool> isFinished;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.bookVersionId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceBookId = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    this.index = const Value.absent(),
    this.title = const Value.absent(),
    this.normalizedTitle = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.streamRef = const Value.absent(),
    this.cachedStreamUrl = const Value.absent(),
    this.cachedStreamUrlUpdatedAt = const Value.absent(),
    this.cachedStreamUrlExpiresAt = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.rawSourceDataJson = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.downloadProgress = const Value.absent(),
    this.playbackPositionMs = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String id,
    required String bookVersionId,
    required String sourceId,
    this.sourceBookId = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    required int index,
    required String title,
    required String normalizedTitle,
    this.durationMs = const Value.absent(),
    this.streamRef = const Value.absent(),
    this.cachedStreamUrl = const Value.absent(),
    this.cachedStreamUrlUpdatedAt = const Value.absent(),
    this.cachedStreamUrlExpiresAt = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.rawSourceDataJson = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.downloadProgress = const Value.absent(),
    this.playbackPositionMs = const Value.absent(),
    this.isFinished = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookVersionId = Value(bookVersionId),
       sourceId = Value(sourceId),
       index = Value(index),
       title = Value(title),
       normalizedTitle = Value(normalizedTitle),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ChapterRow> custom({
    Expression<String>? id,
    Expression<String>? bookVersionId,
    Expression<String>? sourceId,
    Expression<String>? sourceBookId,
    Expression<String>? sourceChapterId,
    Expression<int>? index,
    Expression<String>? title,
    Expression<String>? normalizedTitle,
    Expression<int>? durationMs,
    Expression<String>? streamRef,
    Expression<String>? cachedStreamUrl,
    Expression<DateTime>? cachedStreamUrlUpdatedAt,
    Expression<DateTime>? cachedStreamUrlExpiresAt,
    Expression<String>? audioFormat,
    Expression<String>? mimeType,
    Expression<String>? rawSourceDataJson,
    Expression<String>? localPath,
    Expression<int>? fileSizeBytes,
    Expression<String>? downloadStatus,
    Expression<double>? downloadProgress,
    Expression<int>? playbackPositionMs,
    Expression<bool>? isFinished,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookVersionId != null) 'book_version_id': bookVersionId,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceBookId != null) 'source_book_id': sourceBookId,
      if (sourceChapterId != null) 'source_chapter_id': sourceChapterId,
      if (index != null) 'index': index,
      if (title != null) 'title': title,
      if (normalizedTitle != null) 'normalized_title': normalizedTitle,
      if (durationMs != null) 'duration_ms': durationMs,
      if (streamRef != null) 'stream_ref': streamRef,
      if (cachedStreamUrl != null) 'cached_stream_url': cachedStreamUrl,
      if (cachedStreamUrlUpdatedAt != null)
        'cached_stream_url_updated_at': cachedStreamUrlUpdatedAt,
      if (cachedStreamUrlExpiresAt != null)
        'cached_stream_url_expires_at': cachedStreamUrlExpiresAt,
      if (audioFormat != null) 'audio_format': audioFormat,
      if (mimeType != null) 'mime_type': mimeType,
      if (rawSourceDataJson != null) 'raw_source_data_json': rawSourceDataJson,
      if (localPath != null) 'local_path': localPath,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (downloadStatus != null) 'download_status': downloadStatus,
      if (downloadProgress != null) 'download_progress': downloadProgress,
      if (playbackPositionMs != null)
        'playback_position_ms': playbackPositionMs,
      if (isFinished != null) 'is_finished': isFinished,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? bookVersionId,
    Value<String>? sourceId,
    Value<String?>? sourceBookId,
    Value<String?>? sourceChapterId,
    Value<int>? index,
    Value<String>? title,
    Value<String>? normalizedTitle,
    Value<int?>? durationMs,
    Value<String?>? streamRef,
    Value<String?>? cachedStreamUrl,
    Value<DateTime?>? cachedStreamUrlUpdatedAt,
    Value<DateTime?>? cachedStreamUrlExpiresAt,
    Value<String?>? audioFormat,
    Value<String?>? mimeType,
    Value<String?>? rawSourceDataJson,
    Value<String?>? localPath,
    Value<int?>? fileSizeBytes,
    Value<String>? downloadStatus,
    Value<double>? downloadProgress,
    Value<int>? playbackPositionMs,
    Value<bool>? isFinished,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      bookVersionId: bookVersionId ?? this.bookVersionId,
      sourceId: sourceId ?? this.sourceId,
      sourceBookId: sourceBookId ?? this.sourceBookId,
      sourceChapterId: sourceChapterId ?? this.sourceChapterId,
      index: index ?? this.index,
      title: title ?? this.title,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      durationMs: durationMs ?? this.durationMs,
      streamRef: streamRef ?? this.streamRef,
      cachedStreamUrl: cachedStreamUrl ?? this.cachedStreamUrl,
      cachedStreamUrlUpdatedAt:
          cachedStreamUrlUpdatedAt ?? this.cachedStreamUrlUpdatedAt,
      cachedStreamUrlExpiresAt:
          cachedStreamUrlExpiresAt ?? this.cachedStreamUrlExpiresAt,
      audioFormat: audioFormat ?? this.audioFormat,
      mimeType: mimeType ?? this.mimeType,
      rawSourceDataJson: rawSourceDataJson ?? this.rawSourceDataJson,
      localPath: localPath ?? this.localPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      isFinished: isFinished ?? this.isFinished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookVersionId.present) {
      map['book_version_id'] = Variable<String>(bookVersionId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceBookId.present) {
      map['source_book_id'] = Variable<String>(sourceBookId.value);
    }
    if (sourceChapterId.present) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId.value);
    }
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (normalizedTitle.present) {
      map['normalized_title'] = Variable<String>(normalizedTitle.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (streamRef.present) {
      map['stream_ref'] = Variable<String>(streamRef.value);
    }
    if (cachedStreamUrl.present) {
      map['cached_stream_url'] = Variable<String>(cachedStreamUrl.value);
    }
    if (cachedStreamUrlUpdatedAt.present) {
      map['cached_stream_url_updated_at'] = Variable<DateTime>(
        cachedStreamUrlUpdatedAt.value,
      );
    }
    if (cachedStreamUrlExpiresAt.present) {
      map['cached_stream_url_expires_at'] = Variable<DateTime>(
        cachedStreamUrlExpiresAt.value,
      );
    }
    if (audioFormat.present) {
      map['audio_format'] = Variable<String>(audioFormat.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (rawSourceDataJson.present) {
      map['raw_source_data_json'] = Variable<String>(rawSourceDataJson.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (downloadStatus.present) {
      map['download_status'] = Variable<String>(downloadStatus.value);
    }
    if (downloadProgress.present) {
      map['download_progress'] = Variable<double>(downloadProgress.value);
    }
    if (playbackPositionMs.present) {
      map['playback_position_ms'] = Variable<int>(playbackPositionMs.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('index: $index, ')
          ..write('title: $title, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('durationMs: $durationMs, ')
          ..write('streamRef: $streamRef, ')
          ..write('cachedStreamUrl: $cachedStreamUrl, ')
          ..write('cachedStreamUrlUpdatedAt: $cachedStreamUrlUpdatedAt, ')
          ..write('cachedStreamUrlExpiresAt: $cachedStreamUrlExpiresAt, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('mimeType: $mimeType, ')
          ..write('rawSourceDataJson: $rawSourceDataJson, ')
          ..write('localPath: $localPath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('downloadProgress: $downloadProgress, ')
          ..write('playbackPositionMs: $playbackPositionMs, ')
          ..write('isFinished: $isFinished, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioTracksTable extends AudioTracks
    with TableInfo<$AudioTracksTable, AudioTrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indexMeta = const VerificationMeta('index');
  @override
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaRefMeta = const VerificationMeta(
    'mediaRef',
  );
  @override
  late final GeneratedColumn<String> mediaRef = GeneratedColumn<String>(
    'media_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directUrlMeta = const VerificationMeta(
    'directUrl',
  );
  @override
  late final GeneratedColumn<String> directUrl = GeneratedColumn<String>(
    'direct_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersJsonMeta = const VerificationMeta(
    'headersJson',
  );
  @override
  late final GeneratedColumn<String> headersJson = GeneratedColumn<String>(
    'headers_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawSourceDataJsonMeta = const VerificationMeta(
    'rawSourceDataJson',
  );
  @override
  late final GeneratedColumn<String> rawSourceDataJson =
      GeneratedColumn<String>(
        'raw_source_data_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chapterId,
    sourceId,
    index,
    title,
    durationMs,
    mediaRef,
    directUrl,
    headersJson,
    format,
    mimeType,
    expiresAt,
    rawSourceDataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioTrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('index')) {
      context.handle(
        _indexMeta,
        index.isAcceptableOrUnknown(data['index']!, _indexMeta),
      );
    } else if (isInserting) {
      context.missing(_indexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('media_ref')) {
      context.handle(
        _mediaRefMeta,
        mediaRef.isAcceptableOrUnknown(data['media_ref']!, _mediaRefMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaRefMeta);
    }
    if (data.containsKey('direct_url')) {
      context.handle(
        _directUrlMeta,
        directUrl.isAcceptableOrUnknown(data['direct_url']!, _directUrlMeta),
      );
    }
    if (data.containsKey('headers_json')) {
      context.handle(
        _headersJsonMeta,
        headersJson.isAcceptableOrUnknown(
          data['headers_json']!,
          _headersJsonMeta,
        ),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('raw_source_data_json')) {
      context.handle(
        _rawSourceDataJsonMeta,
        rawSourceDataJson.isAcceptableOrUnknown(
          data['raw_source_data_json']!,
          _rawSourceDataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioTrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioTrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      index: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      mediaRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_ref'],
      )!,
      directUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_url'],
      ),
      headersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers_json'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      rawSourceDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_source_data_json'],
      ),
    );
  }

  @override
  $AudioTracksTable createAlias(String alias) {
    return $AudioTracksTable(attachedDatabase, alias);
  }
}

class AudioTrackRow extends DataClass implements Insertable<AudioTrackRow> {
  final String id;
  final String chapterId;
  final String sourceId;
  final int index;
  final String? title;
  final int? durationMs;
  final String mediaRef;
  final String? directUrl;
  final String? headersJson;
  final String? format;
  final String? mimeType;
  final DateTime? expiresAt;
  final String? rawSourceDataJson;
  const AudioTrackRow({
    required this.id,
    required this.chapterId,
    required this.sourceId,
    required this.index,
    this.title,
    this.durationMs,
    required this.mediaRef,
    this.directUrl,
    this.headersJson,
    this.format,
    this.mimeType,
    this.expiresAt,
    this.rawSourceDataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chapter_id'] = Variable<String>(chapterId);
    map['source_id'] = Variable<String>(sourceId);
    map['index'] = Variable<int>(index);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['media_ref'] = Variable<String>(mediaRef);
    if (!nullToAbsent || directUrl != null) {
      map['direct_url'] = Variable<String>(directUrl);
    }
    if (!nullToAbsent || headersJson != null) {
      map['headers_json'] = Variable<String>(headersJson);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || rawSourceDataJson != null) {
      map['raw_source_data_json'] = Variable<String>(rawSourceDataJson);
    }
    return map;
  }

  AudioTracksCompanion toCompanion(bool nullToAbsent) {
    return AudioTracksCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      sourceId: Value(sourceId),
      index: Value(index),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      mediaRef: Value(mediaRef),
      directUrl: directUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(directUrl),
      headersJson: headersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(headersJson),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      rawSourceDataJson: rawSourceDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawSourceDataJson),
    );
  }

  factory AudioTrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioTrackRow(
      id: serializer.fromJson<String>(json['id']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      index: serializer.fromJson<int>(json['index']),
      title: serializer.fromJson<String?>(json['title']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      mediaRef: serializer.fromJson<String>(json['mediaRef']),
      directUrl: serializer.fromJson<String?>(json['directUrl']),
      headersJson: serializer.fromJson<String?>(json['headersJson']),
      format: serializer.fromJson<String?>(json['format']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      rawSourceDataJson: serializer.fromJson<String?>(
        json['rawSourceDataJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chapterId': serializer.toJson<String>(chapterId),
      'sourceId': serializer.toJson<String>(sourceId),
      'index': serializer.toJson<int>(index),
      'title': serializer.toJson<String?>(title),
      'durationMs': serializer.toJson<int?>(durationMs),
      'mediaRef': serializer.toJson<String>(mediaRef),
      'directUrl': serializer.toJson<String?>(directUrl),
      'headersJson': serializer.toJson<String?>(headersJson),
      'format': serializer.toJson<String?>(format),
      'mimeType': serializer.toJson<String?>(mimeType),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'rawSourceDataJson': serializer.toJson<String?>(rawSourceDataJson),
    };
  }

  AudioTrackRow copyWith({
    String? id,
    String? chapterId,
    String? sourceId,
    int? index,
    Value<String?> title = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    String? mediaRef,
    Value<String?> directUrl = const Value.absent(),
    Value<String?> headersJson = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<DateTime?> expiresAt = const Value.absent(),
    Value<String?> rawSourceDataJson = const Value.absent(),
  }) => AudioTrackRow(
    id: id ?? this.id,
    chapterId: chapterId ?? this.chapterId,
    sourceId: sourceId ?? this.sourceId,
    index: index ?? this.index,
    title: title.present ? title.value : this.title,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    mediaRef: mediaRef ?? this.mediaRef,
    directUrl: directUrl.present ? directUrl.value : this.directUrl,
    headersJson: headersJson.present ? headersJson.value : this.headersJson,
    format: format.present ? format.value : this.format,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    rawSourceDataJson: rawSourceDataJson.present
        ? rawSourceDataJson.value
        : this.rawSourceDataJson,
  );
  AudioTrackRow copyWithCompanion(AudioTracksCompanion data) {
    return AudioTrackRow(
      id: data.id.present ? data.id.value : this.id,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      index: data.index.present ? data.index.value : this.index,
      title: data.title.present ? data.title.value : this.title,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      mediaRef: data.mediaRef.present ? data.mediaRef.value : this.mediaRef,
      directUrl: data.directUrl.present ? data.directUrl.value : this.directUrl,
      headersJson: data.headersJson.present
          ? data.headersJson.value
          : this.headersJson,
      format: data.format.present ? data.format.value : this.format,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      rawSourceDataJson: data.rawSourceDataJson.present
          ? data.rawSourceDataJson.value
          : this.rawSourceDataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioTrackRow(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('sourceId: $sourceId, ')
          ..write('index: $index, ')
          ..write('title: $title, ')
          ..write('durationMs: $durationMs, ')
          ..write('mediaRef: $mediaRef, ')
          ..write('directUrl: $directUrl, ')
          ..write('headersJson: $headersJson, ')
          ..write('format: $format, ')
          ..write('mimeType: $mimeType, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rawSourceDataJson: $rawSourceDataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chapterId,
    sourceId,
    index,
    title,
    durationMs,
    mediaRef,
    directUrl,
    headersJson,
    format,
    mimeType,
    expiresAt,
    rawSourceDataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioTrackRow &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.sourceId == this.sourceId &&
          other.index == this.index &&
          other.title == this.title &&
          other.durationMs == this.durationMs &&
          other.mediaRef == this.mediaRef &&
          other.directUrl == this.directUrl &&
          other.headersJson == this.headersJson &&
          other.format == this.format &&
          other.mimeType == this.mimeType &&
          other.expiresAt == this.expiresAt &&
          other.rawSourceDataJson == this.rawSourceDataJson);
}

class AudioTracksCompanion extends UpdateCompanion<AudioTrackRow> {
  final Value<String> id;
  final Value<String> chapterId;
  final Value<String> sourceId;
  final Value<int> index;
  final Value<String?> title;
  final Value<int?> durationMs;
  final Value<String> mediaRef;
  final Value<String?> directUrl;
  final Value<String?> headersJson;
  final Value<String?> format;
  final Value<String?> mimeType;
  final Value<DateTime?> expiresAt;
  final Value<String?> rawSourceDataJson;
  final Value<int> rowid;
  const AudioTracksCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.index = const Value.absent(),
    this.title = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.mediaRef = const Value.absent(),
    this.directUrl = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.format = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rawSourceDataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioTracksCompanion.insert({
    required String id,
    required String chapterId,
    required String sourceId,
    required int index,
    this.title = const Value.absent(),
    this.durationMs = const Value.absent(),
    required String mediaRef,
    this.directUrl = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.format = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rawSourceDataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chapterId = Value(chapterId),
       sourceId = Value(sourceId),
       index = Value(index),
       mediaRef = Value(mediaRef);
  static Insertable<AudioTrackRow> custom({
    Expression<String>? id,
    Expression<String>? chapterId,
    Expression<String>? sourceId,
    Expression<int>? index,
    Expression<String>? title,
    Expression<int>? durationMs,
    Expression<String>? mediaRef,
    Expression<String>? directUrl,
    Expression<String>? headersJson,
    Expression<String>? format,
    Expression<String>? mimeType,
    Expression<DateTime>? expiresAt,
    Expression<String>? rawSourceDataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (sourceId != null) 'source_id': sourceId,
      if (index != null) 'index': index,
      if (title != null) 'title': title,
      if (durationMs != null) 'duration_ms': durationMs,
      if (mediaRef != null) 'media_ref': mediaRef,
      if (directUrl != null) 'direct_url': directUrl,
      if (headersJson != null) 'headers_json': headersJson,
      if (format != null) 'format': format,
      if (mimeType != null) 'mime_type': mimeType,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rawSourceDataJson != null) 'raw_source_data_json': rawSourceDataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioTracksCompanion copyWith({
    Value<String>? id,
    Value<String>? chapterId,
    Value<String>? sourceId,
    Value<int>? index,
    Value<String?>? title,
    Value<int?>? durationMs,
    Value<String>? mediaRef,
    Value<String?>? directUrl,
    Value<String?>? headersJson,
    Value<String?>? format,
    Value<String?>? mimeType,
    Value<DateTime?>? expiresAt,
    Value<String?>? rawSourceDataJson,
    Value<int>? rowid,
  }) {
    return AudioTracksCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      sourceId: sourceId ?? this.sourceId,
      index: index ?? this.index,
      title: title ?? this.title,
      durationMs: durationMs ?? this.durationMs,
      mediaRef: mediaRef ?? this.mediaRef,
      directUrl: directUrl ?? this.directUrl,
      headersJson: headersJson ?? this.headersJson,
      format: format ?? this.format,
      mimeType: mimeType ?? this.mimeType,
      expiresAt: expiresAt ?? this.expiresAt,
      rawSourceDataJson: rawSourceDataJson ?? this.rawSourceDataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (mediaRef.present) {
      map['media_ref'] = Variable<String>(mediaRef.value);
    }
    if (directUrl.present) {
      map['direct_url'] = Variable<String>(directUrl.value);
    }
    if (headersJson.present) {
      map['headers_json'] = Variable<String>(headersJson.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rawSourceDataJson.present) {
      map['raw_source_data_json'] = Variable<String>(rawSourceDataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioTracksCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('sourceId: $sourceId, ')
          ..write('index: $index, ')
          ..write('title: $title, ')
          ..write('durationMs: $durationMs, ')
          ..write('mediaRef: $mediaRef, ')
          ..write('directUrl: $directUrl, ')
          ..write('headersJson: $headersJson, ')
          ..write('format: $format, ')
          ..write('mimeType: $mimeType, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rawSourceDataJson: $rawSourceDataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourcesTable extends Sources with TableInfo<$SourcesTable, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    host,
    color,
    capabilitiesJson,
    isEnabled,
    priority,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final String id;
  final String name;
  final String host;
  final String? color;
  final String capabilitiesJson;
  final bool isEnabled;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SourceRow({
    required this.id,
    required this.name,
    required this.host,
    this.color,
    required this.capabilitiesJson,
    required this.isEnabled,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['host'] = Variable<String>(host);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['priority'] = Variable<int>(priority);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      name: Value(name),
      host: Value(host),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      capabilitiesJson: Value(capabilitiesJson),
      isEnabled: Value(isEnabled),
      priority: Value(priority),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      host: serializer.fromJson<String>(json['host']),
      color: serializer.fromJson<String?>(json['color']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      priority: serializer.fromJson<int>(json['priority']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'host': serializer.toJson<String>(host),
      'color': serializer.toJson<String?>(color),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'priority': serializer.toJson<int>(priority),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SourceRow copyWith({
    String? id,
    String? name,
    String? host,
    Value<String?> color = const Value.absent(),
    String? capabilitiesJson,
    bool? isEnabled,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SourceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    host: host ?? this.host,
    color: color.present ? color.value : this.color,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    isEnabled: isEnabled ?? this.isEnabled,
    priority: priority ?? this.priority,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      host: data.host.present ? data.host.value : this.host,
      color: data.color.present ? data.color.value : this.color,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('color: $color, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    host,
    color,
    capabilitiesJson,
    isEnabled,
    priority,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.host == this.host &&
          other.color == this.color &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.isEnabled == this.isEnabled &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> host;
  final Value<String?> color;
  final Value<String> capabilitiesJson;
  final Value<bool> isEnabled;
  final Value<int> priority;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.host = const Value.absent(),
    this.color = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required String name,
    required String host,
    this.color = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.priority = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       host = Value(host),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SourceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? host,
    Expression<String>? color,
    Expression<String>? capabilitiesJson,
    Expression<bool>? isEnabled,
    Expression<int>? priority,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (host != null) 'host': host,
      if (color != null) 'color': color,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? host,
    Value<String?>? color,
    Value<String>? capabilitiesJson,
    Value<bool>? isEnabled,
    Value<int>? priority,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      color: color ?? this.color,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('color: $color, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceHealthRowsTable extends SourceHealthRows
    with TableInfo<$SourceHealthRowsTable, SourceHealthRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceHealthRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    status,
    latencyMs,
    errorCode,
    errorMessage,
    checkedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_health';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceHealthRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId};
  @override
  SourceHealthRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceHealthRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $SourceHealthRowsTable createAlias(String alias) {
    return $SourceHealthRowsTable(attachedDatabase, alias);
  }
}

class SourceHealthRow extends DataClass implements Insertable<SourceHealthRow> {
  final String sourceId;
  final String status;
  final int? latencyMs;
  final String? errorCode;
  final String? errorMessage;
  final DateTime checkedAt;
  const SourceHealthRow({
    required this.sourceId,
    required this.status,
    this.latencyMs,
    this.errorCode,
    this.errorMessage,
    required this.checkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['checked_at'] = Variable<DateTime>(checkedAt);
    return map;
  }

  SourceHealthRowsCompanion toCompanion(bool nullToAbsent) {
    return SourceHealthRowsCompanion(
      sourceId: Value(sourceId),
      status: Value(status),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      checkedAt: Value(checkedAt),
    );
  }

  factory SourceHealthRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceHealthRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      status: serializer.fromJson<String>(json['status']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'status': serializer.toJson<String>(status),
      'latencyMs': serializer.toJson<int?>(latencyMs),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
    };
  }

  SourceHealthRow copyWith({
    String? sourceId,
    String? status,
    Value<int?> latencyMs = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? checkedAt,
  }) => SourceHealthRow(
    sourceId: sourceId ?? this.sourceId,
    status: status ?? this.status,
    latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    checkedAt: checkedAt ?? this.checkedAt,
  );
  SourceHealthRow copyWithCompanion(SourceHealthRowsCompanion data) {
    return SourceHealthRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      status: data.status.present ? data.status.value : this.status,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceHealthRow(')
          ..write('sourceId: $sourceId, ')
          ..write('status: $status, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    status,
    latencyMs,
    errorCode,
    errorMessage,
    checkedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceHealthRow &&
          other.sourceId == this.sourceId &&
          other.status == this.status &&
          other.latencyMs == this.latencyMs &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.checkedAt == this.checkedAt);
}

class SourceHealthRowsCompanion extends UpdateCompanion<SourceHealthRow> {
  final Value<String> sourceId;
  final Value<String> status;
  final Value<int?> latencyMs;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<DateTime> checkedAt;
  final Value<int> rowid;
  const SourceHealthRowsCompanion({
    this.sourceId = const Value.absent(),
    this.status = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceHealthRowsCompanion.insert({
    required String sourceId,
    this.status = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime checkedAt,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       checkedAt = Value(checkedAt);
  static Insertable<SourceHealthRow> custom({
    Expression<String>? sourceId,
    Expression<String>? status,
    Expression<int>? latencyMs,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<DateTime>? checkedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (status != null) 'status': status,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceHealthRowsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? status,
    Value<int?>? latencyMs,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<DateTime>? checkedAt,
    Value<int>? rowid,
  }) {
    return SourceHealthRowsCompanion(
      sourceId: sourceId ?? this.sourceId,
      status: status ?? this.status,
      latencyMs: latencyMs ?? this.latencyMs,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      checkedAt: checkedAt ?? this.checkedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceHealthRowsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('status: $status, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackSessionsTable extends PlaybackSessions
    with TableInfo<$PlaybackSessionsTable, PlaybackSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeBookIdMeta = const VerificationMeta(
    'activeBookId',
  );
  @override
  late final GeneratedColumn<String> activeBookId = GeneratedColumn<String>(
    'active_book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeBookVersionIdMeta =
      const VerificationMeta('activeBookVersionId');
  @override
  late final GeneratedColumn<String> activeBookVersionId =
      GeneratedColumn<String>(
        'active_book_version_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _activeSourceIdMeta = const VerificationMeta(
    'activeSourceId',
  );
  @override
  late final GeneratedColumn<String> activeSourceId = GeneratedColumn<String>(
    'active_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeChapterIdMeta = const VerificationMeta(
    'activeChapterId',
  );
  @override
  late final GeneratedColumn<String> activeChapterId = GeneratedColumn<String>(
    'active_chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isPlayingMeta = const VerificationMeta(
    'isPlaying',
  );
  @override
  late final GeneratedColumn<bool> isPlaying = GeneratedColumn<bool>(
    'is_playing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_playing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _playerPageIndexMeta = const VerificationMeta(
    'playerPageIndex',
  );
  @override
  late final GeneratedColumn<int> playerPageIndex = GeneratedColumn<int>(
    'player_page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sleepTimerRemainingMsMeta =
      const VerificationMeta('sleepTimerRemainingMs');
  @override
  late final GeneratedColumn<int> sleepTimerRemainingMs = GeneratedColumn<int>(
    'sleep_timer_remaining_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepTimerModeMeta = const VerificationMeta(
    'sleepTimerMode',
  );
  @override
  late final GeneratedColumn<String> sleepTimerMode = GeneratedColumn<String>(
    'sleep_timer_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('off'),
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
  List<GeneratedColumn> get $columns => [
    id,
    activeBookId,
    activeBookVersionId,
    activeSourceId,
    activeChapterId,
    positionMs,
    speed,
    volume,
    isPlaying,
    playerPageIndex,
    sleepTimerRemainingMs,
    sleepTimerMode,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('active_book_id')) {
      context.handle(
        _activeBookIdMeta,
        activeBookId.isAcceptableOrUnknown(
          data['active_book_id']!,
          _activeBookIdMeta,
        ),
      );
    }
    if (data.containsKey('active_book_version_id')) {
      context.handle(
        _activeBookVersionIdMeta,
        activeBookVersionId.isAcceptableOrUnknown(
          data['active_book_version_id']!,
          _activeBookVersionIdMeta,
        ),
      );
    }
    if (data.containsKey('active_source_id')) {
      context.handle(
        _activeSourceIdMeta,
        activeSourceId.isAcceptableOrUnknown(
          data['active_source_id']!,
          _activeSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('active_chapter_id')) {
      context.handle(
        _activeChapterIdMeta,
        activeChapterId.isAcceptableOrUnknown(
          data['active_chapter_id']!,
          _activeChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('is_playing')) {
      context.handle(
        _isPlayingMeta,
        isPlaying.isAcceptableOrUnknown(data['is_playing']!, _isPlayingMeta),
      );
    }
    if (data.containsKey('player_page_index')) {
      context.handle(
        _playerPageIndexMeta,
        playerPageIndex.isAcceptableOrUnknown(
          data['player_page_index']!,
          _playerPageIndexMeta,
        ),
      );
    }
    if (data.containsKey('sleep_timer_remaining_ms')) {
      context.handle(
        _sleepTimerRemainingMsMeta,
        sleepTimerRemainingMs.isAcceptableOrUnknown(
          data['sleep_timer_remaining_ms']!,
          _sleepTimerRemainingMsMeta,
        ),
      );
    }
    if (data.containsKey('sleep_timer_mode')) {
      context.handle(
        _sleepTimerModeMeta,
        sleepTimerMode.isAcceptableOrUnknown(
          data['sleep_timer_mode']!,
          _sleepTimerModeMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activeBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_book_id'],
      ),
      activeBookVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_book_version_id'],
      ),
      activeSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_source_id'],
      ),
      activeChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_chapter_id'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      )!,
      isPlaying: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_playing'],
      )!,
      playerPageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_page_index'],
      )!,
      sleepTimerRemainingMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sleep_timer_remaining_ms'],
      ),
      sleepTimerMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sleep_timer_mode'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackSessionsTable createAlias(String alias) {
    return $PlaybackSessionsTable(attachedDatabase, alias);
  }
}

class PlaybackSessionRow extends DataClass
    implements Insertable<PlaybackSessionRow> {
  final String id;
  final String? activeBookId;
  final String? activeBookVersionId;
  final String? activeSourceId;
  final String? activeChapterId;
  final int positionMs;
  final double speed;
  final double volume;
  final bool isPlaying;
  final int playerPageIndex;
  final int? sleepTimerRemainingMs;
  final String sleepTimerMode;
  final DateTime updatedAt;
  const PlaybackSessionRow({
    required this.id,
    this.activeBookId,
    this.activeBookVersionId,
    this.activeSourceId,
    this.activeChapterId,
    required this.positionMs,
    required this.speed,
    required this.volume,
    required this.isPlaying,
    required this.playerPageIndex,
    this.sleepTimerRemainingMs,
    required this.sleepTimerMode,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || activeBookId != null) {
      map['active_book_id'] = Variable<String>(activeBookId);
    }
    if (!nullToAbsent || activeBookVersionId != null) {
      map['active_book_version_id'] = Variable<String>(activeBookVersionId);
    }
    if (!nullToAbsent || activeSourceId != null) {
      map['active_source_id'] = Variable<String>(activeSourceId);
    }
    if (!nullToAbsent || activeChapterId != null) {
      map['active_chapter_id'] = Variable<String>(activeChapterId);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['speed'] = Variable<double>(speed);
    map['volume'] = Variable<double>(volume);
    map['is_playing'] = Variable<bool>(isPlaying);
    map['player_page_index'] = Variable<int>(playerPageIndex);
    if (!nullToAbsent || sleepTimerRemainingMs != null) {
      map['sleep_timer_remaining_ms'] = Variable<int>(sleepTimerRemainingMs);
    }
    map['sleep_timer_mode'] = Variable<String>(sleepTimerMode);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackSessionsCompanion toCompanion(bool nullToAbsent) {
    return PlaybackSessionsCompanion(
      id: Value(id),
      activeBookId: activeBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeBookId),
      activeBookVersionId: activeBookVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeBookVersionId),
      activeSourceId: activeSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeSourceId),
      activeChapterId: activeChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeChapterId),
      positionMs: Value(positionMs),
      speed: Value(speed),
      volume: Value(volume),
      isPlaying: Value(isPlaying),
      playerPageIndex: Value(playerPageIndex),
      sleepTimerRemainingMs: sleepTimerRemainingMs == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepTimerRemainingMs),
      sleepTimerMode: Value(sleepTimerMode),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackSessionRow(
      id: serializer.fromJson<String>(json['id']),
      activeBookId: serializer.fromJson<String?>(json['activeBookId']),
      activeBookVersionId: serializer.fromJson<String?>(
        json['activeBookVersionId'],
      ),
      activeSourceId: serializer.fromJson<String?>(json['activeSourceId']),
      activeChapterId: serializer.fromJson<String?>(json['activeChapterId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      speed: serializer.fromJson<double>(json['speed']),
      volume: serializer.fromJson<double>(json['volume']),
      isPlaying: serializer.fromJson<bool>(json['isPlaying']),
      playerPageIndex: serializer.fromJson<int>(json['playerPageIndex']),
      sleepTimerRemainingMs: serializer.fromJson<int?>(
        json['sleepTimerRemainingMs'],
      ),
      sleepTimerMode: serializer.fromJson<String>(json['sleepTimerMode']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activeBookId': serializer.toJson<String?>(activeBookId),
      'activeBookVersionId': serializer.toJson<String?>(activeBookVersionId),
      'activeSourceId': serializer.toJson<String?>(activeSourceId),
      'activeChapterId': serializer.toJson<String?>(activeChapterId),
      'positionMs': serializer.toJson<int>(positionMs),
      'speed': serializer.toJson<double>(speed),
      'volume': serializer.toJson<double>(volume),
      'isPlaying': serializer.toJson<bool>(isPlaying),
      'playerPageIndex': serializer.toJson<int>(playerPageIndex),
      'sleepTimerRemainingMs': serializer.toJson<int?>(sleepTimerRemainingMs),
      'sleepTimerMode': serializer.toJson<String>(sleepTimerMode),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackSessionRow copyWith({
    String? id,
    Value<String?> activeBookId = const Value.absent(),
    Value<String?> activeBookVersionId = const Value.absent(),
    Value<String?> activeSourceId = const Value.absent(),
    Value<String?> activeChapterId = const Value.absent(),
    int? positionMs,
    double? speed,
    double? volume,
    bool? isPlaying,
    int? playerPageIndex,
    Value<int?> sleepTimerRemainingMs = const Value.absent(),
    String? sleepTimerMode,
    DateTime? updatedAt,
  }) => PlaybackSessionRow(
    id: id ?? this.id,
    activeBookId: activeBookId.present ? activeBookId.value : this.activeBookId,
    activeBookVersionId: activeBookVersionId.present
        ? activeBookVersionId.value
        : this.activeBookVersionId,
    activeSourceId: activeSourceId.present
        ? activeSourceId.value
        : this.activeSourceId,
    activeChapterId: activeChapterId.present
        ? activeChapterId.value
        : this.activeChapterId,
    positionMs: positionMs ?? this.positionMs,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    isPlaying: isPlaying ?? this.isPlaying,
    playerPageIndex: playerPageIndex ?? this.playerPageIndex,
    sleepTimerRemainingMs: sleepTimerRemainingMs.present
        ? sleepTimerRemainingMs.value
        : this.sleepTimerRemainingMs,
    sleepTimerMode: sleepTimerMode ?? this.sleepTimerMode,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackSessionRow copyWithCompanion(PlaybackSessionsCompanion data) {
    return PlaybackSessionRow(
      id: data.id.present ? data.id.value : this.id,
      activeBookId: data.activeBookId.present
          ? data.activeBookId.value
          : this.activeBookId,
      activeBookVersionId: data.activeBookVersionId.present
          ? data.activeBookVersionId.value
          : this.activeBookVersionId,
      activeSourceId: data.activeSourceId.present
          ? data.activeSourceId.value
          : this.activeSourceId,
      activeChapterId: data.activeChapterId.present
          ? data.activeChapterId.value
          : this.activeChapterId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      speed: data.speed.present ? data.speed.value : this.speed,
      volume: data.volume.present ? data.volume.value : this.volume,
      isPlaying: data.isPlaying.present ? data.isPlaying.value : this.isPlaying,
      playerPageIndex: data.playerPageIndex.present
          ? data.playerPageIndex.value
          : this.playerPageIndex,
      sleepTimerRemainingMs: data.sleepTimerRemainingMs.present
          ? data.sleepTimerRemainingMs.value
          : this.sleepTimerRemainingMs,
      sleepTimerMode: data.sleepTimerMode.present
          ? data.sleepTimerMode.value
          : this.sleepTimerMode,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackSessionRow(')
          ..write('id: $id, ')
          ..write('activeBookId: $activeBookId, ')
          ..write('activeBookVersionId: $activeBookVersionId, ')
          ..write('activeSourceId: $activeSourceId, ')
          ..write('activeChapterId: $activeChapterId, ')
          ..write('positionMs: $positionMs, ')
          ..write('speed: $speed, ')
          ..write('volume: $volume, ')
          ..write('isPlaying: $isPlaying, ')
          ..write('playerPageIndex: $playerPageIndex, ')
          ..write('sleepTimerRemainingMs: $sleepTimerRemainingMs, ')
          ..write('sleepTimerMode: $sleepTimerMode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activeBookId,
    activeBookVersionId,
    activeSourceId,
    activeChapterId,
    positionMs,
    speed,
    volume,
    isPlaying,
    playerPageIndex,
    sleepTimerRemainingMs,
    sleepTimerMode,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackSessionRow &&
          other.id == this.id &&
          other.activeBookId == this.activeBookId &&
          other.activeBookVersionId == this.activeBookVersionId &&
          other.activeSourceId == this.activeSourceId &&
          other.activeChapterId == this.activeChapterId &&
          other.positionMs == this.positionMs &&
          other.speed == this.speed &&
          other.volume == this.volume &&
          other.isPlaying == this.isPlaying &&
          other.playerPageIndex == this.playerPageIndex &&
          other.sleepTimerRemainingMs == this.sleepTimerRemainingMs &&
          other.sleepTimerMode == this.sleepTimerMode &&
          other.updatedAt == this.updatedAt);
}

class PlaybackSessionsCompanion extends UpdateCompanion<PlaybackSessionRow> {
  final Value<String> id;
  final Value<String?> activeBookId;
  final Value<String?> activeBookVersionId;
  final Value<String?> activeSourceId;
  final Value<String?> activeChapterId;
  final Value<int> positionMs;
  final Value<double> speed;
  final Value<double> volume;
  final Value<bool> isPlaying;
  final Value<int> playerPageIndex;
  final Value<int?> sleepTimerRemainingMs;
  final Value<String> sleepTimerMode;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaybackSessionsCompanion({
    this.id = const Value.absent(),
    this.activeBookId = const Value.absent(),
    this.activeBookVersionId = const Value.absent(),
    this.activeSourceId = const Value.absent(),
    this.activeChapterId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.speed = const Value.absent(),
    this.volume = const Value.absent(),
    this.isPlaying = const Value.absent(),
    this.playerPageIndex = const Value.absent(),
    this.sleepTimerRemainingMs = const Value.absent(),
    this.sleepTimerMode = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackSessionsCompanion.insert({
    required String id,
    this.activeBookId = const Value.absent(),
    this.activeBookVersionId = const Value.absent(),
    this.activeSourceId = const Value.absent(),
    this.activeChapterId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.speed = const Value.absent(),
    this.volume = const Value.absent(),
    this.isPlaying = const Value.absent(),
    this.playerPageIndex = const Value.absent(),
    this.sleepTimerRemainingMs = const Value.absent(),
    this.sleepTimerMode = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<PlaybackSessionRow> custom({
    Expression<String>? id,
    Expression<String>? activeBookId,
    Expression<String>? activeBookVersionId,
    Expression<String>? activeSourceId,
    Expression<String>? activeChapterId,
    Expression<int>? positionMs,
    Expression<double>? speed,
    Expression<double>? volume,
    Expression<bool>? isPlaying,
    Expression<int>? playerPageIndex,
    Expression<int>? sleepTimerRemainingMs,
    Expression<String>? sleepTimerMode,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activeBookId != null) 'active_book_id': activeBookId,
      if (activeBookVersionId != null)
        'active_book_version_id': activeBookVersionId,
      if (activeSourceId != null) 'active_source_id': activeSourceId,
      if (activeChapterId != null) 'active_chapter_id': activeChapterId,
      if (positionMs != null) 'position_ms': positionMs,
      if (speed != null) 'speed': speed,
      if (volume != null) 'volume': volume,
      if (isPlaying != null) 'is_playing': isPlaying,
      if (playerPageIndex != null) 'player_page_index': playerPageIndex,
      if (sleepTimerRemainingMs != null)
        'sleep_timer_remaining_ms': sleepTimerRemainingMs,
      if (sleepTimerMode != null) 'sleep_timer_mode': sleepTimerMode,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackSessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? activeBookId,
    Value<String?>? activeBookVersionId,
    Value<String?>? activeSourceId,
    Value<String?>? activeChapterId,
    Value<int>? positionMs,
    Value<double>? speed,
    Value<double>? volume,
    Value<bool>? isPlaying,
    Value<int>? playerPageIndex,
    Value<int?>? sleepTimerRemainingMs,
    Value<String>? sleepTimerMode,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaybackSessionsCompanion(
      id: id ?? this.id,
      activeBookId: activeBookId ?? this.activeBookId,
      activeBookVersionId: activeBookVersionId ?? this.activeBookVersionId,
      activeSourceId: activeSourceId ?? this.activeSourceId,
      activeChapterId: activeChapterId ?? this.activeChapterId,
      positionMs: positionMs ?? this.positionMs,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
      playerPageIndex: playerPageIndex ?? this.playerPageIndex,
      sleepTimerRemainingMs:
          sleepTimerRemainingMs ?? this.sleepTimerRemainingMs,
      sleepTimerMode: sleepTimerMode ?? this.sleepTimerMode,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activeBookId.present) {
      map['active_book_id'] = Variable<String>(activeBookId.value);
    }
    if (activeBookVersionId.present) {
      map['active_book_version_id'] = Variable<String>(
        activeBookVersionId.value,
      );
    }
    if (activeSourceId.present) {
      map['active_source_id'] = Variable<String>(activeSourceId.value);
    }
    if (activeChapterId.present) {
      map['active_chapter_id'] = Variable<String>(activeChapterId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (isPlaying.present) {
      map['is_playing'] = Variable<bool>(isPlaying.value);
    }
    if (playerPageIndex.present) {
      map['player_page_index'] = Variable<int>(playerPageIndex.value);
    }
    if (sleepTimerRemainingMs.present) {
      map['sleep_timer_remaining_ms'] = Variable<int>(
        sleepTimerRemainingMs.value,
      );
    }
    if (sleepTimerMode.present) {
      map['sleep_timer_mode'] = Variable<String>(sleepTimerMode.value);
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
    return (StringBuffer('PlaybackSessionsCompanion(')
          ..write('id: $id, ')
          ..write('activeBookId: $activeBookId, ')
          ..write('activeBookVersionId: $activeBookVersionId, ')
          ..write('activeSourceId: $activeSourceId, ')
          ..write('activeChapterId: $activeChapterId, ')
          ..write('positionMs: $positionMs, ')
          ..write('speed: $speed, ')
          ..write('volume: $volume, ')
          ..write('isPlaying: $isPlaying, ')
          ..write('playerPageIndex: $playerPageIndex, ')
          ..write('sleepTimerRemainingMs: $sleepTimerRemainingMs, ')
          ..write('sleepTimerMode: $sleepTimerMode, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackProgressEntriesTable extends PlaybackProgressEntries
    with TableInfo<$PlaybackProgressEntriesTable, PlaybackProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackProgressEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookVersionIdMeta = const VerificationMeta(
    'bookVersionId',
  );
  @override
  late final GeneratedColumn<String> bookVersionId = GeneratedColumn<String>(
    'book_version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentChapterIdMeta = const VerificationMeta(
    'currentChapterId',
  );
  @override
  late final GeneratedColumn<String> currentChapterId = GeneratedColumn<String>(
    'current_chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentPositionMsMeta = const VerificationMeta(
    'currentPositionMs',
  );
  @override
  late final GeneratedColumn<int> currentPositionMs = GeneratedColumn<int>(
    'current_position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxReachedGlobalPositionMsMeta =
      const VerificationMeta('maxReachedGlobalPositionMs');
  @override
  late final GeneratedColumn<int> maxReachedGlobalPositionMs =
      GeneratedColumn<int>(
        'max_reached_global_position_ms',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _totalDurationMsMeta = const VerificationMeta(
    'totalDurationMs',
  );
  @override
  late final GeneratedColumn<int> totalDurationMs = GeneratedColumn<int>(
    'total_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _listenedDurationMsMeta =
      const VerificationMeta('listenedDurationMs');
  @override
  late final GeneratedColumn<int> listenedDurationMs = GeneratedColumn<int>(
    'listened_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<double> percent = GeneratedColumn<double>(
    'percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFinishedMeta = const VerificationMeta(
    'isFinished',
  );
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
    'is_finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    bookVersionId,
    currentChapterId,
    currentPositionMs,
    maxReachedGlobalPositionMs,
    totalDurationMs,
    listenedDurationMs,
    percent,
    isFinished,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('book_version_id')) {
      context.handle(
        _bookVersionIdMeta,
        bookVersionId.isAcceptableOrUnknown(
          data['book_version_id']!,
          _bookVersionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookVersionIdMeta);
    }
    if (data.containsKey('current_chapter_id')) {
      context.handle(
        _currentChapterIdMeta,
        currentChapterId.isAcceptableOrUnknown(
          data['current_chapter_id']!,
          _currentChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('current_position_ms')) {
      context.handle(
        _currentPositionMsMeta,
        currentPositionMs.isAcceptableOrUnknown(
          data['current_position_ms']!,
          _currentPositionMsMeta,
        ),
      );
    }
    if (data.containsKey('max_reached_global_position_ms')) {
      context.handle(
        _maxReachedGlobalPositionMsMeta,
        maxReachedGlobalPositionMs.isAcceptableOrUnknown(
          data['max_reached_global_position_ms']!,
          _maxReachedGlobalPositionMsMeta,
        ),
      );
    }
    if (data.containsKey('total_duration_ms')) {
      context.handle(
        _totalDurationMsMeta,
        totalDurationMs.isAcceptableOrUnknown(
          data['total_duration_ms']!,
          _totalDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('listened_duration_ms')) {
      context.handle(
        _listenedDurationMsMeta,
        listenedDurationMs.isAcceptableOrUnknown(
          data['listened_duration_ms']!,
          _listenedDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    }
    if (data.containsKey('is_finished')) {
      context.handle(
        _isFinishedMeta,
        isFinished.isAcceptableOrUnknown(data['is_finished']!, _isFinishedMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastPlayedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, bookVersionId};
  @override
  PlaybackProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackProgressRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      bookVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_version_id'],
      )!,
      currentChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_chapter_id'],
      ),
      currentPositionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_position_ms'],
      )!,
      maxReachedGlobalPositionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_reached_global_position_ms'],
      )!,
      totalDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_duration_ms'],
      )!,
      listenedDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listened_duration_ms'],
      )!,
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent'],
      )!,
      isFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finished'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      )!,
    );
  }

  @override
  $PlaybackProgressEntriesTable createAlias(String alias) {
    return $PlaybackProgressEntriesTable(attachedDatabase, alias);
  }
}

class PlaybackProgressRow extends DataClass
    implements Insertable<PlaybackProgressRow> {
  final String bookId;
  final String bookVersionId;
  final String? currentChapterId;
  final int currentPositionMs;
  final int maxReachedGlobalPositionMs;
  final int totalDurationMs;
  final int listenedDurationMs;
  final double percent;
  final bool isFinished;
  final DateTime lastPlayedAt;
  const PlaybackProgressRow({
    required this.bookId,
    required this.bookVersionId,
    this.currentChapterId,
    required this.currentPositionMs,
    required this.maxReachedGlobalPositionMs,
    required this.totalDurationMs,
    required this.listenedDurationMs,
    required this.percent,
    required this.isFinished,
    required this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['book_version_id'] = Variable<String>(bookVersionId);
    if (!nullToAbsent || currentChapterId != null) {
      map['current_chapter_id'] = Variable<String>(currentChapterId);
    }
    map['current_position_ms'] = Variable<int>(currentPositionMs);
    map['max_reached_global_position_ms'] = Variable<int>(
      maxReachedGlobalPositionMs,
    );
    map['total_duration_ms'] = Variable<int>(totalDurationMs);
    map['listened_duration_ms'] = Variable<int>(listenedDurationMs);
    map['percent'] = Variable<double>(percent);
    map['is_finished'] = Variable<bool>(isFinished);
    map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    return map;
  }

  PlaybackProgressEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackProgressEntriesCompanion(
      bookId: Value(bookId),
      bookVersionId: Value(bookVersionId),
      currentChapterId: currentChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentChapterId),
      currentPositionMs: Value(currentPositionMs),
      maxReachedGlobalPositionMs: Value(maxReachedGlobalPositionMs),
      totalDurationMs: Value(totalDurationMs),
      listenedDurationMs: Value(listenedDurationMs),
      percent: Value(percent),
      isFinished: Value(isFinished),
      lastPlayedAt: Value(lastPlayedAt),
    );
  }

  factory PlaybackProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackProgressRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      bookVersionId: serializer.fromJson<String>(json['bookVersionId']),
      currentChapterId: serializer.fromJson<String?>(json['currentChapterId']),
      currentPositionMs: serializer.fromJson<int>(json['currentPositionMs']),
      maxReachedGlobalPositionMs: serializer.fromJson<int>(
        json['maxReachedGlobalPositionMs'],
      ),
      totalDurationMs: serializer.fromJson<int>(json['totalDurationMs']),
      listenedDurationMs: serializer.fromJson<int>(json['listenedDurationMs']),
      percent: serializer.fromJson<double>(json['percent']),
      isFinished: serializer.fromJson<bool>(json['isFinished']),
      lastPlayedAt: serializer.fromJson<DateTime>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'bookVersionId': serializer.toJson<String>(bookVersionId),
      'currentChapterId': serializer.toJson<String?>(currentChapterId),
      'currentPositionMs': serializer.toJson<int>(currentPositionMs),
      'maxReachedGlobalPositionMs': serializer.toJson<int>(
        maxReachedGlobalPositionMs,
      ),
      'totalDurationMs': serializer.toJson<int>(totalDurationMs),
      'listenedDurationMs': serializer.toJson<int>(listenedDurationMs),
      'percent': serializer.toJson<double>(percent),
      'isFinished': serializer.toJson<bool>(isFinished),
      'lastPlayedAt': serializer.toJson<DateTime>(lastPlayedAt),
    };
  }

  PlaybackProgressRow copyWith({
    String? bookId,
    String? bookVersionId,
    Value<String?> currentChapterId = const Value.absent(),
    int? currentPositionMs,
    int? maxReachedGlobalPositionMs,
    int? totalDurationMs,
    int? listenedDurationMs,
    double? percent,
    bool? isFinished,
    DateTime? lastPlayedAt,
  }) => PlaybackProgressRow(
    bookId: bookId ?? this.bookId,
    bookVersionId: bookVersionId ?? this.bookVersionId,
    currentChapterId: currentChapterId.present
        ? currentChapterId.value
        : this.currentChapterId,
    currentPositionMs: currentPositionMs ?? this.currentPositionMs,
    maxReachedGlobalPositionMs:
        maxReachedGlobalPositionMs ?? this.maxReachedGlobalPositionMs,
    totalDurationMs: totalDurationMs ?? this.totalDurationMs,
    listenedDurationMs: listenedDurationMs ?? this.listenedDurationMs,
    percent: percent ?? this.percent,
    isFinished: isFinished ?? this.isFinished,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
  );
  PlaybackProgressRow copyWithCompanion(PlaybackProgressEntriesCompanion data) {
    return PlaybackProgressRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookVersionId: data.bookVersionId.present
          ? data.bookVersionId.value
          : this.bookVersionId,
      currentChapterId: data.currentChapterId.present
          ? data.currentChapterId.value
          : this.currentChapterId,
      currentPositionMs: data.currentPositionMs.present
          ? data.currentPositionMs.value
          : this.currentPositionMs,
      maxReachedGlobalPositionMs: data.maxReachedGlobalPositionMs.present
          ? data.maxReachedGlobalPositionMs.value
          : this.maxReachedGlobalPositionMs,
      totalDurationMs: data.totalDurationMs.present
          ? data.totalDurationMs.value
          : this.totalDurationMs,
      listenedDurationMs: data.listenedDurationMs.present
          ? data.listenedDurationMs.value
          : this.listenedDurationMs,
      percent: data.percent.present ? data.percent.value : this.percent,
      isFinished: data.isFinished.present
          ? data.isFinished.value
          : this.isFinished,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressRow(')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('currentChapterId: $currentChapterId, ')
          ..write('currentPositionMs: $currentPositionMs, ')
          ..write('maxReachedGlobalPositionMs: $maxReachedGlobalPositionMs, ')
          ..write('totalDurationMs: $totalDurationMs, ')
          ..write('listenedDurationMs: $listenedDurationMs, ')
          ..write('percent: $percent, ')
          ..write('isFinished: $isFinished, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    bookVersionId,
    currentChapterId,
    currentPositionMs,
    maxReachedGlobalPositionMs,
    totalDurationMs,
    listenedDurationMs,
    percent,
    isFinished,
    lastPlayedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackProgressRow &&
          other.bookId == this.bookId &&
          other.bookVersionId == this.bookVersionId &&
          other.currentChapterId == this.currentChapterId &&
          other.currentPositionMs == this.currentPositionMs &&
          other.maxReachedGlobalPositionMs == this.maxReachedGlobalPositionMs &&
          other.totalDurationMs == this.totalDurationMs &&
          other.listenedDurationMs == this.listenedDurationMs &&
          other.percent == this.percent &&
          other.isFinished == this.isFinished &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class PlaybackProgressEntriesCompanion
    extends UpdateCompanion<PlaybackProgressRow> {
  final Value<String> bookId;
  final Value<String> bookVersionId;
  final Value<String?> currentChapterId;
  final Value<int> currentPositionMs;
  final Value<int> maxReachedGlobalPositionMs;
  final Value<int> totalDurationMs;
  final Value<int> listenedDurationMs;
  final Value<double> percent;
  final Value<bool> isFinished;
  final Value<DateTime> lastPlayedAt;
  final Value<int> rowid;
  const PlaybackProgressEntriesCompanion({
    this.bookId = const Value.absent(),
    this.bookVersionId = const Value.absent(),
    this.currentChapterId = const Value.absent(),
    this.currentPositionMs = const Value.absent(),
    this.maxReachedGlobalPositionMs = const Value.absent(),
    this.totalDurationMs = const Value.absent(),
    this.listenedDurationMs = const Value.absent(),
    this.percent = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackProgressEntriesCompanion.insert({
    required String bookId,
    required String bookVersionId,
    this.currentChapterId = const Value.absent(),
    this.currentPositionMs = const Value.absent(),
    this.maxReachedGlobalPositionMs = const Value.absent(),
    this.totalDurationMs = const Value.absent(),
    this.listenedDurationMs = const Value.absent(),
    this.percent = const Value.absent(),
    this.isFinished = const Value.absent(),
    required DateTime lastPlayedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       bookVersionId = Value(bookVersionId),
       lastPlayedAt = Value(lastPlayedAt);
  static Insertable<PlaybackProgressRow> custom({
    Expression<String>? bookId,
    Expression<String>? bookVersionId,
    Expression<String>? currentChapterId,
    Expression<int>? currentPositionMs,
    Expression<int>? maxReachedGlobalPositionMs,
    Expression<int>? totalDurationMs,
    Expression<int>? listenedDurationMs,
    Expression<double>? percent,
    Expression<bool>? isFinished,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (bookVersionId != null) 'book_version_id': bookVersionId,
      if (currentChapterId != null) 'current_chapter_id': currentChapterId,
      if (currentPositionMs != null) 'current_position_ms': currentPositionMs,
      if (maxReachedGlobalPositionMs != null)
        'max_reached_global_position_ms': maxReachedGlobalPositionMs,
      if (totalDurationMs != null) 'total_duration_ms': totalDurationMs,
      if (listenedDurationMs != null)
        'listened_duration_ms': listenedDurationMs,
      if (percent != null) 'percent': percent,
      if (isFinished != null) 'is_finished': isFinished,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackProgressEntriesCompanion copyWith({
    Value<String>? bookId,
    Value<String>? bookVersionId,
    Value<String?>? currentChapterId,
    Value<int>? currentPositionMs,
    Value<int>? maxReachedGlobalPositionMs,
    Value<int>? totalDurationMs,
    Value<int>? listenedDurationMs,
    Value<double>? percent,
    Value<bool>? isFinished,
    Value<DateTime>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return PlaybackProgressEntriesCompanion(
      bookId: bookId ?? this.bookId,
      bookVersionId: bookVersionId ?? this.bookVersionId,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      maxReachedGlobalPositionMs:
          maxReachedGlobalPositionMs ?? this.maxReachedGlobalPositionMs,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      listenedDurationMs: listenedDurationMs ?? this.listenedDurationMs,
      percent: percent ?? this.percent,
      isFinished: isFinished ?? this.isFinished,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookVersionId.present) {
      map['book_version_id'] = Variable<String>(bookVersionId.value);
    }
    if (currentChapterId.present) {
      map['current_chapter_id'] = Variable<String>(currentChapterId.value);
    }
    if (currentPositionMs.present) {
      map['current_position_ms'] = Variable<int>(currentPositionMs.value);
    }
    if (maxReachedGlobalPositionMs.present) {
      map['max_reached_global_position_ms'] = Variable<int>(
        maxReachedGlobalPositionMs.value,
      );
    }
    if (totalDurationMs.present) {
      map['total_duration_ms'] = Variable<int>(totalDurationMs.value);
    }
    if (listenedDurationMs.present) {
      map['listened_duration_ms'] = Variable<int>(listenedDurationMs.value);
    }
    if (percent.present) {
      map['percent'] = Variable<double>(percent.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressEntriesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('currentChapterId: $currentChapterId, ')
          ..write('currentPositionMs: $currentPositionMs, ')
          ..write('maxReachedGlobalPositionMs: $maxReachedGlobalPositionMs, ')
          ..write('totalDurationMs: $totalDurationMs, ')
          ..write('listenedDurationMs: $listenedDurationMs, ')
          ..write('percent: $percent, ')
          ..write('isFinished: $isFinished, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookVersionIdMeta = const VerificationMeta(
    'bookVersionId',
  );
  @override
  late final GeneratedColumn<String> bookVersionId = GeneratedColumn<String>(
    'book_version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedBytesPerSecondMeta =
      const VerificationMeta('speedBytesPerSecond');
  @override
  late final GeneratedColumn<int> speedBytesPerSecond = GeneratedColumn<int>(
    'speed_bytes_per_second',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    bookVersionId,
    chapterId,
    sourceId,
    type,
    status,
    priority,
    progress,
    downloadedBytes,
    totalBytes,
    speedBytesPerSecond,
    errorCode,
    errorMessage,
    retryCount,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('book_version_id')) {
      context.handle(
        _bookVersionIdMeta,
        bookVersionId.isAcceptableOrUnknown(
          data['book_version_id']!,
          _bookVersionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookVersionIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('speed_bytes_per_second')) {
      context.handle(
        _speedBytesPerSecondMeta,
        speedBytesPerSecond.isAcceptableOrUnknown(
          data['speed_bytes_per_second']!,
          _speedBytesPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      bookVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_version_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      speedBytesPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}speed_bytes_per_second'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }
}

class DownloadTaskRow extends DataClass implements Insertable<DownloadTaskRow> {
  final String id;
  final String bookId;
  final String bookVersionId;
  final String? chapterId;
  final String sourceId;
  final String type;
  final String status;
  final int priority;
  final double progress;
  final int downloadedBytes;
  final int? totalBytes;
  final int speedBytesPerSecond;
  final String? errorCode;
  final String? errorMessage;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DownloadTaskRow({
    required this.id,
    required this.bookId,
    required this.bookVersionId,
    this.chapterId,
    required this.sourceId,
    required this.type,
    required this.status,
    required this.priority,
    required this.progress,
    required this.downloadedBytes,
    this.totalBytes,
    required this.speedBytesPerSecond,
    this.errorCode,
    this.errorMessage,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['book_version_id'] = Variable<String>(bookVersionId);
    if (!nullToAbsent || chapterId != null) {
      map['chapter_id'] = Variable<String>(chapterId);
    }
    map['source_id'] = Variable<String>(sourceId);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<int>(priority);
    map['progress'] = Variable<double>(progress);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    map['speed_bytes_per_second'] = Variable<int>(speedBytesPerSecond);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      bookVersionId: Value(bookVersionId),
      chapterId: chapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterId),
      sourceId: Value(sourceId),
      type: Value(type),
      status: Value(status),
      priority: Value(priority),
      progress: Value(progress),
      downloadedBytes: Value(downloadedBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      speedBytesPerSecond: Value(speedBytesPerSecond),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTaskRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      bookVersionId: serializer.fromJson<String>(json['bookVersionId']),
      chapterId: serializer.fromJson<String?>(json['chapterId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<int>(json['priority']),
      progress: serializer.fromJson<double>(json['progress']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      speedBytesPerSecond: serializer.fromJson<int>(
        json['speedBytesPerSecond'],
      ),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'bookVersionId': serializer.toJson<String>(bookVersionId),
      'chapterId': serializer.toJson<String?>(chapterId),
      'sourceId': serializer.toJson<String>(sourceId),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<int>(priority),
      'progress': serializer.toJson<double>(progress),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'speedBytesPerSecond': serializer.toJson<int>(speedBytesPerSecond),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadTaskRow copyWith({
    String? id,
    String? bookId,
    String? bookVersionId,
    Value<String?> chapterId = const Value.absent(),
    String? sourceId,
    String? type,
    String? status,
    int? priority,
    double? progress,
    int? downloadedBytes,
    Value<int?> totalBytes = const Value.absent(),
    int? speedBytesPerSecond,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    int? retryCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DownloadTaskRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    bookVersionId: bookVersionId ?? this.bookVersionId,
    chapterId: chapterId.present ? chapterId.value : this.chapterId,
    sourceId: sourceId ?? this.sourceId,
    type: type ?? this.type,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    progress: progress ?? this.progress,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadTaskRow copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTaskRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookVersionId: data.bookVersionId.present
          ? data.bookVersionId.value
          : this.bookVersionId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      progress: data.progress.present ? data.progress.value : this.progress,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      speedBytesPerSecond: data.speedBytesPerSecond.present
          ? data.speedBytesPerSecond.value
          : this.speedBytesPerSecond,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('chapterId: $chapterId, ')
          ..write('sourceId: $sourceId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('progress: $progress, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('speedBytesPerSecond: $speedBytesPerSecond, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    bookVersionId,
    chapterId,
    sourceId,
    type,
    status,
    priority,
    progress,
    downloadedBytes,
    totalBytes,
    speedBytesPerSecond,
    errorCode,
    errorMessage,
    retryCount,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTaskRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.bookVersionId == this.bookVersionId &&
          other.chapterId == this.chapterId &&
          other.sourceId == this.sourceId &&
          other.type == this.type &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.progress == this.progress &&
          other.downloadedBytes == this.downloadedBytes &&
          other.totalBytes == this.totalBytes &&
          other.speedBytesPerSecond == this.speedBytesPerSecond &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTaskRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> bookVersionId;
  final Value<String?> chapterId;
  final Value<String> sourceId;
  final Value<String> type;
  final Value<String> status;
  final Value<int> priority;
  final Value<double> progress;
  final Value<int> downloadedBytes;
  final Value<int?> totalBytes;
  final Value<int> speedBytesPerSecond;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DownloadTasksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.bookVersionId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.progress = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.speedBytesPerSecond = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    required String id,
    required String bookId,
    required String bookVersionId,
    this.chapterId = const Value.absent(),
    required String sourceId,
    required String type,
    required String status,
    this.priority = const Value.absent(),
    this.progress = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.speedBytesPerSecond = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.retryCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       bookVersionId = Value(bookVersionId),
       sourceId = Value(sourceId),
       type = Value(type),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadTaskRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? bookVersionId,
    Expression<String>? chapterId,
    Expression<String>? sourceId,
    Expression<String>? type,
    Expression<String>? status,
    Expression<int>? priority,
    Expression<double>? progress,
    Expression<int>? downloadedBytes,
    Expression<int>? totalBytes,
    Expression<int>? speedBytesPerSecond,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (bookVersionId != null) 'book_version_id': bookVersionId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (sourceId != null) 'source_id': sourceId,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (progress != null) 'progress': progress,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (speedBytesPerSecond != null)
        'speed_bytes_per_second': speedBytesPerSecond,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? bookVersionId,
    Value<String?>? chapterId,
    Value<String>? sourceId,
    Value<String>? type,
    Value<String>? status,
    Value<int>? priority,
    Value<double>? progress,
    Value<int>? downloadedBytes,
    Value<int?>? totalBytes,
    Value<int>? speedBytesPerSecond,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<int>? retryCount,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadTasksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookVersionId: bookVersionId ?? this.bookVersionId,
      chapterId: chapterId ?? this.chapterId,
      sourceId: sourceId ?? this.sourceId,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookVersionId.present) {
      map['book_version_id'] = Variable<String>(bookVersionId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (speedBytesPerSecond.present) {
      map['speed_bytes_per_second'] = Variable<int>(speedBytesPerSecond.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('chapterId: $chapterId, ')
          ..write('sourceId: $sourceId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('progress: $progress, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('speedBytesPerSecond: $speedBytesPerSecond, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookVersionIdMeta = const VerificationMeta(
    'bookVersionId',
  );
  @override
  late final GeneratedColumn<String> bookVersionId = GeneratedColumn<String>(
    'book_version_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [bookId, bookVersionId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('book_version_id')) {
      context.handle(
        _bookVersionIdMeta,
        bookVersionId.isAcceptableOrUnknown(
          data['book_version_id']!,
          _bookVersionIdMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      bookVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_version_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final String bookId;
  final String? bookVersionId;
  final DateTime createdAt;
  const FavoriteRow({
    required this.bookId,
    this.bookVersionId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || bookVersionId != null) {
      map['book_version_id'] = Variable<String>(bookVersionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      bookId: Value(bookId),
      bookVersionId: bookVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookVersionId),
      createdAt: Value(createdAt),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      bookId: serializer.fromJson<String>(json['bookId']),
      bookVersionId: serializer.fromJson<String?>(json['bookVersionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'bookVersionId': serializer.toJson<String?>(bookVersionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FavoriteRow copyWith({
    String? bookId,
    Value<String?> bookVersionId = const Value.absent(),
    DateTime? createdAt,
  }) => FavoriteRow(
    bookId: bookId ?? this.bookId,
    bookVersionId: bookVersionId.present
        ? bookVersionId.value
        : this.bookVersionId,
    createdAt: createdAt ?? this.createdAt,
  );
  FavoriteRow copyWithCompanion(FavoritesCompanion data) {
    return FavoriteRow(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookVersionId: data.bookVersionId.present
          ? data.bookVersionId.value
          : this.bookVersionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, bookVersionId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.bookId == this.bookId &&
          other.bookVersionId == this.bookVersionId &&
          other.createdAt == this.createdAt);
}

class FavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<String> bookId;
  final Value<String?> bookVersionId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.bookId = const Value.absent(),
    this.bookVersionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String bookId,
    this.bookVersionId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       createdAt = Value(createdAt);
  static Insertable<FavoriteRow> custom({
    Expression<String>? bookId,
    Expression<String>? bookVersionId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (bookVersionId != null) 'book_version_id': bookVersionId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? bookId,
    Value<String?>? bookVersionId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      bookId: bookId ?? this.bookId,
      bookVersionId: bookVersionId ?? this.bookVersionId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookVersionId.present) {
      map['book_version_id'] = Variable<String>(bookVersionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookVersionIdMeta = const VerificationMeta(
    'bookVersionId',
  );
  @override
  late final GeneratedColumn<String> bookVersionId = GeneratedColumn<String>(
    'book_version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
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
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    bookVersionId,
    chapterId,
    positionMs,
    title,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('book_version_id')) {
      context.handle(
        _bookVersionIdMeta,
        bookVersionId.isAcceptableOrUnknown(
          data['book_version_id']!,
          _bookVersionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookVersionIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      bookVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_version_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class BookmarkRow extends DataClass implements Insertable<BookmarkRow> {
  final String id;
  final String bookId;
  final String bookVersionId;
  final String chapterId;
  final int positionMs;
  final String title;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BookmarkRow({
    required this.id,
    required this.bookId,
    required this.bookVersionId,
    required this.chapterId,
    required this.positionMs,
    required this.title,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['book_version_id'] = Variable<String>(bookVersionId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['position_ms'] = Variable<int>(positionMs);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      bookVersionId: Value(bookVersionId),
      chapterId: Value(chapterId),
      positionMs: Value(positionMs),
      title: Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookmarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkRow(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      bookVersionId: serializer.fromJson<String>(json['bookVersionId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'bookVersionId': serializer.toJson<String>(bookVersionId),
      'chapterId': serializer.toJson<String>(chapterId),
      'positionMs': serializer.toJson<int>(positionMs),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookmarkRow copyWith({
    String? id,
    String? bookId,
    String? bookVersionId,
    String? chapterId,
    int? positionMs,
    String? title,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookmarkRow(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    bookVersionId: bookVersionId ?? this.bookVersionId,
    chapterId: chapterId ?? this.chapterId,
    positionMs: positionMs ?? this.positionMs,
    title: title ?? this.title,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookmarkRow copyWithCompanion(BookmarksCompanion data) {
    return BookmarkRow(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookVersionId: data.bookVersionId.present
          ? data.bookVersionId.value
          : this.bookVersionId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkRow(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('chapterId: $chapterId, ')
          ..write('positionMs: $positionMs, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    bookVersionId,
    chapterId,
    positionMs,
    title,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkRow &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.bookVersionId == this.bookVersionId &&
          other.chapterId == this.chapterId &&
          other.positionMs == this.positionMs &&
          other.title == this.title &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkRow> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> bookVersionId;
  final Value<String> chapterId;
  final Value<int> positionMs;
  final Value<String> title;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.bookVersionId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String bookId,
    required String bookVersionId,
    required String chapterId,
    required int positionMs,
    required String title,
    this.note = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       bookVersionId = Value(bookVersionId),
       chapterId = Value(chapterId),
       positionMs = Value(positionMs),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookmarkRow> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? bookVersionId,
    Expression<String>? chapterId,
    Expression<int>? positionMs,
    Expression<String>? title,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (bookVersionId != null) 'book_version_id': bookVersionId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (positionMs != null) 'position_ms': positionMs,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? bookVersionId,
    Value<String>? chapterId,
    Value<int>? positionMs,
    Value<String>? title,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookVersionId: bookVersionId ?? this.bookVersionId,
      chapterId: chapterId ?? this.chapterId,
      positionMs: positionMs ?? this.positionMs,
      title: title ?? this.title,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookVersionId.present) {
      map['book_version_id'] = Variable<String>(bookVersionId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookVersionId: $bookVersionId, ')
          ..write('chapterId: $chapterId, ')
          ..write('positionMs: $positionMs, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryRowsTable extends SearchHistoryRows
    with TableInfo<$SearchHistoryRowsTable, SearchHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchKindMeta = const VerificationMeta(
    'searchKind',
  );
  @override
  late final GeneratedColumn<String> searchKind = GeneratedColumn<String>(
    'search_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filtersJsonMeta = const VerificationMeta(
    'filtersJson',
  );
  @override
  late final GeneratedColumn<String> filtersJson = GeneratedColumn<String>(
    'filters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
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
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usageCountMeta = const VerificationMeta(
    'usageCount',
  );
  @override
  late final GeneratedColumn<int> usageCount = GeneratedColumn<int>(
    'usage_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    query,
    searchKind,
    filtersJson,
    createdAt,
    lastUsedAt,
    usageCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('search_kind')) {
      context.handle(
        _searchKindMeta,
        searchKind.isAcceptableOrUnknown(data['search_kind']!, _searchKindMeta),
      );
    } else if (isInserting) {
      context.missing(_searchKindMeta);
    }
    if (data.containsKey('filters_json')) {
      context.handle(
        _filtersJsonMeta,
        filtersJson.isAcceptableOrUnknown(
          data['filters_json']!,
          _filtersJsonMeta,
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
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    if (data.containsKey('usage_count')) {
      context.handle(
        _usageCountMeta,
        usageCount.isAcceptableOrUnknown(data['usage_count']!, _usageCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      searchKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_kind'],
      )!,
      filtersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filters_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      )!,
      usageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usage_count'],
      )!,
    );
  }

  @override
  $SearchHistoryRowsTable createAlias(String alias) {
    return $SearchHistoryRowsTable(attachedDatabase, alias);
  }
}

class SearchHistoryRow extends DataClass
    implements Insertable<SearchHistoryRow> {
  final String id;
  final String query;
  final String searchKind;
  final String filtersJson;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final int usageCount;
  const SearchHistoryRow({
    required this.id,
    required this.query,
    required this.searchKind,
    required this.filtersJson,
    required this.createdAt,
    required this.lastUsedAt,
    required this.usageCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['query'] = Variable<String>(query);
    map['search_kind'] = Variable<String>(searchKind);
    map['filters_json'] = Variable<String>(filtersJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    map['usage_count'] = Variable<int>(usageCount);
    return map;
  }

  SearchHistoryRowsCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryRowsCompanion(
      id: Value(id),
      query: Value(query),
      searchKind: Value(searchKind),
      filtersJson: Value(filtersJson),
      createdAt: Value(createdAt),
      lastUsedAt: Value(lastUsedAt),
      usageCount: Value(usageCount),
    );
  }

  factory SearchHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      query: serializer.fromJson<String>(json['query']),
      searchKind: serializer.fromJson<String>(json['searchKind']),
      filtersJson: serializer.fromJson<String>(json['filtersJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
      usageCount: serializer.fromJson<int>(json['usageCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'query': serializer.toJson<String>(query),
      'searchKind': serializer.toJson<String>(searchKind),
      'filtersJson': serializer.toJson<String>(filtersJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
      'usageCount': serializer.toJson<int>(usageCount),
    };
  }

  SearchHistoryRow copyWith({
    String? id,
    String? query,
    String? searchKind,
    String? filtersJson,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? usageCount,
  }) => SearchHistoryRow(
    id: id ?? this.id,
    query: query ?? this.query,
    searchKind: searchKind ?? this.searchKind,
    filtersJson: filtersJson ?? this.filtersJson,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    usageCount: usageCount ?? this.usageCount,
  );
  SearchHistoryRow copyWithCompanion(SearchHistoryRowsCompanion data) {
    return SearchHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      query: data.query.present ? data.query.value : this.query,
      searchKind: data.searchKind.present
          ? data.searchKind.value
          : this.searchKind,
      filtersJson: data.filtersJson.present
          ? data.filtersJson.value
          : this.filtersJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      usageCount: data.usageCount.present
          ? data.usageCount.value
          : this.usageCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryRow(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchKind: $searchKind, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('usageCount: $usageCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    query,
    searchKind,
    filtersJson,
    createdAt,
    lastUsedAt,
    usageCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryRow &&
          other.id == this.id &&
          other.query == this.query &&
          other.searchKind == this.searchKind &&
          other.filtersJson == this.filtersJson &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.usageCount == this.usageCount);
}

class SearchHistoryRowsCompanion extends UpdateCompanion<SearchHistoryRow> {
  final Value<String> id;
  final Value<String> query;
  final Value<String> searchKind;
  final Value<String> filtersJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUsedAt;
  final Value<int> usageCount;
  final Value<int> rowid;
  const SearchHistoryRowsCompanion({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.searchKind = const Value.absent(),
    this.filtersJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.usageCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryRowsCompanion.insert({
    required String id,
    required String query,
    required String searchKind,
    this.filtersJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastUsedAt,
    this.usageCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       query = Value(query),
       searchKind = Value(searchKind),
       createdAt = Value(createdAt),
       lastUsedAt = Value(lastUsedAt);
  static Insertable<SearchHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? query,
    Expression<String>? searchKind,
    Expression<String>? filtersJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? usageCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (query != null) 'query': query,
      if (searchKind != null) 'search_kind': searchKind,
      if (filtersJson != null) 'filters_json': filtersJson,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (usageCount != null) 'usage_count': usageCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? query,
    Value<String>? searchKind,
    Value<String>? filtersJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastUsedAt,
    Value<int>? usageCount,
    Value<int>? rowid,
  }) {
    return SearchHistoryRowsCompanion(
      id: id ?? this.id,
      query: query ?? this.query,
      searchKind: searchKind ?? this.searchKind,
      filtersJson: filtersJson ?? this.filtersJson,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchKind.present) {
      map['search_kind'] = Variable<String>(searchKind.value);
    }
    if (filtersJson.present) {
      map['filters_json'] = Variable<String>(filtersJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (usageCount.present) {
      map['usage_count'] = Variable<int>(usageCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchKind: $searchKind, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('usageCount: $usageCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsRowsTable extends AppSettingsRows
    with TableInfo<$AppSettingsRowsTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ru'),
  );
  static const VerificationMeta _accentColorMeta = const VerificationMeta(
    'accentColor',
  );
  @override
  late final GeneratedColumn<String> accentColor = GeneratedColumn<String>(
    'accent_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _textScaleMeta = const VerificationMeta(
    'textScale',
  );
  @override
  late final GeneratedColumn<double> textScale = GeneratedColumn<double>(
    'text_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _compactCardsMeta = const VerificationMeta(
    'compactCards',
  );
  @override
  late final GeneratedColumn<bool> compactCards = GeneratedColumn<bool>(
    'compact_cards',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("compact_cards" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showSourceOnCardsMeta = const VerificationMeta(
    'showSourceOnCards',
  );
  @override
  late final GeneratedColumn<bool> showSourceOnCards = GeneratedColumn<bool>(
    'show_source_on_cards',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_source_on_cards" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showPercentOnCoversMeta =
      const VerificationMeta('showPercentOnCovers');
  @override
  late final GeneratedColumn<bool> showPercentOnCovers = GeneratedColumn<bool>(
    'show_percent_on_covers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_percent_on_covers" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _animationsModeMeta = const VerificationMeta(
    'animationsMode',
  );
  @override
  late final GeneratedColumn<String> animationsMode = GeneratedColumn<String>(
    'animations_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('full'),
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
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    languageCode,
    accentColor,
    textScale,
    compactCards,
    showSourceOnCards,
    showPercentOnCovers,
    animationsMode,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    }
    if (data.containsKey('accent_color')) {
      context.handle(
        _accentColorMeta,
        accentColor.isAcceptableOrUnknown(
          data['accent_color']!,
          _accentColorMeta,
        ),
      );
    }
    if (data.containsKey('text_scale')) {
      context.handle(
        _textScaleMeta,
        textScale.isAcceptableOrUnknown(data['text_scale']!, _textScaleMeta),
      );
    }
    if (data.containsKey('compact_cards')) {
      context.handle(
        _compactCardsMeta,
        compactCards.isAcceptableOrUnknown(
          data['compact_cards']!,
          _compactCardsMeta,
        ),
      );
    }
    if (data.containsKey('show_source_on_cards')) {
      context.handle(
        _showSourceOnCardsMeta,
        showSourceOnCards.isAcceptableOrUnknown(
          data['show_source_on_cards']!,
          _showSourceOnCardsMeta,
        ),
      );
    }
    if (data.containsKey('show_percent_on_covers')) {
      context.handle(
        _showPercentOnCoversMeta,
        showPercentOnCovers.isAcceptableOrUnknown(
          data['show_percent_on_covers']!,
          _showPercentOnCoversMeta,
        ),
      );
    }
    if (data.containsKey('animations_mode')) {
      context.handle(
        _animationsModeMeta,
        animationsMode.isAcceptableOrUnknown(
          data['animations_mode']!,
          _animationsModeMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      )!,
      accentColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accent_color'],
      )!,
      textScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}text_scale'],
      )!,
      compactCards: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}compact_cards'],
      )!,
      showSourceOnCards: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_source_on_cards'],
      )!,
      showPercentOnCovers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_percent_on_covers'],
      )!,
      animationsMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}animations_mode'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsRowsTable createAlias(String alias) {
    return $AppSettingsRowsTable(attachedDatabase, alias);
  }
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final String id;
  final String themeMode;
  final String languageCode;
  final String accentColor;
  final double textScale;
  final bool compactCards;
  final bool showSourceOnCards;
  final bool showPercentOnCovers;
  final String animationsMode;
  final DateTime updatedAt;
  const AppSettingsRow({
    required this.id,
    required this.themeMode,
    required this.languageCode,
    required this.accentColor,
    required this.textScale,
    required this.compactCards,
    required this.showSourceOnCards,
    required this.showPercentOnCovers,
    required this.animationsMode,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['theme_mode'] = Variable<String>(themeMode);
    map['language_code'] = Variable<String>(languageCode);
    map['accent_color'] = Variable<String>(accentColor);
    map['text_scale'] = Variable<double>(textScale);
    map['compact_cards'] = Variable<bool>(compactCards);
    map['show_source_on_cards'] = Variable<bool>(showSourceOnCards);
    map['show_percent_on_covers'] = Variable<bool>(showPercentOnCovers);
    map['animations_mode'] = Variable<String>(animationsMode);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsRowsCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      languageCode: Value(languageCode),
      accentColor: Value(accentColor),
      textScale: Value(textScale),
      compactCards: Value(compactCards),
      showSourceOnCards: Value(showSourceOnCards),
      showPercentOnCovers: Value(showPercentOnCovers),
      animationsMode: Value(animationsMode),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      id: serializer.fromJson<String>(json['id']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      accentColor: serializer.fromJson<String>(json['accentColor']),
      textScale: serializer.fromJson<double>(json['textScale']),
      compactCards: serializer.fromJson<bool>(json['compactCards']),
      showSourceOnCards: serializer.fromJson<bool>(json['showSourceOnCards']),
      showPercentOnCovers: serializer.fromJson<bool>(
        json['showPercentOnCovers'],
      ),
      animationsMode: serializer.fromJson<String>(json['animationsMode']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'themeMode': serializer.toJson<String>(themeMode),
      'languageCode': serializer.toJson<String>(languageCode),
      'accentColor': serializer.toJson<String>(accentColor),
      'textScale': serializer.toJson<double>(textScale),
      'compactCards': serializer.toJson<bool>(compactCards),
      'showSourceOnCards': serializer.toJson<bool>(showSourceOnCards),
      'showPercentOnCovers': serializer.toJson<bool>(showPercentOnCovers),
      'animationsMode': serializer.toJson<String>(animationsMode),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSettingsRow copyWith({
    String? id,
    String? themeMode,
    String? languageCode,
    String? accentColor,
    double? textScale,
    bool? compactCards,
    bool? showSourceOnCards,
    bool? showPercentOnCovers,
    String? animationsMode,
    DateTime? updatedAt,
  }) => AppSettingsRow(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    accentColor: accentColor ?? this.accentColor,
    textScale: textScale ?? this.textScale,
    compactCards: compactCards ?? this.compactCards,
    showSourceOnCards: showSourceOnCards ?? this.showSourceOnCards,
    showPercentOnCovers: showPercentOnCovers ?? this.showPercentOnCovers,
    animationsMode: animationsMode ?? this.animationsMode,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSettingsRow copyWithCompanion(AppSettingsRowsCompanion data) {
    return AppSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      accentColor: data.accentColor.present
          ? data.accentColor.value
          : this.accentColor,
      textScale: data.textScale.present ? data.textScale.value : this.textScale,
      compactCards: data.compactCards.present
          ? data.compactCards.value
          : this.compactCards,
      showSourceOnCards: data.showSourceOnCards.present
          ? data.showSourceOnCards.value
          : this.showSourceOnCards,
      showPercentOnCovers: data.showPercentOnCovers.present
          ? data.showPercentOnCovers.value
          : this.showPercentOnCovers,
      animationsMode: data.animationsMode.present
          ? data.animationsMode.value
          : this.animationsMode,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('languageCode: $languageCode, ')
          ..write('accentColor: $accentColor, ')
          ..write('textScale: $textScale, ')
          ..write('compactCards: $compactCards, ')
          ..write('showSourceOnCards: $showSourceOnCards, ')
          ..write('showPercentOnCovers: $showPercentOnCovers, ')
          ..write('animationsMode: $animationsMode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    languageCode,
    accentColor,
    textScale,
    compactCards,
    showSourceOnCards,
    showPercentOnCovers,
    animationsMode,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.languageCode == this.languageCode &&
          other.accentColor == this.accentColor &&
          other.textScale == this.textScale &&
          other.compactCards == this.compactCards &&
          other.showSourceOnCards == this.showSourceOnCards &&
          other.showPercentOnCovers == this.showPercentOnCovers &&
          other.animationsMode == this.animationsMode &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsRowsCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<String> id;
  final Value<String> themeMode;
  final Value<String> languageCode;
  final Value<String> accentColor;
  final Value<double> textScale;
  final Value<bool> compactCards;
  final Value<bool> showSourceOnCards;
  final Value<bool> showPercentOnCovers;
  final Value<String> animationsMode;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsRowsCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.textScale = const Value.absent(),
    this.compactCards = const Value.absent(),
    this.showSourceOnCards = const Value.absent(),
    this.showPercentOnCovers = const Value.absent(),
    this.animationsMode = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsRowsCompanion.insert({
    required String id,
    this.themeMode = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.textScale = const Value.absent(),
    this.compactCards = const Value.absent(),
    this.showSourceOnCards = const Value.absent(),
    this.showPercentOnCovers = const Value.absent(),
    this.animationsMode = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingsRow> custom({
    Expression<String>? id,
    Expression<String>? themeMode,
    Expression<String>? languageCode,
    Expression<String>? accentColor,
    Expression<double>? textScale,
    Expression<bool>? compactCards,
    Expression<bool>? showSourceOnCards,
    Expression<bool>? showPercentOnCovers,
    Expression<String>? animationsMode,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (languageCode != null) 'language_code': languageCode,
      if (accentColor != null) 'accent_color': accentColor,
      if (textScale != null) 'text_scale': textScale,
      if (compactCards != null) 'compact_cards': compactCards,
      if (showSourceOnCards != null) 'show_source_on_cards': showSourceOnCards,
      if (showPercentOnCovers != null)
        'show_percent_on_covers': showPercentOnCovers,
      if (animationsMode != null) 'animations_mode': animationsMode,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? themeMode,
    Value<String>? languageCode,
    Value<String>? accentColor,
    Value<double>? textScale,
    Value<bool>? compactCards,
    Value<bool>? showSourceOnCards,
    Value<bool>? showPercentOnCovers,
    Value<String>? animationsMode,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsRowsCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      accentColor: accentColor ?? this.accentColor,
      textScale: textScale ?? this.textScale,
      compactCards: compactCards ?? this.compactCards,
      showSourceOnCards: showSourceOnCards ?? this.showSourceOnCards,
      showPercentOnCovers: showPercentOnCovers ?? this.showPercentOnCovers,
      animationsMode: animationsMode ?? this.animationsMode,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (accentColor.present) {
      map['accent_color'] = Variable<String>(accentColor.value);
    }
    if (textScale.present) {
      map['text_scale'] = Variable<double>(textScale.value);
    }
    if (compactCards.present) {
      map['compact_cards'] = Variable<bool>(compactCards.value);
    }
    if (showSourceOnCards.present) {
      map['show_source_on_cards'] = Variable<bool>(showSourceOnCards.value);
    }
    if (showPercentOnCovers.present) {
      map['show_percent_on_covers'] = Variable<bool>(showPercentOnCovers.value);
    }
    if (animationsMode.present) {
      map['animations_mode'] = Variable<String>(animationsMode.value);
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
    return (StringBuffer('AppSettingsRowsCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('languageCode: $languageCode, ')
          ..write('accentColor: $accentColor, ')
          ..write('textScale: $textScale, ')
          ..write('compactCards: $compactCards, ')
          ..write('showSourceOnCards: $showSourceOnCards, ')
          ..write('showPercentOnCovers: $showPercentOnCovers, ')
          ..write('animationsMode: $animationsMode, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProxyProfilesTable extends ProxyProfiles
    with TableInfo<$ProxyProfilesTable, ProxyProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProxyProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    host,
    port,
    username,
    isEnabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'proxy_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProxyProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProxyProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProxyProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      ),
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProxyProfilesTable createAlias(String alias) {
    return $ProxyProfilesTable(attachedDatabase, alias);
  }
}

class ProxyProfileRow extends DataClass implements Insertable<ProxyProfileRow> {
  final String id;
  final String name;
  final String type;
  final String? host;
  final int? port;
  final String? username;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProxyProfileRow({
    required this.id,
    required this.name,
    required this.type,
    this.host,
    this.port,
    this.username,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || host != null) {
      map['host'] = Variable<String>(host);
    }
    if (!nullToAbsent || port != null) {
      map['port'] = Variable<int>(port);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProxyProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProxyProfilesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      host: host == null && nullToAbsent ? const Value.absent() : Value(host),
      port: port == null && nullToAbsent ? const Value.absent() : Value(port),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProxyProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProxyProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      host: serializer.fromJson<String?>(json['host']),
      port: serializer.fromJson<int?>(json['port']),
      username: serializer.fromJson<String?>(json['username']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'host': serializer.toJson<String?>(host),
      'port': serializer.toJson<int?>(port),
      'username': serializer.toJson<String?>(username),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProxyProfileRow copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> host = const Value.absent(),
    Value<int?> port = const Value.absent(),
    Value<String?> username = const Value.absent(),
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProxyProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    host: host.present ? host.value : this.host,
    port: port.present ? port.value : this.port,
    username: username.present ? username.value : this.username,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProxyProfileRow copyWithCompanion(ProxyProfilesCompanion data) {
    return ProxyProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      username: data.username.present ? data.username.value : this.username,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProxyProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    host,
    port,
    username,
    isEnabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProxyProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.host == this.host &&
          other.port == this.port &&
          other.username == this.username &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProxyProfilesCompanion extends UpdateCompanion<ProxyProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> host;
  final Value<int?> port;
  final Value<String?> username;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProxyProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.username = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProxyProfilesCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.username = const Value.absent(),
    this.isEnabled = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProxyProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? host,
    Expression<int>? port,
    Expression<String>? username,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (username != null) 'username': username,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProxyProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? host,
    Value<int?>? port,
    Value<String?>? username,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProxyProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('ProxyProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceSettingsRowsTable extends SourceSettingsRows
    with TableInfo<$SourceSettingsRowsTable, SourceSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceSettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _useInGlobalSearchMeta = const VerificationMeta(
    'useInGlobalSearch',
  );
  @override
  late final GeneratedColumn<bool> useInGlobalSearch = GeneratedColumn<bool>(
    'use_in_global_search',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_in_global_search" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _allowStreamingMeta = const VerificationMeta(
    'allowStreaming',
  );
  @override
  late final GeneratedColumn<bool> allowStreaming = GeneratedColumn<bool>(
    'allow_streaming',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_streaming" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _allowDownloadMeta = const VerificationMeta(
    'allowDownload',
  );
  @override
  late final GeneratedColumn<bool> allowDownload = GeneratedColumn<bool>(
    'allow_download',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_download" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _proxyModeMeta = const VerificationMeta(
    'proxyMode',
  );
  @override
  late final GeneratedColumn<String> proxyMode = GeneratedColumn<String>(
    'proxy_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _timeoutMsMeta = const VerificationMeta(
    'timeoutMs',
  );
  @override
  late final GeneratedColumn<int> timeoutMs = GeneratedColumn<int>(
    'timeout_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultLimitMeta = const VerificationMeta(
    'resultLimit',
  );
  @override
  late final GeneratedColumn<int> resultLimit = GeneratedColumn<int>(
    'result_limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
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
  List<GeneratedColumn> get $columns => [
    sourceId,
    isEnabled,
    priority,
    useInGlobalSearch,
    allowStreaming,
    allowDownload,
    proxyMode,
    timeoutMs,
    resultLimit,
    extraJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('use_in_global_search')) {
      context.handle(
        _useInGlobalSearchMeta,
        useInGlobalSearch.isAcceptableOrUnknown(
          data['use_in_global_search']!,
          _useInGlobalSearchMeta,
        ),
      );
    }
    if (data.containsKey('allow_streaming')) {
      context.handle(
        _allowStreamingMeta,
        allowStreaming.isAcceptableOrUnknown(
          data['allow_streaming']!,
          _allowStreamingMeta,
        ),
      );
    }
    if (data.containsKey('allow_download')) {
      context.handle(
        _allowDownloadMeta,
        allowDownload.isAcceptableOrUnknown(
          data['allow_download']!,
          _allowDownloadMeta,
        ),
      );
    }
    if (data.containsKey('proxy_mode')) {
      context.handle(
        _proxyModeMeta,
        proxyMode.isAcceptableOrUnknown(data['proxy_mode']!, _proxyModeMeta),
      );
    }
    if (data.containsKey('timeout_ms')) {
      context.handle(
        _timeoutMsMeta,
        timeoutMs.isAcceptableOrUnknown(data['timeout_ms']!, _timeoutMsMeta),
      );
    }
    if (data.containsKey('result_limit')) {
      context.handle(
        _resultLimitMeta,
        resultLimit.isAcceptableOrUnknown(
          data['result_limit']!,
          _resultLimitMeta,
        ),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {sourceId};
  @override
  SourceSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceSettingsRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      useInGlobalSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_in_global_search'],
      )!,
      allowStreaming: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_streaming'],
      )!,
      allowDownload: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_download'],
      )!,
      proxyMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_mode'],
      )!,
      timeoutMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timeout_ms'],
      ),
      resultLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result_limit'],
      ),
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SourceSettingsRowsTable createAlias(String alias) {
    return $SourceSettingsRowsTable(attachedDatabase, alias);
  }
}

class SourceSettingsRow extends DataClass
    implements Insertable<SourceSettingsRow> {
  final String sourceId;
  final bool isEnabled;
  final int priority;
  final bool useInGlobalSearch;
  final bool allowStreaming;
  final bool allowDownload;
  final String proxyMode;
  final int? timeoutMs;
  final int? resultLimit;
  final String extraJson;
  final DateTime updatedAt;
  const SourceSettingsRow({
    required this.sourceId,
    required this.isEnabled,
    required this.priority,
    required this.useInGlobalSearch,
    required this.allowStreaming,
    required this.allowDownload,
    required this.proxyMode,
    this.timeoutMs,
    this.resultLimit,
    required this.extraJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['priority'] = Variable<int>(priority);
    map['use_in_global_search'] = Variable<bool>(useInGlobalSearch);
    map['allow_streaming'] = Variable<bool>(allowStreaming);
    map['allow_download'] = Variable<bool>(allowDownload);
    map['proxy_mode'] = Variable<String>(proxyMode);
    if (!nullToAbsent || timeoutMs != null) {
      map['timeout_ms'] = Variable<int>(timeoutMs);
    }
    if (!nullToAbsent || resultLimit != null) {
      map['result_limit'] = Variable<int>(resultLimit);
    }
    map['extra_json'] = Variable<String>(extraJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SourceSettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return SourceSettingsRowsCompanion(
      sourceId: Value(sourceId),
      isEnabled: Value(isEnabled),
      priority: Value(priority),
      useInGlobalSearch: Value(useInGlobalSearch),
      allowStreaming: Value(allowStreaming),
      allowDownload: Value(allowDownload),
      proxyMode: Value(proxyMode),
      timeoutMs: timeoutMs == null && nullToAbsent
          ? const Value.absent()
          : Value(timeoutMs),
      resultLimit: resultLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(resultLimit),
      extraJson: Value(extraJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SourceSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceSettingsRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      priority: serializer.fromJson<int>(json['priority']),
      useInGlobalSearch: serializer.fromJson<bool>(json['useInGlobalSearch']),
      allowStreaming: serializer.fromJson<bool>(json['allowStreaming']),
      allowDownload: serializer.fromJson<bool>(json['allowDownload']),
      proxyMode: serializer.fromJson<String>(json['proxyMode']),
      timeoutMs: serializer.fromJson<int?>(json['timeoutMs']),
      resultLimit: serializer.fromJson<int?>(json['resultLimit']),
      extraJson: serializer.fromJson<String>(json['extraJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'priority': serializer.toJson<int>(priority),
      'useInGlobalSearch': serializer.toJson<bool>(useInGlobalSearch),
      'allowStreaming': serializer.toJson<bool>(allowStreaming),
      'allowDownload': serializer.toJson<bool>(allowDownload),
      'proxyMode': serializer.toJson<String>(proxyMode),
      'timeoutMs': serializer.toJson<int?>(timeoutMs),
      'resultLimit': serializer.toJson<int?>(resultLimit),
      'extraJson': serializer.toJson<String>(extraJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SourceSettingsRow copyWith({
    String? sourceId,
    bool? isEnabled,
    int? priority,
    bool? useInGlobalSearch,
    bool? allowStreaming,
    bool? allowDownload,
    String? proxyMode,
    Value<int?> timeoutMs = const Value.absent(),
    Value<int?> resultLimit = const Value.absent(),
    String? extraJson,
    DateTime? updatedAt,
  }) => SourceSettingsRow(
    sourceId: sourceId ?? this.sourceId,
    isEnabled: isEnabled ?? this.isEnabled,
    priority: priority ?? this.priority,
    useInGlobalSearch: useInGlobalSearch ?? this.useInGlobalSearch,
    allowStreaming: allowStreaming ?? this.allowStreaming,
    allowDownload: allowDownload ?? this.allowDownload,
    proxyMode: proxyMode ?? this.proxyMode,
    timeoutMs: timeoutMs.present ? timeoutMs.value : this.timeoutMs,
    resultLimit: resultLimit.present ? resultLimit.value : this.resultLimit,
    extraJson: extraJson ?? this.extraJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SourceSettingsRow copyWithCompanion(SourceSettingsRowsCompanion data) {
    return SourceSettingsRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      priority: data.priority.present ? data.priority.value : this.priority,
      useInGlobalSearch: data.useInGlobalSearch.present
          ? data.useInGlobalSearch.value
          : this.useInGlobalSearch,
      allowStreaming: data.allowStreaming.present
          ? data.allowStreaming.value
          : this.allowStreaming,
      allowDownload: data.allowDownload.present
          ? data.allowDownload.value
          : this.allowDownload,
      proxyMode: data.proxyMode.present ? data.proxyMode.value : this.proxyMode,
      timeoutMs: data.timeoutMs.present ? data.timeoutMs.value : this.timeoutMs,
      resultLimit: data.resultLimit.present
          ? data.resultLimit.value
          : this.resultLimit,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceSettingsRow(')
          ..write('sourceId: $sourceId, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('priority: $priority, ')
          ..write('useInGlobalSearch: $useInGlobalSearch, ')
          ..write('allowStreaming: $allowStreaming, ')
          ..write('allowDownload: $allowDownload, ')
          ..write('proxyMode: $proxyMode, ')
          ..write('timeoutMs: $timeoutMs, ')
          ..write('resultLimit: $resultLimit, ')
          ..write('extraJson: $extraJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    isEnabled,
    priority,
    useInGlobalSearch,
    allowStreaming,
    allowDownload,
    proxyMode,
    timeoutMs,
    resultLimit,
    extraJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceSettingsRow &&
          other.sourceId == this.sourceId &&
          other.isEnabled == this.isEnabled &&
          other.priority == this.priority &&
          other.useInGlobalSearch == this.useInGlobalSearch &&
          other.allowStreaming == this.allowStreaming &&
          other.allowDownload == this.allowDownload &&
          other.proxyMode == this.proxyMode &&
          other.timeoutMs == this.timeoutMs &&
          other.resultLimit == this.resultLimit &&
          other.extraJson == this.extraJson &&
          other.updatedAt == this.updatedAt);
}

class SourceSettingsRowsCompanion extends UpdateCompanion<SourceSettingsRow> {
  final Value<String> sourceId;
  final Value<bool> isEnabled;
  final Value<int> priority;
  final Value<bool> useInGlobalSearch;
  final Value<bool> allowStreaming;
  final Value<bool> allowDownload;
  final Value<String> proxyMode;
  final Value<int?> timeoutMs;
  final Value<int?> resultLimit;
  final Value<String> extraJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SourceSettingsRowsCompanion({
    this.sourceId = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.useInGlobalSearch = const Value.absent(),
    this.allowStreaming = const Value.absent(),
    this.allowDownload = const Value.absent(),
    this.proxyMode = const Value.absent(),
    this.timeoutMs = const Value.absent(),
    this.resultLimit = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceSettingsRowsCompanion.insert({
    required String sourceId,
    this.isEnabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.useInGlobalSearch = const Value.absent(),
    this.allowStreaming = const Value.absent(),
    this.allowDownload = const Value.absent(),
    this.proxyMode = const Value.absent(),
    this.timeoutMs = const Value.absent(),
    this.resultLimit = const Value.absent(),
    this.extraJson = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       updatedAt = Value(updatedAt);
  static Insertable<SourceSettingsRow> custom({
    Expression<String>? sourceId,
    Expression<bool>? isEnabled,
    Expression<int>? priority,
    Expression<bool>? useInGlobalSearch,
    Expression<bool>? allowStreaming,
    Expression<bool>? allowDownload,
    Expression<String>? proxyMode,
    Expression<int>? timeoutMs,
    Expression<int>? resultLimit,
    Expression<String>? extraJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (priority != null) 'priority': priority,
      if (useInGlobalSearch != null) 'use_in_global_search': useInGlobalSearch,
      if (allowStreaming != null) 'allow_streaming': allowStreaming,
      if (allowDownload != null) 'allow_download': allowDownload,
      if (proxyMode != null) 'proxy_mode': proxyMode,
      if (timeoutMs != null) 'timeout_ms': timeoutMs,
      if (resultLimit != null) 'result_limit': resultLimit,
      if (extraJson != null) 'extra_json': extraJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceSettingsRowsCompanion copyWith({
    Value<String>? sourceId,
    Value<bool>? isEnabled,
    Value<int>? priority,
    Value<bool>? useInGlobalSearch,
    Value<bool>? allowStreaming,
    Value<bool>? allowDownload,
    Value<String>? proxyMode,
    Value<int?>? timeoutMs,
    Value<int?>? resultLimit,
    Value<String>? extraJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SourceSettingsRowsCompanion(
      sourceId: sourceId ?? this.sourceId,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
      useInGlobalSearch: useInGlobalSearch ?? this.useInGlobalSearch,
      allowStreaming: allowStreaming ?? this.allowStreaming,
      allowDownload: allowDownload ?? this.allowDownload,
      proxyMode: proxyMode ?? this.proxyMode,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      resultLimit: resultLimit ?? this.resultLimit,
      extraJson: extraJson ?? this.extraJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (useInGlobalSearch.present) {
      map['use_in_global_search'] = Variable<bool>(useInGlobalSearch.value);
    }
    if (allowStreaming.present) {
      map['allow_streaming'] = Variable<bool>(allowStreaming.value);
    }
    if (allowDownload.present) {
      map['allow_download'] = Variable<bool>(allowDownload.value);
    }
    if (proxyMode.present) {
      map['proxy_mode'] = Variable<String>(proxyMode.value);
    }
    if (timeoutMs.present) {
      map['timeout_ms'] = Variable<int>(timeoutMs.value);
    }
    if (resultLimit.present) {
      map['result_limit'] = Variable<int>(resultLimit.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
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
    return (StringBuffer('SourceSettingsRowsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('priority: $priority, ')
          ..write('useInGlobalSearch: $useInGlobalSearch, ')
          ..write('allowStreaming: $allowStreaming, ')
          ..write('allowDownload: $allowDownload, ')
          ..write('proxyMode: $proxyMode, ')
          ..write('timeoutMs: $timeoutMs, ')
          ..write('resultLimit: $resultLimit, ')
          ..write('extraJson: $extraJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $BookVersionsTable bookVersions = $BookVersionsTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $AudioTracksTable audioTracks = $AudioTracksTable(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $SourceHealthRowsTable sourceHealthRows = $SourceHealthRowsTable(
    this,
  );
  late final $PlaybackSessionsTable playbackSessions = $PlaybackSessionsTable(
    this,
  );
  late final $PlaybackProgressEntriesTable playbackProgressEntries =
      $PlaybackProgressEntriesTable(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $SearchHistoryRowsTable searchHistoryRows =
      $SearchHistoryRowsTable(this);
  late final $AppSettingsRowsTable appSettingsRows = $AppSettingsRowsTable(
    this,
  );
  late final $ProxyProfilesTable proxyProfiles = $ProxyProfilesTable(this);
  late final $SourceSettingsRowsTable sourceSettingsRows =
      $SourceSettingsRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    bookVersions,
    chapters,
    audioTracks,
    sources,
    sourceHealthRows,
    playbackSessions,
    playbackProgressEntries,
    downloadTasks,
    favorites,
    bookmarks,
    searchHistoryRows,
    appSettingsRows,
    proxyProfiles,
    sourceSettingsRows,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String normalizedTitle,
      required String displayTitle,
      required String authorsJson,
      Value<String?> seriesTitle,
      Value<double?> seriesNumber,
      Value<int?> year,
      Value<String?> bestCoverUrl,
      Value<String?> bestLocalCoverPath,
      Value<String?> bestDescription,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> normalizedTitle,
      Value<String> displayTitle,
      Value<String> authorsJson,
      Value<String?> seriesTitle,
      Value<double?> seriesNumber,
      Value<int?> year,
      Value<String?> bestCoverUrl,
      Value<String?> bestLocalCoverPath,
      Value<String?> bestDescription,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
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

  ColumnFilters<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayTitle => $composableBuilder(
    column: $table.displayTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesTitle => $composableBuilder(
    column: $table.seriesTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bestCoverUrl => $composableBuilder(
    column: $table.bestCoverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bestLocalCoverPath => $composableBuilder(
    column: $table.bestLocalCoverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bestDescription => $composableBuilder(
    column: $table.bestDescription,
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
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
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

  ColumnOrderings<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayTitle => $composableBuilder(
    column: $table.displayTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesTitle => $composableBuilder(
    column: $table.seriesTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bestCoverUrl => $composableBuilder(
    column: $table.bestCoverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bestLocalCoverPath => $composableBuilder(
    column: $table.bestLocalCoverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bestDescription => $composableBuilder(
    column: $table.bestDescription,
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
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayTitle => $composableBuilder(
    column: $table.displayTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seriesTitle => $composableBuilder(
    column: $table.seriesTitle,
    builder: (column) => column,
  );

  GeneratedColumn<double> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get bestCoverUrl => $composableBuilder(
    column: $table.bestCoverUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bestLocalCoverPath => $composableBuilder(
    column: $table.bestLocalCoverPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bestDescription => $composableBuilder(
    column: $table.bestDescription,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          BookRow,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
          BookRow,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> normalizedTitle = const Value.absent(),
                Value<String> displayTitle = const Value.absent(),
                Value<String> authorsJson = const Value.absent(),
                Value<String?> seriesTitle = const Value.absent(),
                Value<double?> seriesNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> bestCoverUrl = const Value.absent(),
                Value<String?> bestLocalCoverPath = const Value.absent(),
                Value<String?> bestDescription = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                normalizedTitle: normalizedTitle,
                displayTitle: displayTitle,
                authorsJson: authorsJson,
                seriesTitle: seriesTitle,
                seriesNumber: seriesNumber,
                year: year,
                bestCoverUrl: bestCoverUrl,
                bestLocalCoverPath: bestLocalCoverPath,
                bestDescription: bestDescription,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String normalizedTitle,
                required String displayTitle,
                required String authorsJson,
                Value<String?> seriesTitle = const Value.absent(),
                Value<double?> seriesNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> bestCoverUrl = const Value.absent(),
                Value<String?> bestLocalCoverPath = const Value.absent(),
                Value<String?> bestDescription = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                normalizedTitle: normalizedTitle,
                displayTitle: displayTitle,
                authorsJson: authorsJson,
                seriesTitle: seriesTitle,
                seriesNumber: seriesNumber,
                year: year,
                bestCoverUrl: bestCoverUrl,
                bestLocalCoverPath: bestLocalCoverPath,
                bestDescription: bestDescription,
                createdAt: createdAt,
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

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      BookRow,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookRow, BaseReferences<_$AppDatabase, $BooksTable, BookRow>),
      BookRow,
      PrefetchHooks Function()
    >;
typedef $$BookVersionsTableCreateCompanionBuilder =
    BookVersionsCompanion Function({
      required String id,
      required String bookId,
      required String sourceId,
      required String sourceBookId,
      Value<String?> sourceUrl,
      required String title,
      required String normalizedTitle,
      required String authorsJson,
      required String narratorsJson,
      Value<String> translatorsJson,
      Value<String?> seriesTitle,
      Value<double?> seriesNumber,
      Value<String> genresJson,
      Value<String> tagsJson,
      Value<String?> description,
      Value<String?> coverUrl,
      Value<String?> localCoverPath,
      Value<int?> durationMs,
      Value<String?> durationText,
      Value<int?> publishedYear,
      Value<int?> audioYear,
      Value<double?> ratingValue,
      Value<int?> ratingCount,
      required String accessType,
      required String playbackAccess,
      Value<bool> isFull,
      Value<bool> isFragment,
      Value<bool> isPaid,
      Value<bool> isSubscription,
      Value<bool> isAccessibleForFree,
      Value<bool> canStream,
      Value<bool> canDownload,
      Value<String?> rawSourceDataJson,
      Value<DateTime?> lastResolvedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BookVersionsTableUpdateCompanionBuilder =
    BookVersionsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> sourceId,
      Value<String> sourceBookId,
      Value<String?> sourceUrl,
      Value<String> title,
      Value<String> normalizedTitle,
      Value<String> authorsJson,
      Value<String> narratorsJson,
      Value<String> translatorsJson,
      Value<String?> seriesTitle,
      Value<double?> seriesNumber,
      Value<String> genresJson,
      Value<String> tagsJson,
      Value<String?> description,
      Value<String?> coverUrl,
      Value<String?> localCoverPath,
      Value<int?> durationMs,
      Value<String?> durationText,
      Value<int?> publishedYear,
      Value<int?> audioYear,
      Value<double?> ratingValue,
      Value<int?> ratingCount,
      Value<String> accessType,
      Value<String> playbackAccess,
      Value<bool> isFull,
      Value<bool> isFragment,
      Value<bool> isPaid,
      Value<bool> isSubscription,
      Value<bool> isAccessibleForFree,
      Value<bool> canStream,
      Value<bool> canDownload,
      Value<String?> rawSourceDataJson,
      Value<DateTime?> lastResolvedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BookVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $BookVersionsTable> {
  $$BookVersionsTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narratorsJson => $composableBuilder(
    column: $table.narratorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatorsJson => $composableBuilder(
    column: $table.translatorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesTitle => $composableBuilder(
    column: $table.seriesTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localCoverPath => $composableBuilder(
    column: $table.localCoverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get durationText => $composableBuilder(
    column: $table.durationText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedYear => $composableBuilder(
    column: $table.publishedYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioYear => $composableBuilder(
    column: $table.audioYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ratingValue => $composableBuilder(
    column: $table.ratingValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessType => $composableBuilder(
    column: $table.accessType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackAccess => $composableBuilder(
    column: $table.playbackAccess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFull => $composableBuilder(
    column: $table.isFull,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFragment => $composableBuilder(
    column: $table.isFragment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPaid => $composableBuilder(
    column: $table.isPaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSubscription => $composableBuilder(
    column: $table.isSubscription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAccessibleForFree => $composableBuilder(
    column: $table.isAccessibleForFree,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get canStream => $composableBuilder(
    column: $table.canStream,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get canDownload => $composableBuilder(
    column: $table.canDownload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastResolvedAt => $composableBuilder(
    column: $table.lastResolvedAt,
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
}

class $$BookVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookVersionsTable> {
  $$BookVersionsTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narratorsJson => $composableBuilder(
    column: $table.narratorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatorsJson => $composableBuilder(
    column: $table.translatorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesTitle => $composableBuilder(
    column: $table.seriesTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localCoverPath => $composableBuilder(
    column: $table.localCoverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get durationText => $composableBuilder(
    column: $table.durationText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedYear => $composableBuilder(
    column: $table.publishedYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioYear => $composableBuilder(
    column: $table.audioYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ratingValue => $composableBuilder(
    column: $table.ratingValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessType => $composableBuilder(
    column: $table.accessType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackAccess => $composableBuilder(
    column: $table.playbackAccess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFull => $composableBuilder(
    column: $table.isFull,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFragment => $composableBuilder(
    column: $table.isFragment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPaid => $composableBuilder(
    column: $table.isPaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSubscription => $composableBuilder(
    column: $table.isSubscription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAccessibleForFree => $composableBuilder(
    column: $table.isAccessibleForFree,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get canStream => $composableBuilder(
    column: $table.canStream,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get canDownload => $composableBuilder(
    column: $table.canDownload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastResolvedAt => $composableBuilder(
    column: $table.lastResolvedAt,
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
}

class $$BookVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookVersionsTable> {
  $$BookVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorsJson => $composableBuilder(
    column: $table.authorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get narratorsJson => $composableBuilder(
    column: $table.narratorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatorsJson => $composableBuilder(
    column: $table.translatorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seriesTitle => $composableBuilder(
    column: $table.seriesTitle,
    builder: (column) => column,
  );

  GeneratedColumn<double> get seriesNumber => $composableBuilder(
    column: $table.seriesNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get localCoverPath => $composableBuilder(
    column: $table.localCoverPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get durationText => $composableBuilder(
    column: $table.durationText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get publishedYear => $composableBuilder(
    column: $table.publishedYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioYear =>
      $composableBuilder(column: $table.audioYear, builder: (column) => column);

  GeneratedColumn<double> get ratingValue => $composableBuilder(
    column: $table.ratingValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accessType => $composableBuilder(
    column: $table.accessType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playbackAccess => $composableBuilder(
    column: $table.playbackAccess,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFull =>
      $composableBuilder(column: $table.isFull, builder: (column) => column);

  GeneratedColumn<bool> get isFragment => $composableBuilder(
    column: $table.isFragment,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPaid =>
      $composableBuilder(column: $table.isPaid, builder: (column) => column);

  GeneratedColumn<bool> get isSubscription => $composableBuilder(
    column: $table.isSubscription,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAccessibleForFree => $composableBuilder(
    column: $table.isAccessibleForFree,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get canStream =>
      $composableBuilder(column: $table.canStream, builder: (column) => column);

  GeneratedColumn<bool> get canDownload => $composableBuilder(
    column: $table.canDownload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastResolvedAt => $composableBuilder(
    column: $table.lastResolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookVersionsTable,
          BookVersionRow,
          $$BookVersionsTableFilterComposer,
          $$BookVersionsTableOrderingComposer,
          $$BookVersionsTableAnnotationComposer,
          $$BookVersionsTableCreateCompanionBuilder,
          $$BookVersionsTableUpdateCompanionBuilder,
          (
            BookVersionRow,
            BaseReferences<_$AppDatabase, $BookVersionsTable, BookVersionRow>,
          ),
          BookVersionRow,
          PrefetchHooks Function()
        > {
  $$BookVersionsTableTableManager(_$AppDatabase db, $BookVersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceBookId = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> normalizedTitle = const Value.absent(),
                Value<String> authorsJson = const Value.absent(),
                Value<String> narratorsJson = const Value.absent(),
                Value<String> translatorsJson = const Value.absent(),
                Value<String?> seriesTitle = const Value.absent(),
                Value<double?> seriesNumber = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> localCoverPath = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> durationText = const Value.absent(),
                Value<int?> publishedYear = const Value.absent(),
                Value<int?> audioYear = const Value.absent(),
                Value<double?> ratingValue = const Value.absent(),
                Value<int?> ratingCount = const Value.absent(),
                Value<String> accessType = const Value.absent(),
                Value<String> playbackAccess = const Value.absent(),
                Value<bool> isFull = const Value.absent(),
                Value<bool> isFragment = const Value.absent(),
                Value<bool> isPaid = const Value.absent(),
                Value<bool> isSubscription = const Value.absent(),
                Value<bool> isAccessibleForFree = const Value.absent(),
                Value<bool> canStream = const Value.absent(),
                Value<bool> canDownload = const Value.absent(),
                Value<String?> rawSourceDataJson = const Value.absent(),
                Value<DateTime?> lastResolvedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookVersionsCompanion(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                sourceBookId: sourceBookId,
                sourceUrl: sourceUrl,
                title: title,
                normalizedTitle: normalizedTitle,
                authorsJson: authorsJson,
                narratorsJson: narratorsJson,
                translatorsJson: translatorsJson,
                seriesTitle: seriesTitle,
                seriesNumber: seriesNumber,
                genresJson: genresJson,
                tagsJson: tagsJson,
                description: description,
                coverUrl: coverUrl,
                localCoverPath: localCoverPath,
                durationMs: durationMs,
                durationText: durationText,
                publishedYear: publishedYear,
                audioYear: audioYear,
                ratingValue: ratingValue,
                ratingCount: ratingCount,
                accessType: accessType,
                playbackAccess: playbackAccess,
                isFull: isFull,
                isFragment: isFragment,
                isPaid: isPaid,
                isSubscription: isSubscription,
                isAccessibleForFree: isAccessibleForFree,
                canStream: canStream,
                canDownload: canDownload,
                rawSourceDataJson: rawSourceDataJson,
                lastResolvedAt: lastResolvedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String sourceId,
                required String sourceBookId,
                Value<String?> sourceUrl = const Value.absent(),
                required String title,
                required String normalizedTitle,
                required String authorsJson,
                required String narratorsJson,
                Value<String> translatorsJson = const Value.absent(),
                Value<String?> seriesTitle = const Value.absent(),
                Value<double?> seriesNumber = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> localCoverPath = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> durationText = const Value.absent(),
                Value<int?> publishedYear = const Value.absent(),
                Value<int?> audioYear = const Value.absent(),
                Value<double?> ratingValue = const Value.absent(),
                Value<int?> ratingCount = const Value.absent(),
                required String accessType,
                required String playbackAccess,
                Value<bool> isFull = const Value.absent(),
                Value<bool> isFragment = const Value.absent(),
                Value<bool> isPaid = const Value.absent(),
                Value<bool> isSubscription = const Value.absent(),
                Value<bool> isAccessibleForFree = const Value.absent(),
                Value<bool> canStream = const Value.absent(),
                Value<bool> canDownload = const Value.absent(),
                Value<String?> rawSourceDataJson = const Value.absent(),
                Value<DateTime?> lastResolvedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookVersionsCompanion.insert(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                sourceBookId: sourceBookId,
                sourceUrl: sourceUrl,
                title: title,
                normalizedTitle: normalizedTitle,
                authorsJson: authorsJson,
                narratorsJson: narratorsJson,
                translatorsJson: translatorsJson,
                seriesTitle: seriesTitle,
                seriesNumber: seriesNumber,
                genresJson: genresJson,
                tagsJson: tagsJson,
                description: description,
                coverUrl: coverUrl,
                localCoverPath: localCoverPath,
                durationMs: durationMs,
                durationText: durationText,
                publishedYear: publishedYear,
                audioYear: audioYear,
                ratingValue: ratingValue,
                ratingCount: ratingCount,
                accessType: accessType,
                playbackAccess: playbackAccess,
                isFull: isFull,
                isFragment: isFragment,
                isPaid: isPaid,
                isSubscription: isSubscription,
                isAccessibleForFree: isAccessibleForFree,
                canStream: canStream,
                canDownload: canDownload,
                rawSourceDataJson: rawSourceDataJson,
                lastResolvedAt: lastResolvedAt,
                createdAt: createdAt,
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

typedef $$BookVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookVersionsTable,
      BookVersionRow,
      $$BookVersionsTableFilterComposer,
      $$BookVersionsTableOrderingComposer,
      $$BookVersionsTableAnnotationComposer,
      $$BookVersionsTableCreateCompanionBuilder,
      $$BookVersionsTableUpdateCompanionBuilder,
      (
        BookVersionRow,
        BaseReferences<_$AppDatabase, $BookVersionsTable, BookVersionRow>,
      ),
      BookVersionRow,
      PrefetchHooks Function()
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      required String id,
      required String bookVersionId,
      required String sourceId,
      Value<String?> sourceBookId,
      Value<String?> sourceChapterId,
      required int index,
      required String title,
      required String normalizedTitle,
      Value<int?> durationMs,
      Value<String?> streamRef,
      Value<String?> cachedStreamUrl,
      Value<DateTime?> cachedStreamUrlUpdatedAt,
      Value<DateTime?> cachedStreamUrlExpiresAt,
      Value<String?> audioFormat,
      Value<String?> mimeType,
      Value<String?> rawSourceDataJson,
      Value<String?> localPath,
      Value<int?> fileSizeBytes,
      Value<String> downloadStatus,
      Value<double> downloadProgress,
      Value<int> playbackPositionMs,
      Value<bool> isFinished,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<String> id,
      Value<String> bookVersionId,
      Value<String> sourceId,
      Value<String?> sourceBookId,
      Value<String?> sourceChapterId,
      Value<int> index,
      Value<String> title,
      Value<String> normalizedTitle,
      Value<int?> durationMs,
      Value<String?> streamRef,
      Value<String?> cachedStreamUrl,
      Value<DateTime?> cachedStreamUrlUpdatedAt,
      Value<DateTime?> cachedStreamUrlExpiresAt,
      Value<String?> audioFormat,
      Value<String?> mimeType,
      Value<String?> rawSourceDataJson,
      Value<String?> localPath,
      Value<int?> fileSizeBytes,
      Value<String> downloadStatus,
      Value<double> downloadProgress,
      Value<int> playbackPositionMs,
      Value<bool> isFinished,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
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

  ColumnFilters<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamRef => $composableBuilder(
    column: $table.streamRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cachedStreamUrl => $composableBuilder(
    column: $table.cachedStreamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedStreamUrlUpdatedAt => $composableBuilder(
    column: $table.cachedStreamUrlUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedStreamUrlExpiresAt => $composableBuilder(
    column: $table.cachedStreamUrlExpiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get downloadProgress => $composableBuilder(
    column: $table.downloadProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playbackPositionMs => $composableBuilder(
    column: $table.playbackPositionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
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
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
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

  ColumnOrderings<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamRef => $composableBuilder(
    column: $table.streamRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachedStreamUrl => $composableBuilder(
    column: $table.cachedStreamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedStreamUrlUpdatedAt => $composableBuilder(
    column: $table.cachedStreamUrlUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedStreamUrlExpiresAt => $composableBuilder(
    column: $table.cachedStreamUrlExpiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get downloadProgress => $composableBuilder(
    column: $table.downloadProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playbackPositionMs => $composableBuilder(
    column: $table.playbackPositionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
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
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get index =>
      $composableBuilder(column: $table.index, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamRef =>
      $composableBuilder(column: $table.streamRef, builder: (column) => column);

  GeneratedColumn<String> get cachedStreamUrl => $composableBuilder(
    column: $table.cachedStreamUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedStreamUrlUpdatedAt => $composableBuilder(
    column: $table.cachedStreamUrlUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedStreamUrlExpiresAt => $composableBuilder(
    column: $table.cachedStreamUrlExpiresAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get downloadProgress => $composableBuilder(
    column: $table.downloadProgress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playbackPositionMs => $composableBuilder(
    column: $table.playbackPositionMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          ChapterRow,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (
            ChapterRow,
            BaseReferences<_$AppDatabase, $ChaptersTable, ChapterRow>,
          ),
          ChapterRow,
          PrefetchHooks Function()
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookVersionId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> sourceBookId = const Value.absent(),
                Value<String?> sourceChapterId = const Value.absent(),
                Value<int> index = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> normalizedTitle = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> streamRef = const Value.absent(),
                Value<String?> cachedStreamUrl = const Value.absent(),
                Value<DateTime?> cachedStreamUrlUpdatedAt =
                    const Value.absent(),
                Value<DateTime?> cachedStreamUrlExpiresAt =
                    const Value.absent(),
                Value<String?> audioFormat = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> rawSourceDataJson = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<String> downloadStatus = const Value.absent(),
                Value<double> downloadProgress = const Value.absent(),
                Value<int> playbackPositionMs = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                bookVersionId: bookVersionId,
                sourceId: sourceId,
                sourceBookId: sourceBookId,
                sourceChapterId: sourceChapterId,
                index: index,
                title: title,
                normalizedTitle: normalizedTitle,
                durationMs: durationMs,
                streamRef: streamRef,
                cachedStreamUrl: cachedStreamUrl,
                cachedStreamUrlUpdatedAt: cachedStreamUrlUpdatedAt,
                cachedStreamUrlExpiresAt: cachedStreamUrlExpiresAt,
                audioFormat: audioFormat,
                mimeType: mimeType,
                rawSourceDataJson: rawSourceDataJson,
                localPath: localPath,
                fileSizeBytes: fileSizeBytes,
                downloadStatus: downloadStatus,
                downloadProgress: downloadProgress,
                playbackPositionMs: playbackPositionMs,
                isFinished: isFinished,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookVersionId,
                required String sourceId,
                Value<String?> sourceBookId = const Value.absent(),
                Value<String?> sourceChapterId = const Value.absent(),
                required int index,
                required String title,
                required String normalizedTitle,
                Value<int?> durationMs = const Value.absent(),
                Value<String?> streamRef = const Value.absent(),
                Value<String?> cachedStreamUrl = const Value.absent(),
                Value<DateTime?> cachedStreamUrlUpdatedAt =
                    const Value.absent(),
                Value<DateTime?> cachedStreamUrlExpiresAt =
                    const Value.absent(),
                Value<String?> audioFormat = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> rawSourceDataJson = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<String> downloadStatus = const Value.absent(),
                Value<double> downloadProgress = const Value.absent(),
                Value<int> playbackPositionMs = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                bookVersionId: bookVersionId,
                sourceId: sourceId,
                sourceBookId: sourceBookId,
                sourceChapterId: sourceChapterId,
                index: index,
                title: title,
                normalizedTitle: normalizedTitle,
                durationMs: durationMs,
                streamRef: streamRef,
                cachedStreamUrl: cachedStreamUrl,
                cachedStreamUrlUpdatedAt: cachedStreamUrlUpdatedAt,
                cachedStreamUrlExpiresAt: cachedStreamUrlExpiresAt,
                audioFormat: audioFormat,
                mimeType: mimeType,
                rawSourceDataJson: rawSourceDataJson,
                localPath: localPath,
                fileSizeBytes: fileSizeBytes,
                downloadStatus: downloadStatus,
                downloadProgress: downloadProgress,
                playbackPositionMs: playbackPositionMs,
                isFinished: isFinished,
                createdAt: createdAt,
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

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      ChapterRow,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (ChapterRow, BaseReferences<_$AppDatabase, $ChaptersTable, ChapterRow>),
      ChapterRow,
      PrefetchHooks Function()
    >;
typedef $$AudioTracksTableCreateCompanionBuilder =
    AudioTracksCompanion Function({
      required String id,
      required String chapterId,
      required String sourceId,
      required int index,
      Value<String?> title,
      Value<int?> durationMs,
      required String mediaRef,
      Value<String?> directUrl,
      Value<String?> headersJson,
      Value<String?> format,
      Value<String?> mimeType,
      Value<DateTime?> expiresAt,
      Value<String?> rawSourceDataJson,
      Value<int> rowid,
    });
typedef $$AudioTracksTableUpdateCompanionBuilder =
    AudioTracksCompanion Function({
      Value<String> id,
      Value<String> chapterId,
      Value<String> sourceId,
      Value<int> index,
      Value<String?> title,
      Value<int?> durationMs,
      Value<String> mediaRef,
      Value<String?> directUrl,
      Value<String?> headersJson,
      Value<String?> format,
      Value<String?> mimeType,
      Value<DateTime?> expiresAt,
      Value<String?> rawSourceDataJson,
      Value<int> rowid,
    });

class $$AudioTracksTableFilterComposer
    extends Composer<_$AppDatabase, $AudioTracksTable> {
  $$AudioTracksTableFilterComposer({
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

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaRef => $composableBuilder(
    column: $table.mediaRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioTracksTable> {
  $$AudioTracksTableOrderingComposer({
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

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaRef => $composableBuilder(
    column: $table.mediaRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioTracksTable> {
  $$AudioTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get index =>
      $composableBuilder(column: $table.index, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaRef =>
      $composableBuilder(column: $table.mediaRef, builder: (column) => column);

  GeneratedColumn<String> get directUrl =>
      $composableBuilder(column: $table.directUrl, builder: (column) => column);

  GeneratedColumn<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get rawSourceDataJson => $composableBuilder(
    column: $table.rawSourceDataJson,
    builder: (column) => column,
  );
}

class $$AudioTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioTracksTable,
          AudioTrackRow,
          $$AudioTracksTableFilterComposer,
          $$AudioTracksTableOrderingComposer,
          $$AudioTracksTableAnnotationComposer,
          $$AudioTracksTableCreateCompanionBuilder,
          $$AudioTracksTableUpdateCompanionBuilder,
          (
            AudioTrackRow,
            BaseReferences<_$AppDatabase, $AudioTracksTable, AudioTrackRow>,
          ),
          AudioTrackRow,
          PrefetchHooks Function()
        > {
  $$AudioTracksTableTableManager(_$AppDatabase db, $AudioTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> index = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> mediaRef = const Value.absent(),
                Value<String?> directUrl = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<String?> rawSourceDataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioTracksCompanion(
                id: id,
                chapterId: chapterId,
                sourceId: sourceId,
                index: index,
                title: title,
                durationMs: durationMs,
                mediaRef: mediaRef,
                directUrl: directUrl,
                headersJson: headersJson,
                format: format,
                mimeType: mimeType,
                expiresAt: expiresAt,
                rawSourceDataJson: rawSourceDataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chapterId,
                required String sourceId,
                required int index,
                Value<String?> title = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required String mediaRef,
                Value<String?> directUrl = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<String?> rawSourceDataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioTracksCompanion.insert(
                id: id,
                chapterId: chapterId,
                sourceId: sourceId,
                index: index,
                title: title,
                durationMs: durationMs,
                mediaRef: mediaRef,
                directUrl: directUrl,
                headersJson: headersJson,
                format: format,
                mimeType: mimeType,
                expiresAt: expiresAt,
                rawSourceDataJson: rawSourceDataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioTracksTable,
      AudioTrackRow,
      $$AudioTracksTableFilterComposer,
      $$AudioTracksTableOrderingComposer,
      $$AudioTracksTableAnnotationComposer,
      $$AudioTracksTableCreateCompanionBuilder,
      $$AudioTracksTableUpdateCompanionBuilder,
      (
        AudioTrackRow,
        BaseReferences<_$AppDatabase, $AudioTracksTable, AudioTrackRow>,
      ),
      AudioTrackRow,
      PrefetchHooks Function()
    >;
typedef $$SourcesTableCreateCompanionBuilder =
    SourcesCompanion Function({
      required String id,
      required String name,
      required String host,
      Value<String?> color,
      Value<String> capabilitiesJson,
      Value<bool> isEnabled,
      Value<int> priority,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SourcesTableUpdateCompanionBuilder =
    SourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> host,
      Value<String?> color,
      Value<String> capabilitiesJson,
      Value<bool> isEnabled,
      Value<int> priority,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SourcesTableFilterComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
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
}

class $$SourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
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
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourcesTable,
          SourceRow,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (SourceRow, BaseReferences<_$AppDatabase, $SourcesTable, SourceRow>),
          SourceRow,
          PrefetchHooks Function()
        > {
  $$SourcesTableTableManager(_$AppDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                name: name,
                host: host,
                color: color,
                capabilitiesJson: capabilitiesJson,
                isEnabled: isEnabled,
                priority: priority,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String host,
                Value<String?> color = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                name: name,
                host: host,
                color: color,
                capabilitiesJson: capabilitiesJson,
                isEnabled: isEnabled,
                priority: priority,
                createdAt: createdAt,
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

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourcesTable,
      SourceRow,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (SourceRow, BaseReferences<_$AppDatabase, $SourcesTable, SourceRow>),
      SourceRow,
      PrefetchHooks Function()
    >;
typedef $$SourceHealthRowsTableCreateCompanionBuilder =
    SourceHealthRowsCompanion Function({
      required String sourceId,
      Value<String> status,
      Value<int?> latencyMs,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      required DateTime checkedAt,
      Value<int> rowid,
    });
typedef $$SourceHealthRowsTableUpdateCompanionBuilder =
    SourceHealthRowsCompanion Function({
      Value<String> sourceId,
      Value<String> status,
      Value<int?> latencyMs,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime> checkedAt,
      Value<int> rowid,
    });

class $$SourceHealthRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SourceHealthRowsTable> {
  $$SourceHealthRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceHealthRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceHealthRowsTable> {
  $$SourceHealthRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceHealthRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceHealthRowsTable> {
  $$SourceHealthRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$SourceHealthRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceHealthRowsTable,
          SourceHealthRow,
          $$SourceHealthRowsTableFilterComposer,
          $$SourceHealthRowsTableOrderingComposer,
          $$SourceHealthRowsTableAnnotationComposer,
          $$SourceHealthRowsTableCreateCompanionBuilder,
          $$SourceHealthRowsTableUpdateCompanionBuilder,
          (
            SourceHealthRow,
            BaseReferences<
              _$AppDatabase,
              $SourceHealthRowsTable,
              SourceHealthRow
            >,
          ),
          SourceHealthRow,
          PrefetchHooks Function()
        > {
  $$SourceHealthRowsTableTableManager(
    _$AppDatabase db,
    $SourceHealthRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceHealthRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceHealthRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceHealthRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceHealthRowsCompanion(
                sourceId: sourceId,
                status: status,
                latencyMs: latencyMs,
                errorCode: errorCode,
                errorMessage: errorMessage,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                Value<String> status = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required DateTime checkedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourceHealthRowsCompanion.insert(
                sourceId: sourceId,
                status: status,
                latencyMs: latencyMs,
                errorCode: errorCode,
                errorMessage: errorMessage,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceHealthRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceHealthRowsTable,
      SourceHealthRow,
      $$SourceHealthRowsTableFilterComposer,
      $$SourceHealthRowsTableOrderingComposer,
      $$SourceHealthRowsTableAnnotationComposer,
      $$SourceHealthRowsTableCreateCompanionBuilder,
      $$SourceHealthRowsTableUpdateCompanionBuilder,
      (
        SourceHealthRow,
        BaseReferences<_$AppDatabase, $SourceHealthRowsTable, SourceHealthRow>,
      ),
      SourceHealthRow,
      PrefetchHooks Function()
    >;
typedef $$PlaybackSessionsTableCreateCompanionBuilder =
    PlaybackSessionsCompanion Function({
      required String id,
      Value<String?> activeBookId,
      Value<String?> activeBookVersionId,
      Value<String?> activeSourceId,
      Value<String?> activeChapterId,
      Value<int> positionMs,
      Value<double> speed,
      Value<double> volume,
      Value<bool> isPlaying,
      Value<int> playerPageIndex,
      Value<int?> sleepTimerRemainingMs,
      Value<String> sleepTimerMode,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlaybackSessionsTableUpdateCompanionBuilder =
    PlaybackSessionsCompanion Function({
      Value<String> id,
      Value<String?> activeBookId,
      Value<String?> activeBookVersionId,
      Value<String?> activeSourceId,
      Value<String?> activeChapterId,
      Value<int> positionMs,
      Value<double> speed,
      Value<double> volume,
      Value<bool> isPlaying,
      Value<int> playerPageIndex,
      Value<int?> sleepTimerRemainingMs,
      Value<String> sleepTimerMode,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PlaybackSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackSessionsTable> {
  $$PlaybackSessionsTableFilterComposer({
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

  ColumnFilters<String> get activeBookId => $composableBuilder(
    column: $table.activeBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeBookVersionId => $composableBuilder(
    column: $table.activeBookVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeSourceId => $composableBuilder(
    column: $table.activeSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeChapterId => $composableBuilder(
    column: $table.activeChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlaying => $composableBuilder(
    column: $table.isPlaying,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playerPageIndex => $composableBuilder(
    column: $table.playerPageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sleepTimerRemainingMs => $composableBuilder(
    column: $table.sleepTimerRemainingMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sleepTimerMode => $composableBuilder(
    column: $table.sleepTimerMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackSessionsTable> {
  $$PlaybackSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get activeBookId => $composableBuilder(
    column: $table.activeBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeBookVersionId => $composableBuilder(
    column: $table.activeBookVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeSourceId => $composableBuilder(
    column: $table.activeSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeChapterId => $composableBuilder(
    column: $table.activeChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlaying => $composableBuilder(
    column: $table.isPlaying,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playerPageIndex => $composableBuilder(
    column: $table.playerPageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sleepTimerRemainingMs => $composableBuilder(
    column: $table.sleepTimerRemainingMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sleepTimerMode => $composableBuilder(
    column: $table.sleepTimerMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackSessionsTable> {
  $$PlaybackSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activeBookId => $composableBuilder(
    column: $table.activeBookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeBookVersionId => $composableBuilder(
    column: $table.activeBookVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeSourceId => $composableBuilder(
    column: $table.activeSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeChapterId => $composableBuilder(
    column: $table.activeChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<bool> get isPlaying =>
      $composableBuilder(column: $table.isPlaying, builder: (column) => column);

  GeneratedColumn<int> get playerPageIndex => $composableBuilder(
    column: $table.playerPageIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sleepTimerRemainingMs => $composableBuilder(
    column: $table.sleepTimerRemainingMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sleepTimerMode => $composableBuilder(
    column: $table.sleepTimerMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackSessionsTable,
          PlaybackSessionRow,
          $$PlaybackSessionsTableFilterComposer,
          $$PlaybackSessionsTableOrderingComposer,
          $$PlaybackSessionsTableAnnotationComposer,
          $$PlaybackSessionsTableCreateCompanionBuilder,
          $$PlaybackSessionsTableUpdateCompanionBuilder,
          (
            PlaybackSessionRow,
            BaseReferences<
              _$AppDatabase,
              $PlaybackSessionsTable,
              PlaybackSessionRow
            >,
          ),
          PlaybackSessionRow,
          PrefetchHooks Function()
        > {
  $$PlaybackSessionsTableTableManager(
    _$AppDatabase db,
    $PlaybackSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> activeBookId = const Value.absent(),
                Value<String?> activeBookVersionId = const Value.absent(),
                Value<String?> activeSourceId = const Value.absent(),
                Value<String?> activeChapterId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<bool> isPlaying = const Value.absent(),
                Value<int> playerPageIndex = const Value.absent(),
                Value<int?> sleepTimerRemainingMs = const Value.absent(),
                Value<String> sleepTimerMode = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackSessionsCompanion(
                id: id,
                activeBookId: activeBookId,
                activeBookVersionId: activeBookVersionId,
                activeSourceId: activeSourceId,
                activeChapterId: activeChapterId,
                positionMs: positionMs,
                speed: speed,
                volume: volume,
                isPlaying: isPlaying,
                playerPageIndex: playerPageIndex,
                sleepTimerRemainingMs: sleepTimerRemainingMs,
                sleepTimerMode: sleepTimerMode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> activeBookId = const Value.absent(),
                Value<String?> activeBookVersionId = const Value.absent(),
                Value<String?> activeSourceId = const Value.absent(),
                Value<String?> activeChapterId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<bool> isPlaying = const Value.absent(),
                Value<int> playerPageIndex = const Value.absent(),
                Value<int?> sleepTimerRemainingMs = const Value.absent(),
                Value<String> sleepTimerMode = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackSessionsCompanion.insert(
                id: id,
                activeBookId: activeBookId,
                activeBookVersionId: activeBookVersionId,
                activeSourceId: activeSourceId,
                activeChapterId: activeChapterId,
                positionMs: positionMs,
                speed: speed,
                volume: volume,
                isPlaying: isPlaying,
                playerPageIndex: playerPageIndex,
                sleepTimerRemainingMs: sleepTimerRemainingMs,
                sleepTimerMode: sleepTimerMode,
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

typedef $$PlaybackSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackSessionsTable,
      PlaybackSessionRow,
      $$PlaybackSessionsTableFilterComposer,
      $$PlaybackSessionsTableOrderingComposer,
      $$PlaybackSessionsTableAnnotationComposer,
      $$PlaybackSessionsTableCreateCompanionBuilder,
      $$PlaybackSessionsTableUpdateCompanionBuilder,
      (
        PlaybackSessionRow,
        BaseReferences<
          _$AppDatabase,
          $PlaybackSessionsTable,
          PlaybackSessionRow
        >,
      ),
      PlaybackSessionRow,
      PrefetchHooks Function()
    >;
typedef $$PlaybackProgressEntriesTableCreateCompanionBuilder =
    PlaybackProgressEntriesCompanion Function({
      required String bookId,
      required String bookVersionId,
      Value<String?> currentChapterId,
      Value<int> currentPositionMs,
      Value<int> maxReachedGlobalPositionMs,
      Value<int> totalDurationMs,
      Value<int> listenedDurationMs,
      Value<double> percent,
      Value<bool> isFinished,
      required DateTime lastPlayedAt,
      Value<int> rowid,
    });
typedef $$PlaybackProgressEntriesTableUpdateCompanionBuilder =
    PlaybackProgressEntriesCompanion Function({
      Value<String> bookId,
      Value<String> bookVersionId,
      Value<String?> currentChapterId,
      Value<int> currentPositionMs,
      Value<int> maxReachedGlobalPositionMs,
      Value<int> totalDurationMs,
      Value<int> listenedDurationMs,
      Value<double> percent,
      Value<bool> isFinished,
      Value<DateTime> lastPlayedAt,
      Value<int> rowid,
    });

class $$PlaybackProgressEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackProgressEntriesTable> {
  $$PlaybackProgressEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPositionMs => $composableBuilder(
    column: $table.currentPositionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxReachedGlobalPositionMs => $composableBuilder(
    column: $table.maxReachedGlobalPositionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenedDurationMs => $composableBuilder(
    column: $table.listenedDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackProgressEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackProgressEntriesTable> {
  $$PlaybackProgressEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPositionMs => $composableBuilder(
    column: $table.currentPositionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxReachedGlobalPositionMs => $composableBuilder(
    column: $table.maxReachedGlobalPositionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenedDurationMs => $composableBuilder(
    column: $table.listenedDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackProgressEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackProgressEntriesTable> {
  $$PlaybackProgressEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentPositionMs => $composableBuilder(
    column: $table.currentPositionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxReachedGlobalPositionMs => $composableBuilder(
    column: $table.maxReachedGlobalPositionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get listenedDurationMs => $composableBuilder(
    column: $table.listenedDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$PlaybackProgressEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackProgressEntriesTable,
          PlaybackProgressRow,
          $$PlaybackProgressEntriesTableFilterComposer,
          $$PlaybackProgressEntriesTableOrderingComposer,
          $$PlaybackProgressEntriesTableAnnotationComposer,
          $$PlaybackProgressEntriesTableCreateCompanionBuilder,
          $$PlaybackProgressEntriesTableUpdateCompanionBuilder,
          (
            PlaybackProgressRow,
            BaseReferences<
              _$AppDatabase,
              $PlaybackProgressEntriesTable,
              PlaybackProgressRow
            >,
          ),
          PlaybackProgressRow,
          PrefetchHooks Function()
        > {
  $$PlaybackProgressEntriesTableTableManager(
    _$AppDatabase db,
    $PlaybackProgressEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackProgressEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PlaybackProgressEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaybackProgressEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> bookVersionId = const Value.absent(),
                Value<String?> currentChapterId = const Value.absent(),
                Value<int> currentPositionMs = const Value.absent(),
                Value<int> maxReachedGlobalPositionMs = const Value.absent(),
                Value<int> totalDurationMs = const Value.absent(),
                Value<int> listenedDurationMs = const Value.absent(),
                Value<double> percent = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<DateTime> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressEntriesCompanion(
                bookId: bookId,
                bookVersionId: bookVersionId,
                currentChapterId: currentChapterId,
                currentPositionMs: currentPositionMs,
                maxReachedGlobalPositionMs: maxReachedGlobalPositionMs,
                totalDurationMs: totalDurationMs,
                listenedDurationMs: listenedDurationMs,
                percent: percent,
                isFinished: isFinished,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String bookVersionId,
                Value<String?> currentChapterId = const Value.absent(),
                Value<int> currentPositionMs = const Value.absent(),
                Value<int> maxReachedGlobalPositionMs = const Value.absent(),
                Value<int> totalDurationMs = const Value.absent(),
                Value<int> listenedDurationMs = const Value.absent(),
                Value<double> percent = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                required DateTime lastPlayedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressEntriesCompanion.insert(
                bookId: bookId,
                bookVersionId: bookVersionId,
                currentChapterId: currentChapterId,
                currentPositionMs: currentPositionMs,
                maxReachedGlobalPositionMs: maxReachedGlobalPositionMs,
                totalDurationMs: totalDurationMs,
                listenedDurationMs: listenedDurationMs,
                percent: percent,
                isFinished: isFinished,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackProgressEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackProgressEntriesTable,
      PlaybackProgressRow,
      $$PlaybackProgressEntriesTableFilterComposer,
      $$PlaybackProgressEntriesTableOrderingComposer,
      $$PlaybackProgressEntriesTableAnnotationComposer,
      $$PlaybackProgressEntriesTableCreateCompanionBuilder,
      $$PlaybackProgressEntriesTableUpdateCompanionBuilder,
      (
        PlaybackProgressRow,
        BaseReferences<
          _$AppDatabase,
          $PlaybackProgressEntriesTable,
          PlaybackProgressRow
        >,
      ),
      PlaybackProgressRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadTasksTableCreateCompanionBuilder =
    DownloadTasksCompanion Function({
      required String id,
      required String bookId,
      required String bookVersionId,
      Value<String?> chapterId,
      required String sourceId,
      required String type,
      required String status,
      Value<int> priority,
      Value<double> progress,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<int> speedBytesPerSecond,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<int> retryCount,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DownloadTasksTableUpdateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> bookVersionId,
      Value<String?> chapterId,
      Value<String> sourceId,
      Value<String> type,
      Value<String> status,
      Value<int> priority,
      Value<double> progress,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<int> speedBytesPerSecond,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<int> retryCount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DownloadTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get speedBytesPerSecond => $composableBuilder(
    column: $table.speedBytesPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
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
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get speedBytesPerSecond => $composableBuilder(
    column: $table.speedBytesPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
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
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get speedBytesPerSecond => $composableBuilder(
    column: $table.speedBytesPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTasksTable,
          DownloadTaskRow,
          $$DownloadTasksTableFilterComposer,
          $$DownloadTasksTableOrderingComposer,
          $$DownloadTasksTableAnnotationComposer,
          $$DownloadTasksTableCreateCompanionBuilder,
          $$DownloadTasksTableUpdateCompanionBuilder,
          (
            DownloadTaskRow,
            BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTaskRow>,
          ),
          DownloadTaskRow,
          PrefetchHooks Function()
        > {
  $$DownloadTasksTableTableManager(_$AppDatabase db, $DownloadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> bookVersionId = const Value.absent(),
                Value<String?> chapterId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int> speedBytesPerSecond = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion(
                id: id,
                bookId: bookId,
                bookVersionId: bookVersionId,
                chapterId: chapterId,
                sourceId: sourceId,
                type: type,
                status: status,
                priority: priority,
                progress: progress,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                speedBytesPerSecond: speedBytesPerSecond,
                errorCode: errorCode,
                errorMessage: errorMessage,
                retryCount: retryCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String bookVersionId,
                Value<String?> chapterId = const Value.absent(),
                required String sourceId,
                required String type,
                required String status,
                Value<int> priority = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int> speedBytesPerSecond = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion.insert(
                id: id,
                bookId: bookId,
                bookVersionId: bookVersionId,
                chapterId: chapterId,
                sourceId: sourceId,
                type: type,
                status: status,
                priority: priority,
                progress: progress,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                speedBytesPerSecond: speedBytesPerSecond,
                errorCode: errorCode,
                errorMessage: errorMessage,
                retryCount: retryCount,
                createdAt: createdAt,
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

typedef $$DownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTasksTable,
      DownloadTaskRow,
      $$DownloadTasksTableFilterComposer,
      $$DownloadTasksTableOrderingComposer,
      $$DownloadTasksTableAnnotationComposer,
      $$DownloadTasksTableCreateCompanionBuilder,
      $$DownloadTasksTableUpdateCompanionBuilder,
      (
        DownloadTaskRow,
        BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTaskRow>,
      ),
      DownloadTaskRow,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      required String bookId,
      Value<String?> bookVersionId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<String> bookId,
      Value<String?> bookVersionId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          FavoriteRow,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (
            FavoriteRow,
            BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
          ),
          FavoriteRow,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String?> bookVersionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                bookId: bookId,
                bookVersionId: bookVersionId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                Value<String?> bookVersionId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                bookId: bookId,
                bookVersionId: bookVersionId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      FavoriteRow,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (
        FavoriteRow,
        BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
      ),
      FavoriteRow,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String bookId,
      required String bookVersionId,
      required String chapterId,
      required int positionMs,
      required String title,
      Value<String?> note,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> bookVersionId,
      Value<String> chapterId,
      Value<int> positionMs,
      Value<String> title,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get bookVersionId => $composableBuilder(
    column: $table.bookVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          BookmarkRow,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (
            BookmarkRow,
            BaseReferences<_$AppDatabase, $BookmarksTable, BookmarkRow>,
          ),
          BookmarkRow,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> bookVersionId = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                bookVersionId: bookVersionId,
                chapterId: chapterId,
                positionMs: positionMs,
                title: title,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String bookVersionId,
                required String chapterId,
                required int positionMs,
                required String title,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                bookVersionId: bookVersionId,
                chapterId: chapterId,
                positionMs: positionMs,
                title: title,
                note: note,
                createdAt: createdAt,
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

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      BookmarkRow,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (
        BookmarkRow,
        BaseReferences<_$AppDatabase, $BookmarksTable, BookmarkRow>,
      ),
      BookmarkRow,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryRowsTableCreateCompanionBuilder =
    SearchHistoryRowsCompanion Function({
      required String id,
      required String query,
      required String searchKind,
      Value<String> filtersJson,
      required DateTime createdAt,
      required DateTime lastUsedAt,
      Value<int> usageCount,
      Value<int> rowid,
    });
typedef $$SearchHistoryRowsTableUpdateCompanionBuilder =
    SearchHistoryRowsCompanion Function({
      Value<String> id,
      Value<String> query,
      Value<String> searchKind,
      Value<String> filtersJson,
      Value<DateTime> createdAt,
      Value<DateTime> lastUsedAt,
      Value<int> usageCount,
      Value<int> rowid,
    });

class $$SearchHistoryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryRowsTable> {
  $$SearchHistoryRowsTableFilterComposer({
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

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchKind => $composableBuilder(
    column: $table.searchKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryRowsTable> {
  $$SearchHistoryRowsTableOrderingComposer({
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

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchKind => $composableBuilder(
    column: $table.searchKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryRowsTable> {
  $$SearchHistoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get searchKind => $composableBuilder(
    column: $table.searchKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usageCount => $composableBuilder(
    column: $table.usageCount,
    builder: (column) => column,
  );
}

class $$SearchHistoryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryRowsTable,
          SearchHistoryRow,
          $$SearchHistoryRowsTableFilterComposer,
          $$SearchHistoryRowsTableOrderingComposer,
          $$SearchHistoryRowsTableAnnotationComposer,
          $$SearchHistoryRowsTableCreateCompanionBuilder,
          $$SearchHistoryRowsTableUpdateCompanionBuilder,
          (
            SearchHistoryRow,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryRowsTable,
              SearchHistoryRow
            >,
          ),
          SearchHistoryRow,
          PrefetchHooks Function()
        > {
  $$SearchHistoryRowsTableTableManager(
    _$AppDatabase db,
    $SearchHistoryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String> searchKind = const Value.absent(),
                Value<String> filtersJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
                Value<int> usageCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryRowsCompanion(
                id: id,
                query: query,
                searchKind: searchKind,
                filtersJson: filtersJson,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                usageCount: usageCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String query,
                required String searchKind,
                Value<String> filtersJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastUsedAt,
                Value<int> usageCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryRowsCompanion.insert(
                id: id,
                query: query,
                searchKind: searchKind,
                filtersJson: filtersJson,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                usageCount: usageCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryRowsTable,
      SearchHistoryRow,
      $$SearchHistoryRowsTableFilterComposer,
      $$SearchHistoryRowsTableOrderingComposer,
      $$SearchHistoryRowsTableAnnotationComposer,
      $$SearchHistoryRowsTableCreateCompanionBuilder,
      $$SearchHistoryRowsTableUpdateCompanionBuilder,
      (
        SearchHistoryRow,
        BaseReferences<
          _$AppDatabase,
          $SearchHistoryRowsTable,
          SearchHistoryRow
        >,
      ),
      SearchHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsRowsTableCreateCompanionBuilder =
    AppSettingsRowsCompanion Function({
      required String id,
      Value<String> themeMode,
      Value<String> languageCode,
      Value<String> accentColor,
      Value<double> textScale,
      Value<bool> compactCards,
      Value<bool> showSourceOnCards,
      Value<bool> showPercentOnCovers,
      Value<String> animationsMode,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsRowsTableUpdateCompanionBuilder =
    AppSettingsRowsCompanion Function({
      Value<String> id,
      Value<String> themeMode,
      Value<String> languageCode,
      Value<String> accentColor,
      Value<double> textScale,
      Value<bool> compactCards,
      Value<bool> showSourceOnCards,
      Value<bool> showPercentOnCovers,
      Value<String> animationsMode,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsRowsTable> {
  $$AppSettingsRowsTableFilterComposer({
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

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get compactCards => $composableBuilder(
    column: $table.compactCards,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showSourceOnCards => $composableBuilder(
    column: $table.showSourceOnCards,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showPercentOnCovers => $composableBuilder(
    column: $table.showPercentOnCovers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animationsMode => $composableBuilder(
    column: $table.animationsMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsRowsTable> {
  $$AppSettingsRowsTableOrderingComposer({
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

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get compactCards => $composableBuilder(
    column: $table.compactCards,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showSourceOnCards => $composableBuilder(
    column: $table.showSourceOnCards,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showPercentOnCovers => $composableBuilder(
    column: $table.showPercentOnCovers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animationsMode => $composableBuilder(
    column: $table.animationsMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsRowsTable> {
  $$AppSettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => column,
  );

  GeneratedColumn<double> get textScale =>
      $composableBuilder(column: $table.textScale, builder: (column) => column);

  GeneratedColumn<bool> get compactCards => $composableBuilder(
    column: $table.compactCards,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showSourceOnCards => $composableBuilder(
    column: $table.showSourceOnCards,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showPercentOnCovers => $composableBuilder(
    column: $table.showPercentOnCovers,
    builder: (column) => column,
  );

  GeneratedColumn<String> get animationsMode => $composableBuilder(
    column: $table.animationsMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsRowsTable,
          AppSettingsRow,
          $$AppSettingsRowsTableFilterComposer,
          $$AppSettingsRowsTableOrderingComposer,
          $$AppSettingsRowsTableAnnotationComposer,
          $$AppSettingsRowsTableCreateCompanionBuilder,
          $$AppSettingsRowsTableUpdateCompanionBuilder,
          (
            AppSettingsRow,
            BaseReferences<
              _$AppDatabase,
              $AppSettingsRowsTable,
              AppSettingsRow
            >,
          ),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsRowsTableTableManager(
    _$AppDatabase db,
    $AppSettingsRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<String> accentColor = const Value.absent(),
                Value<double> textScale = const Value.absent(),
                Value<bool> compactCards = const Value.absent(),
                Value<bool> showSourceOnCards = const Value.absent(),
                Value<bool> showPercentOnCovers = const Value.absent(),
                Value<String> animationsMode = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsRowsCompanion(
                id: id,
                themeMode: themeMode,
                languageCode: languageCode,
                accentColor: accentColor,
                textScale: textScale,
                compactCards: compactCards,
                showSourceOnCards: showSourceOnCards,
                showPercentOnCovers: showPercentOnCovers,
                animationsMode: animationsMode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> themeMode = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<String> accentColor = const Value.absent(),
                Value<double> textScale = const Value.absent(),
                Value<bool> compactCards = const Value.absent(),
                Value<bool> showSourceOnCards = const Value.absent(),
                Value<bool> showPercentOnCovers = const Value.absent(),
                Value<String> animationsMode = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsRowsCompanion.insert(
                id: id,
                themeMode: themeMode,
                languageCode: languageCode,
                accentColor: accentColor,
                textScale: textScale,
                compactCards: compactCards,
                showSourceOnCards: showSourceOnCards,
                showPercentOnCovers: showPercentOnCovers,
                animationsMode: animationsMode,
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

typedef $$AppSettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsRowsTable,
      AppSettingsRow,
      $$AppSettingsRowsTableFilterComposer,
      $$AppSettingsRowsTableOrderingComposer,
      $$AppSettingsRowsTableAnnotationComposer,
      $$AppSettingsRowsTableCreateCompanionBuilder,
      $$AppSettingsRowsTableUpdateCompanionBuilder,
      (
        AppSettingsRow,
        BaseReferences<_$AppDatabase, $AppSettingsRowsTable, AppSettingsRow>,
      ),
      AppSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$ProxyProfilesTableCreateCompanionBuilder =
    ProxyProfilesCompanion Function({
      required String id,
      required String name,
      required String type,
      Value<String?> host,
      Value<int?> port,
      Value<String?> username,
      Value<bool> isEnabled,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProxyProfilesTableUpdateCompanionBuilder =
    ProxyProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> host,
      Value<int?> port,
      Value<String?> username,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProxyProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProxyProfilesTable> {
  $$ProxyProfilesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
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
}

class $$ProxyProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProxyProfilesTable> {
  $$ProxyProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
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
}

class $$ProxyProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProxyProfilesTable> {
  $$ProxyProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProxyProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProxyProfilesTable,
          ProxyProfileRow,
          $$ProxyProfilesTableFilterComposer,
          $$ProxyProfilesTableOrderingComposer,
          $$ProxyProfilesTableAnnotationComposer,
          $$ProxyProfilesTableCreateCompanionBuilder,
          $$ProxyProfilesTableUpdateCompanionBuilder,
          (
            ProxyProfileRow,
            BaseReferences<_$AppDatabase, $ProxyProfilesTable, ProxyProfileRow>,
          ),
          ProxyProfileRow,
          PrefetchHooks Function()
        > {
  $$ProxyProfilesTableTableManager(_$AppDatabase db, $ProxyProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProxyProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProxyProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProxyProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> host = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProxyProfilesCompanion(
                id: id,
                name: name,
                type: type,
                host: host,
                port: port,
                username: username,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                Value<String?> host = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProxyProfilesCompanion.insert(
                id: id,
                name: name,
                type: type,
                host: host,
                port: port,
                username: username,
                isEnabled: isEnabled,
                createdAt: createdAt,
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

typedef $$ProxyProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProxyProfilesTable,
      ProxyProfileRow,
      $$ProxyProfilesTableFilterComposer,
      $$ProxyProfilesTableOrderingComposer,
      $$ProxyProfilesTableAnnotationComposer,
      $$ProxyProfilesTableCreateCompanionBuilder,
      $$ProxyProfilesTableUpdateCompanionBuilder,
      (
        ProxyProfileRow,
        BaseReferences<_$AppDatabase, $ProxyProfilesTable, ProxyProfileRow>,
      ),
      ProxyProfileRow,
      PrefetchHooks Function()
    >;
typedef $$SourceSettingsRowsTableCreateCompanionBuilder =
    SourceSettingsRowsCompanion Function({
      required String sourceId,
      Value<bool> isEnabled,
      Value<int> priority,
      Value<bool> useInGlobalSearch,
      Value<bool> allowStreaming,
      Value<bool> allowDownload,
      Value<String> proxyMode,
      Value<int?> timeoutMs,
      Value<int?> resultLimit,
      Value<String> extraJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SourceSettingsRowsTableUpdateCompanionBuilder =
    SourceSettingsRowsCompanion Function({
      Value<String> sourceId,
      Value<bool> isEnabled,
      Value<int> priority,
      Value<bool> useInGlobalSearch,
      Value<bool> allowStreaming,
      Value<bool> allowDownload,
      Value<String> proxyMode,
      Value<int?> timeoutMs,
      Value<int?> resultLimit,
      Value<String> extraJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SourceSettingsRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SourceSettingsRowsTable> {
  $$SourceSettingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useInGlobalSearch => $composableBuilder(
    column: $table.useInGlobalSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowStreaming => $composableBuilder(
    column: $table.allowStreaming,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowDownload => $composableBuilder(
    column: $table.allowDownload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxyMode => $composableBuilder(
    column: $table.proxyMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeoutMs => $composableBuilder(
    column: $table.timeoutMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resultLimit => $composableBuilder(
    column: $table.resultLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceSettingsRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceSettingsRowsTable> {
  $$SourceSettingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useInGlobalSearch => $composableBuilder(
    column: $table.useInGlobalSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowStreaming => $composableBuilder(
    column: $table.allowStreaming,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowDownload => $composableBuilder(
    column: $table.allowDownload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxyMode => $composableBuilder(
    column: $table.proxyMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeoutMs => $composableBuilder(
    column: $table.timeoutMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resultLimit => $composableBuilder(
    column: $table.resultLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceSettingsRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceSettingsRowsTable> {
  $$SourceSettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get useInGlobalSearch => $composableBuilder(
    column: $table.useInGlobalSearch,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowStreaming => $composableBuilder(
    column: $table.allowStreaming,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowDownload => $composableBuilder(
    column: $table.allowDownload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proxyMode =>
      $composableBuilder(column: $table.proxyMode, builder: (column) => column);

  GeneratedColumn<int> get timeoutMs =>
      $composableBuilder(column: $table.timeoutMs, builder: (column) => column);

  GeneratedColumn<int> get resultLimit => $composableBuilder(
    column: $table.resultLimit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SourceSettingsRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceSettingsRowsTable,
          SourceSettingsRow,
          $$SourceSettingsRowsTableFilterComposer,
          $$SourceSettingsRowsTableOrderingComposer,
          $$SourceSettingsRowsTableAnnotationComposer,
          $$SourceSettingsRowsTableCreateCompanionBuilder,
          $$SourceSettingsRowsTableUpdateCompanionBuilder,
          (
            SourceSettingsRow,
            BaseReferences<
              _$AppDatabase,
              $SourceSettingsRowsTable,
              SourceSettingsRow
            >,
          ),
          SourceSettingsRow,
          PrefetchHooks Function()
        > {
  $$SourceSettingsRowsTableTableManager(
    _$AppDatabase db,
    $SourceSettingsRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceSettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceSettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceSettingsRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> useInGlobalSearch = const Value.absent(),
                Value<bool> allowStreaming = const Value.absent(),
                Value<bool> allowDownload = const Value.absent(),
                Value<String> proxyMode = const Value.absent(),
                Value<int?> timeoutMs = const Value.absent(),
                Value<int?> resultLimit = const Value.absent(),
                Value<String> extraJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceSettingsRowsCompanion(
                sourceId: sourceId,
                isEnabled: isEnabled,
                priority: priority,
                useInGlobalSearch: useInGlobalSearch,
                allowStreaming: allowStreaming,
                allowDownload: allowDownload,
                proxyMode: proxyMode,
                timeoutMs: timeoutMs,
                resultLimit: resultLimit,
                extraJson: extraJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                Value<bool> isEnabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> useInGlobalSearch = const Value.absent(),
                Value<bool> allowStreaming = const Value.absent(),
                Value<bool> allowDownload = const Value.absent(),
                Value<String> proxyMode = const Value.absent(),
                Value<int?> timeoutMs = const Value.absent(),
                Value<int?> resultLimit = const Value.absent(),
                Value<String> extraJson = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourceSettingsRowsCompanion.insert(
                sourceId: sourceId,
                isEnabled: isEnabled,
                priority: priority,
                useInGlobalSearch: useInGlobalSearch,
                allowStreaming: allowStreaming,
                allowDownload: allowDownload,
                proxyMode: proxyMode,
                timeoutMs: timeoutMs,
                resultLimit: resultLimit,
                extraJson: extraJson,
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

typedef $$SourceSettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceSettingsRowsTable,
      SourceSettingsRow,
      $$SourceSettingsRowsTableFilterComposer,
      $$SourceSettingsRowsTableOrderingComposer,
      $$SourceSettingsRowsTableAnnotationComposer,
      $$SourceSettingsRowsTableCreateCompanionBuilder,
      $$SourceSettingsRowsTableUpdateCompanionBuilder,
      (
        SourceSettingsRow,
        BaseReferences<
          _$AppDatabase,
          $SourceSettingsRowsTable,
          SourceSettingsRow
        >,
      ),
      SourceSettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$BookVersionsTableTableManager get bookVersions =>
      $$BookVersionsTableTableManager(_db, _db.bookVersions);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$AudioTracksTableTableManager get audioTracks =>
      $$AudioTracksTableTableManager(_db, _db.audioTracks);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$SourceHealthRowsTableTableManager get sourceHealthRows =>
      $$SourceHealthRowsTableTableManager(_db, _db.sourceHealthRows);
  $$PlaybackSessionsTableTableManager get playbackSessions =>
      $$PlaybackSessionsTableTableManager(_db, _db.playbackSessions);
  $$PlaybackProgressEntriesTableTableManager get playbackProgressEntries =>
      $$PlaybackProgressEntriesTableTableManager(
        _db,
        _db.playbackProgressEntries,
      );
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$SearchHistoryRowsTableTableManager get searchHistoryRows =>
      $$SearchHistoryRowsTableTableManager(_db, _db.searchHistoryRows);
  $$AppSettingsRowsTableTableManager get appSettingsRows =>
      $$AppSettingsRowsTableTableManager(_db, _db.appSettingsRows);
  $$ProxyProfilesTableTableManager get proxyProfiles =>
      $$ProxyProfilesTableTableManager(_db, _db.proxyProfiles);
  $$SourceSettingsRowsTableTableManager get sourceSettingsRows =>
      $$SourceSettingsRowsTableTableManager(_db, _db.sourceSettingsRows);
}
