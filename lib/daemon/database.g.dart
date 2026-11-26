// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$NodesDaoMixin on DatabaseAccessor<BridgeDatabase> {
  $NodesTable get nodes => attachedDatabase.nodes;
  NodesDaoManager get managers => NodesDaoManager(this);
}

class NodesDaoManager {
  final _$NodesDaoMixin _db;
  NodesDaoManager(this._db);
  $$NodesTableTableManager get nodes =>
      $$NodesTableTableManager(_db.attachedDatabase, _db.nodes);
}

mixin _$WorkflowsDaoMixin on DatabaseAccessor<BridgeDatabase> {
  $WorkflowsTable get workflows => attachedDatabase.workflows;
  WorkflowsDaoManager get managers => WorkflowsDaoManager(this);
}

class WorkflowsDaoManager {
  final _$WorkflowsDaoMixin _db;
  WorkflowsDaoManager(this._db);
  $$WorkflowsTableTableManager get workflows =>
      $$WorkflowsTableTableManager(_db.attachedDatabase, _db.workflows);
}

mixin _$TasksDaoMixin on DatabaseAccessor<BridgeDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  TasksDaoManager get managers => TasksDaoManager(this);
}

class TasksDaoManager {
  final _$TasksDaoMixin _db;
  TasksDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
}

mixin _$AuditDaoMixin on DatabaseAccessor<BridgeDatabase> {
  $AuditLogTable get auditLog => attachedDatabase.auditLog;
  AuditDaoManager get managers => AuditDaoManager(this);
}

class AuditDaoManager {
  final _$AuditDaoMixin _db;
  AuditDaoManager(this._db);
  $$AuditLogTableTableManager get auditLog =>
      $$AuditLogTableTableManager(_db.attachedDatabase, _db.auditLog);
}

mixin _$SettingsDaoMixin on DatabaseAccessor<BridgeDatabase> {
  $SettingsTable get settings => attachedDatabase.settings;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
}

class $NodesTable extends Nodes with TableInfo<$NodesTable, Node> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tabIdMeta = const VerificationMeta('tabId');
  @override
  late final GeneratedColumn<int> tabId = GeneratedColumn<int>(
      'tab_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _permissionTierMeta =
      const VerificationMeta('permissionTier');
  @override
  late final GeneratedColumn<String> permissionTier = GeneratedColumn<String>(
      'permission_tier', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('read_only'));
  static const VerificationMeta _healthMeta = const VerificationMeta('health');
  @override
  late final GeneratedColumn<String> health = GeneratedColumn<String>(
      'health', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('healthy'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, kind, url, tabId, permissionTier, health, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nodes';
  @override
  VerificationContext validateIntegrity(Insertable<Node> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('tab_id')) {
      context.handle(
          _tabIdMeta, tabId.isAcceptableOrUnknown(data['tab_id']!, _tabIdMeta));
    }
    if (data.containsKey('permission_tier')) {
      context.handle(
          _permissionTierMeta,
          permissionTier.isAcceptableOrUnknown(
              data['permission_tier']!, _permissionTierMeta));
    }
    if (data.containsKey('health')) {
      context.handle(_healthMeta,
          health.isAcceptableOrUnknown(data['health']!, _healthMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Node map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Node(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url']),
      tabId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tab_id']),
      permissionTier: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}permission_tier'])!,
      health: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}health'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $NodesTable createAlias(String alias) {
    return $NodesTable(attachedDatabase, alias);
  }
}

class Node extends DataClass implements Insertable<Node> {
  final String id;
  final String name;
  final String kind;
  final String? url;
  final int? tabId;
  final String permissionTier;
  final String health;
  final int createdAt;
  const Node(
      {required this.id,
      required this.name,
      required this.kind,
      this.url,
      this.tabId,
      required this.permissionTier,
      required this.health,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || tabId != null) {
      map['tab_id'] = Variable<int>(tabId);
    }
    map['permission_tier'] = Variable<String>(permissionTier);
    map['health'] = Variable<String>(health);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  NodesCompanion toCompanion(bool nullToAbsent) {
    return NodesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      tabId:
          tabId == null && nullToAbsent ? const Value.absent() : Value(tabId),
      permissionTier: Value(permissionTier),
      health: Value(health),
      createdAt: Value(createdAt),
    );
  }

  factory Node.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Node(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      url: serializer.fromJson<String?>(json['url']),
      tabId: serializer.fromJson<int?>(json['tabId']),
      permissionTier: serializer.fromJson<String>(json['permissionTier']),
      health: serializer.fromJson<String>(json['health']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'url': serializer.toJson<String?>(url),
      'tabId': serializer.toJson<int?>(tabId),
      'permissionTier': serializer.toJson<String>(permissionTier),
      'health': serializer.toJson<String>(health),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Node copyWith(
          {String? id,
          String? name,
          String? kind,
          Value<String?> url = const Value.absent(),
          Value<int?> tabId = const Value.absent(),
          String? permissionTier,
          String? health,
          int? createdAt}) =>
      Node(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        url: url.present ? url.value : this.url,
        tabId: tabId.present ? tabId.value : this.tabId,
        permissionTier: permissionTier ?? this.permissionTier,
        health: health ?? this.health,
        createdAt: createdAt ?? this.createdAt,
      );
  Node copyWithCompanion(NodesCompanion data) {
    return Node(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      url: data.url.present ? data.url.value : this.url,
      tabId: data.tabId.present ? data.tabId.value : this.tabId,
      permissionTier: data.permissionTier.present
          ? data.permissionTier.value
          : this.permissionTier,
      health: data.health.present ? data.health.value : this.health,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Node(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('url: $url, ')
          ..write('tabId: $tabId, ')
          ..write('permissionTier: $permissionTier, ')
          ..write('health: $health, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, kind, url, tabId, permissionTier, health, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Node &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.url == this.url &&
          other.tabId == this.tabId &&
          other.permissionTier == this.permissionTier &&
          other.health == this.health &&
          other.createdAt == this.createdAt);
}

class NodesCompanion extends UpdateCompanion<Node> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> url;
  final Value<int?> tabId;
  final Value<String> permissionTier;
  final Value<String> health;
  final Value<int> createdAt;
  final Value<int> rowid;
  const NodesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.url = const Value.absent(),
    this.tabId = const Value.absent(),
    this.permissionTier = const Value.absent(),
    this.health = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NodesCompanion.insert({
    required String id,
    required String name,
    required String kind,
    this.url = const Value.absent(),
    this.tabId = const Value.absent(),
    this.permissionTier = const Value.absent(),
    this.health = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        kind = Value(kind),
        createdAt = Value(createdAt);
  static Insertable<Node> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? url,
    Expression<int>? tabId,
    Expression<String>? permissionTier,
    Expression<String>? health,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (url != null) 'url': url,
      if (tabId != null) 'tab_id': tabId,
      if (permissionTier != null) 'permission_tier': permissionTier,
      if (health != null) 'health': health,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NodesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? kind,
      Value<String?>? url,
      Value<int?>? tabId,
      Value<String>? permissionTier,
      Value<String>? health,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return NodesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      url: url ?? this.url,
      tabId: tabId ?? this.tabId,
      permissionTier: permissionTier ?? this.permissionTier,
      health: health ?? this.health,
      createdAt: createdAt ?? this.createdAt,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (tabId.present) {
      map['tab_id'] = Variable<int>(tabId.value);
    }
    if (permissionTier.present) {
      map['permission_tier'] = Variable<String>(permissionTier.value);
    }
    if (health.present) {
      map['health'] = Variable<String>(health.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NodesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('url: $url, ')
          ..write('tabId: $tabId, ')
          ..write('permissionTier: $permissionTier, ')
          ..write('health: $health, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkflowsTable extends Workflows
    with TableInfo<$WorkflowsTable, Workflow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkflowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _graphJsonMeta =
      const VerificationMeta('graphJson');
  @override
  late final GeneratedColumn<String> graphJson = GeneratedColumn<String>(
      'graph_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, graphJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workflows';
  @override
  VerificationContext validateIntegrity(Insertable<Workflow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('graph_json')) {
      context.handle(_graphJsonMeta,
          graphJson.isAcceptableOrUnknown(data['graph_json']!, _graphJsonMeta));
    } else if (isInserting) {
      context.missing(_graphJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workflow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workflow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      graphJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}graph_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $WorkflowsTable createAlias(String alias) {
    return $WorkflowsTable(attachedDatabase, alias);
  }
}

class Workflow extends DataClass implements Insertable<Workflow> {
  final String id;
  final String name;
  final String graphJson;
  final int createdAt;
  const Workflow(
      {required this.id,
      required this.name,
      required this.graphJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['graph_json'] = Variable<String>(graphJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  WorkflowsCompanion toCompanion(bool nullToAbsent) {
    return WorkflowsCompanion(
      id: Value(id),
      name: Value(name),
      graphJson: Value(graphJson),
      createdAt: Value(createdAt),
    );
  }

  factory Workflow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workflow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      graphJson: serializer.fromJson<String>(json['graphJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'graphJson': serializer.toJson<String>(graphJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Workflow copyWith(
          {String? id, String? name, String? graphJson, int? createdAt}) =>
      Workflow(
        id: id ?? this.id,
        name: name ?? this.name,
        graphJson: graphJson ?? this.graphJson,
        createdAt: createdAt ?? this.createdAt,
      );
  Workflow copyWithCompanion(WorkflowsCompanion data) {
    return Workflow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      graphJson: data.graphJson.present ? data.graphJson.value : this.graphJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workflow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('graphJson: $graphJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, graphJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workflow &&
          other.id == this.id &&
          other.name == this.name &&
          other.graphJson == this.graphJson &&
          other.createdAt == this.createdAt);
}

class WorkflowsCompanion extends UpdateCompanion<Workflow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> graphJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const WorkflowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.graphJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkflowsCompanion.insert({
    required String id,
    required String name,
    required String graphJson,
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        graphJson = Value(graphJson),
        createdAt = Value(createdAt);
  static Insertable<Workflow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? graphJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (graphJson != null) 'graph_json': graphJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkflowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? graphJson,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return WorkflowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      graphJson: graphJson ?? this.graphJson,
      createdAt: createdAt ?? this.createdAt,
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
    if (graphJson.present) {
      map['graph_json'] = Variable<String>(graphJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('graphJson: $graphJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workflowIdMeta =
      const VerificationMeta('workflowId');
  @override
  late final GeneratedColumn<String> workflowId = GeneratedColumn<String>(
      'workflow_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentTaskIdMeta =
      const VerificationMeta('parentTaskId');
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
      'parent_task_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _handoffDepthMeta =
      const VerificationMeta('handoffDepth');
  @override
  late final GeneratedColumn<int> handoffDepth = GeneratedColumn<int>(
      'handoff_depth', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sourceNodeMeta =
      const VerificationMeta('sourceNode');
  @override
  late final GeneratedColumn<String> sourceNode = GeneratedColumn<String>(
      'source_node', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetNodeMeta =
      const VerificationMeta('targetNode');
  @override
  late final GeneratedColumn<String> targetNode = GeneratedColumn<String>(
      'target_node', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _instructionMeta =
      const VerificationMeta('instruction');
  @override
  late final GeneratedColumn<String> instruction = GeneratedColumn<String>(
      'instruction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('created'));
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
      'result', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
      'error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workflowId,
        projectId,
        parentTaskId,
        handoffDepth,
        sourceNode,
        targetNode,
        instruction,
        status,
        result,
        error,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(Insertable<Task> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workflow_id')) {
      context.handle(
          _workflowIdMeta,
          workflowId.isAcceptableOrUnknown(
              data['workflow_id']!, _workflowIdMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
          _parentTaskIdMeta,
          parentTaskId.isAcceptableOrUnknown(
              data['parent_task_id']!, _parentTaskIdMeta));
    }
    if (data.containsKey('handoff_depth')) {
      context.handle(
          _handoffDepthMeta,
          handoffDepth.isAcceptableOrUnknown(
              data['handoff_depth']!, _handoffDepthMeta));
    }
    if (data.containsKey('source_node')) {
      context.handle(
          _sourceNodeMeta,
          sourceNode.isAcceptableOrUnknown(
              data['source_node']!, _sourceNodeMeta));
    } else if (isInserting) {
      context.missing(_sourceNodeMeta);
    }
    if (data.containsKey('target_node')) {
      context.handle(
          _targetNodeMeta,
          targetNode.isAcceptableOrUnknown(
              data['target_node']!, _targetNodeMeta));
    } else if (isInserting) {
      context.missing(_targetNodeMeta);
    }
    if (data.containsKey('instruction')) {
      context.handle(
          _instructionMeta,
          instruction.isAcceptableOrUnknown(
              data['instruction']!, _instructionMeta));
    } else if (isInserting) {
      context.missing(_instructionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta,
          result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    }
    if (data.containsKey('error')) {
      context.handle(
          _errorMeta, error.isAcceptableOrUnknown(data['error']!, _errorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workflowId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workflow_id']),
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      parentTaskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_task_id']),
      handoffDepth: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}handoff_depth'])!,
      sourceNode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_node'])!,
      targetNode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_node'])!,
      instruction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}instruction'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      result: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result']),
      error: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String? workflowId;
  final String? projectId;
  final String? parentTaskId;
  final int handoffDepth;
  final String sourceNode;
  final String targetNode;
  final String instruction;
  final String status;
  final String? result;
  final String? error;
  final int createdAt;
  final int updatedAt;
  const Task(
      {required this.id,
      this.workflowId,
      this.projectId,
      this.parentTaskId,
      required this.handoffDepth,
      required this.sourceNode,
      required this.targetNode,
      required this.instruction,
      required this.status,
      this.result,
      this.error,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || workflowId != null) {
      map['workflow_id'] = Variable<String>(workflowId);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    map['handoff_depth'] = Variable<int>(handoffDepth);
    map['source_node'] = Variable<String>(sourceNode);
    map['target_node'] = Variable<String>(targetNode);
    map['instruction'] = Variable<String>(instruction);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      workflowId: workflowId == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
      handoffDepth: Value(handoffDepth),
      sourceNode: Value(sourceNode),
      targetNode: Value(targetNode),
      instruction: Value(instruction),
      status: Value(status),
      result:
          result == null && nullToAbsent ? const Value.absent() : Value(result),
      error:
          error == null && nullToAbsent ? const Value.absent() : Value(error),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Task.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      workflowId: serializer.fromJson<String?>(json['workflowId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
      handoffDepth: serializer.fromJson<int>(json['handoffDepth']),
      sourceNode: serializer.fromJson<String>(json['sourceNode']),
      targetNode: serializer.fromJson<String>(json['targetNode']),
      instruction: serializer.fromJson<String>(json['instruction']),
      status: serializer.fromJson<String>(json['status']),
      result: serializer.fromJson<String?>(json['result']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workflowId': serializer.toJson<String?>(workflowId),
      'projectId': serializer.toJson<String?>(projectId),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
      'handoffDepth': serializer.toJson<int>(handoffDepth),
      'sourceNode': serializer.toJson<String>(sourceNode),
      'targetNode': serializer.toJson<String>(targetNode),
      'instruction': serializer.toJson<String>(instruction),
      'status': serializer.toJson<String>(status),
      'result': serializer.toJson<String?>(result),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Task copyWith(
          {String? id,
          Value<String?> workflowId = const Value.absent(),
          Value<String?> projectId = const Value.absent(),
          Value<String?> parentTaskId = const Value.absent(),
          int? handoffDepth,
          String? sourceNode,
          String? targetNode,
          String? instruction,
          String? status,
          Value<String?> result = const Value.absent(),
          Value<String?> error = const Value.absent(),
          int? createdAt,
          int? updatedAt}) =>
      Task(
        id: id ?? this.id,
        workflowId: workflowId.present ? workflowId.value : this.workflowId,
        projectId: projectId.present ? projectId.value : this.projectId,
        parentTaskId:
            parentTaskId.present ? parentTaskId.value : this.parentTaskId,
        handoffDepth: handoffDepth ?? this.handoffDepth,
        sourceNode: sourceNode ?? this.sourceNode,
        targetNode: targetNode ?? this.targetNode,
        instruction: instruction ?? this.instruction,
        status: status ?? this.status,
        result: result.present ? result.value : this.result,
        error: error.present ? error.value : this.error,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      workflowId:
          data.workflowId.present ? data.workflowId.value : this.workflowId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
      handoffDepth: data.handoffDepth.present
          ? data.handoffDepth.value
          : this.handoffDepth,
      sourceNode:
          data.sourceNode.present ? data.sourceNode.value : this.sourceNode,
      targetNode:
          data.targetNode.present ? data.targetNode.value : this.targetNode,
      instruction:
          data.instruction.present ? data.instruction.value : this.instruction,
      status: data.status.present ? data.status.value : this.status,
      result: data.result.present ? data.result.value : this.result,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('workflowId: $workflowId, ')
          ..write('projectId: $projectId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('handoffDepth: $handoffDepth, ')
          ..write('sourceNode: $sourceNode, ')
          ..write('targetNode: $targetNode, ')
          ..write('instruction: $instruction, ')
          ..write('status: $status, ')
          ..write('result: $result, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workflowId,
      projectId,
      parentTaskId,
      handoffDepth,
      sourceNode,
      targetNode,
      instruction,
      status,
      result,
      error,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.workflowId == this.workflowId &&
          other.projectId == this.projectId &&
          other.parentTaskId == this.parentTaskId &&
          other.handoffDepth == this.handoffDepth &&
          other.sourceNode == this.sourceNode &&
          other.targetNode == this.targetNode &&
          other.instruction == this.instruction &&
          other.status == this.status &&
          other.result == this.result &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String?> workflowId;
  final Value<String?> projectId;
  final Value<String?> parentTaskId;
  final Value<int> handoffDepth;
  final Value<String> sourceNode;
  final Value<String> targetNode;
  final Value<String> instruction;
  final Value<String> status;
  final Value<String?> result;
  final Value<String?> error;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.workflowId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.handoffDepth = const Value.absent(),
    this.sourceNode = const Value.absent(),
    this.targetNode = const Value.absent(),
    this.instruction = const Value.absent(),
    this.status = const Value.absent(),
    this.result = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    this.workflowId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.handoffDepth = const Value.absent(),
    required String sourceNode,
    required String targetNode,
    required String instruction,
    this.status = const Value.absent(),
    this.result = const Value.absent(),
    this.error = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sourceNode = Value(sourceNode),
        targetNode = Value(targetNode),
        instruction = Value(instruction),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? workflowId,
    Expression<String>? projectId,
    Expression<String>? parentTaskId,
    Expression<int>? handoffDepth,
    Expression<String>? sourceNode,
    Expression<String>? targetNode,
    Expression<String>? instruction,
    Expression<String>? status,
    Expression<String>? result,
    Expression<String>? error,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workflowId != null) 'workflow_id': workflowId,
      if (projectId != null) 'project_id': projectId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (handoffDepth != null) 'handoff_depth': handoffDepth,
      if (sourceNode != null) 'source_node': sourceNode,
      if (targetNode != null) 'target_node': targetNode,
      if (instruction != null) 'instruction': instruction,
      if (status != null) 'status': status,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith(
      {Value<String>? id,
      Value<String?>? workflowId,
      Value<String?>? projectId,
      Value<String?>? parentTaskId,
      Value<int>? handoffDepth,
      Value<String>? sourceNode,
      Value<String>? targetNode,
      Value<String>? instruction,
      Value<String>? status,
      Value<String?>? result,
      Value<String?>? error,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return TasksCompanion(
      id: id ?? this.id,
      workflowId: workflowId ?? this.workflowId,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      handoffDepth: handoffDepth ?? this.handoffDepth,
      sourceNode: sourceNode ?? this.sourceNode,
      targetNode: targetNode ?? this.targetNode,
      instruction: instruction ?? this.instruction,
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
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
    if (workflowId.present) {
      map['workflow_id'] = Variable<String>(workflowId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
    }
    if (handoffDepth.present) {
      map['handoff_depth'] = Variable<int>(handoffDepth.value);
    }
    if (sourceNode.present) {
      map['source_node'] = Variable<String>(sourceNode.value);
    }
    if (targetNode.present) {
      map['target_node'] = Variable<String>(targetNode.value);
    }
    if (instruction.present) {
      map['instruction'] = Variable<String>(instruction.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('workflowId: $workflowId, ')
          ..write('projectId: $projectId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('handoffDepth: $handoffDepth, ')
          ..write('sourceNode: $sourceNode, ')
          ..write('targetNode: $targetNode, ')
          ..write('instruction: $instruction, ')
          ..write('status: $status, ')
          ..write('result: $result, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogTable extends AuditLog
    with TableInfo<$AuditLogTable, AuditLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
      'node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _capabilityMeta =
      const VerificationMeta('capability');
  @override
  late final GeneratedColumn<String> capability = GeneratedColumn<String>(
      'capability', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _decisionMeta =
      const VerificationMeta('decision');
  @override
  late final GeneratedColumn<String> decision = GeneratedColumn<String>(
      'decision', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, ts, nodeId, capability, decision, taskId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_log';
  @override
  VerificationContext validateIntegrity(Insertable<AuditLogData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(_nodeIdMeta,
          nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta));
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('capability')) {
      context.handle(
          _capabilityMeta,
          capability.isAcceptableOrUnknown(
              data['capability']!, _capabilityMeta));
    } else if (isInserting) {
      context.missing(_capabilityMeta);
    }
    if (data.containsKey('decision')) {
      context.handle(_decisionMeta,
          decision.isAcceptableOrUnknown(data['decision']!, _decisionMeta));
    } else if (isInserting) {
      context.missing(_decisionMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      nodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_id'])!,
      capability: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}capability'])!,
      decision: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}decision'])!,
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
    );
  }

  @override
  $AuditLogTable createAlias(String alias) {
    return $AuditLogTable(attachedDatabase, alias);
  }
}

class AuditLogData extends DataClass implements Insertable<AuditLogData> {
  final int id;
  final int ts;
  final String nodeId;
  final String capability;
  final String decision;
  final String taskId;
  const AuditLogData(
      {required this.id,
      required this.ts,
      required this.nodeId,
      required this.capability,
      required this.decision,
      required this.taskId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    map['node_id'] = Variable<String>(nodeId);
    map['capability'] = Variable<String>(capability);
    map['decision'] = Variable<String>(decision);
    map['task_id'] = Variable<String>(taskId);
    return map;
  }

  AuditLogCompanion toCompanion(bool nullToAbsent) {
    return AuditLogCompanion(
      id: Value(id),
      ts: Value(ts),
      nodeId: Value(nodeId),
      capability: Value(capability),
      decision: Value(decision),
      taskId: Value(taskId),
    );
  }

  factory AuditLogData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogData(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      capability: serializer.fromJson<String>(json['capability']),
      decision: serializer.fromJson<String>(json['decision']),
      taskId: serializer.fromJson<String>(json['taskId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'nodeId': serializer.toJson<String>(nodeId),
      'capability': serializer.toJson<String>(capability),
      'decision': serializer.toJson<String>(decision),
      'taskId': serializer.toJson<String>(taskId),
    };
  }

  AuditLogData copyWith(
          {int? id,
          int? ts,
          String? nodeId,
          String? capability,
          String? decision,
          String? taskId}) =>
      AuditLogData(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        nodeId: nodeId ?? this.nodeId,
        capability: capability ?? this.capability,
        decision: decision ?? this.decision,
        taskId: taskId ?? this.taskId,
      );
  AuditLogData copyWithCompanion(AuditLogCompanion data) {
    return AuditLogData(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      capability:
          data.capability.present ? data.capability.value : this.capability,
      decision: data.decision.present ? data.decision.value : this.decision,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogData(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('nodeId: $nodeId, ')
          ..write('capability: $capability, ')
          ..write('decision: $decision, ')
          ..write('taskId: $taskId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, nodeId, capability, decision, taskId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogData &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.nodeId == this.nodeId &&
          other.capability == this.capability &&
          other.decision == this.decision &&
          other.taskId == this.taskId);
}

class AuditLogCompanion extends UpdateCompanion<AuditLogData> {
  final Value<int> id;
  final Value<int> ts;
  final Value<String> nodeId;
  final Value<String> capability;
  final Value<String> decision;
  final Value<String> taskId;
  const AuditLogCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.capability = const Value.absent(),
    this.decision = const Value.absent(),
    this.taskId = const Value.absent(),
  });
  AuditLogCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    required String nodeId,
    required String capability,
    required String decision,
    required String taskId,
  })  : ts = Value(ts),
        nodeId = Value(nodeId),
        capability = Value(capability),
        decision = Value(decision),
        taskId = Value(taskId);
  static Insertable<AuditLogData> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<String>? nodeId,
    Expression<String>? capability,
    Expression<String>? decision,
    Expression<String>? taskId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (nodeId != null) 'node_id': nodeId,
      if (capability != null) 'capability': capability,
      if (decision != null) 'decision': decision,
      if (taskId != null) 'task_id': taskId,
    });
  }

  AuditLogCompanion copyWith(
      {Value<int>? id,
      Value<int>? ts,
      Value<String>? nodeId,
      Value<String>? capability,
      Value<String>? decision,
      Value<String>? taskId}) {
    return AuditLogCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      nodeId: nodeId ?? this.nodeId,
      capability: capability ?? this.capability,
      decision: decision ?? this.decision,
      taskId: taskId ?? this.taskId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (capability.present) {
      map['capability'] = Variable<String>(capability.value);
    }
    if (decision.present) {
      map['decision'] = Variable<String>(decision.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('nodeId: $nodeId, ')
          ..write('capability: $capability, ')
          ..write('decision: $decision, ')
          ..write('taskId: $taskId')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectRecordsTable extends ProjectRecords
    with TableInfo<$ProjectRecordsTable, ProjectRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_records';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ProjectRecordsTable createAlias(String alias) {
    return $ProjectRecordsTable(attachedDatabase, alias);
  }
}

class ProjectRecord extends DataClass implements Insertable<ProjectRecord> {
  final String id;
  final String name;
  final int createdAt;
  const ProjectRecord(
      {required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ProjectRecordsCompanion toCompanion(bool nullToAbsent) {
    return ProjectRecordsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory ProjectRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRecord(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ProjectRecord copyWith({String? id, String? name, int? createdAt}) =>
      ProjectRecord(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  ProjectRecord copyWithCompanion(ProjectRecordsCompanion data) {
    return ProjectRecord(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRecord(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRecord &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class ProjectRecordsCompanion extends UpdateCompanion<ProjectRecord> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ProjectRecordsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectRecordsCompanion.insert({
    required String id,
    required String name,
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<ProjectRecord> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return ProjectRecordsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
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
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRecordsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ApprovalGrantsTable extends ApprovalGrants
    with TableInfo<$ApprovalGrantsTable, ApprovalGrant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApprovalGrantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
      'node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _capabilityMeta =
      const VerificationMeta('capability');
  @override
  late final GeneratedColumn<String> capability = GeneratedColumn<String>(
      'capability', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _grantedAtMeta =
      const VerificationMeta('grantedAt');
  @override
  late final GeneratedColumn<int> grantedAt = GeneratedColumn<int>(
      'granted_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [projectId, nodeId, capability, grantedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'approval_grants';
  @override
  VerificationContext validateIntegrity(Insertable<ApprovalGrant> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(_nodeIdMeta,
          nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta));
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('capability')) {
      context.handle(
          _capabilityMeta,
          capability.isAcceptableOrUnknown(
              data['capability']!, _capabilityMeta));
    } else if (isInserting) {
      context.missing(_capabilityMeta);
    }
    if (data.containsKey('granted_at')) {
      context.handle(_grantedAtMeta,
          grantedAt.isAcceptableOrUnknown(data['granted_at']!, _grantedAtMeta));
    } else if (isInserting) {
      context.missing(_grantedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId, nodeId, capability};
  @override
  ApprovalGrant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApprovalGrant(
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      nodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_id'])!,
      capability: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}capability'])!,
      grantedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}granted_at'])!,
    );
  }

  @override
  $ApprovalGrantsTable createAlias(String alias) {
    return $ApprovalGrantsTable(attachedDatabase, alias);
  }
}

class ApprovalGrant extends DataClass implements Insertable<ApprovalGrant> {
  final String projectId;
  final String nodeId;
  final String capability;
  final int grantedAt;
  const ApprovalGrant(
      {required this.projectId,
      required this.nodeId,
      required this.capability,
      required this.grantedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['node_id'] = Variable<String>(nodeId);
    map['capability'] = Variable<String>(capability);
    map['granted_at'] = Variable<int>(grantedAt);
    return map;
  }

  ApprovalGrantsCompanion toCompanion(bool nullToAbsent) {
    return ApprovalGrantsCompanion(
      projectId: Value(projectId),
      nodeId: Value(nodeId),
      capability: Value(capability),
      grantedAt: Value(grantedAt),
    );
  }

  factory ApprovalGrant.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApprovalGrant(
      projectId: serializer.fromJson<String>(json['projectId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      capability: serializer.fromJson<String>(json['capability']),
      grantedAt: serializer.fromJson<int>(json['grantedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'nodeId': serializer.toJson<String>(nodeId),
      'capability': serializer.toJson<String>(capability),
      'grantedAt': serializer.toJson<int>(grantedAt),
    };
  }

  ApprovalGrant copyWith(
          {String? projectId,
          String? nodeId,
          String? capability,
          int? grantedAt}) =>
      ApprovalGrant(
        projectId: projectId ?? this.projectId,
        nodeId: nodeId ?? this.nodeId,
        capability: capability ?? this.capability,
        grantedAt: grantedAt ?? this.grantedAt,
      );
  ApprovalGrant copyWithCompanion(ApprovalGrantsCompanion data) {
    return ApprovalGrant(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      capability:
          data.capability.present ? data.capability.value : this.capability,
      grantedAt: data.grantedAt.present ? data.grantedAt.value : this.grantedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApprovalGrant(')
          ..write('projectId: $projectId, ')
          ..write('nodeId: $nodeId, ')
          ..write('capability: $capability, ')
          ..write('grantedAt: $grantedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(projectId, nodeId, capability, grantedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApprovalGrant &&
          other.projectId == this.projectId &&
          other.nodeId == this.nodeId &&
          other.capability == this.capability &&
          other.grantedAt == this.grantedAt);
}

class ApprovalGrantsCompanion extends UpdateCompanion<ApprovalGrant> {
  final Value<String> projectId;
  final Value<String> nodeId;
  final Value<String> capability;
  final Value<int> grantedAt;
  final Value<int> rowid;
  const ApprovalGrantsCompanion({
    this.projectId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.capability = const Value.absent(),
    this.grantedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ApprovalGrantsCompanion.insert({
    required String projectId,
    required String nodeId,
    required String capability,
    required int grantedAt,
    this.rowid = const Value.absent(),
  })  : projectId = Value(projectId),
        nodeId = Value(nodeId),
        capability = Value(capability),
        grantedAt = Value(grantedAt);
  static Insertable<ApprovalGrant> custom({
    Expression<String>? projectId,
    Expression<String>? nodeId,
    Expression<String>? capability,
    Expression<int>? grantedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (nodeId != null) 'node_id': nodeId,
      if (capability != null) 'capability': capability,
      if (grantedAt != null) 'granted_at': grantedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ApprovalGrantsCompanion copyWith(
      {Value<String>? projectId,
      Value<String>? nodeId,
      Value<String>? capability,
      Value<int>? grantedAt,
      Value<int>? rowid}) {
    return ApprovalGrantsCompanion(
      projectId: projectId ?? this.projectId,
      nodeId: nodeId ?? this.nodeId,
      capability: capability ?? this.capability,
      grantedAt: grantedAt ?? this.grantedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (capability.present) {
      map['capability'] = Variable<String>(capability.value);
    }
    if (grantedAt.present) {
      map['granted_at'] = Variable<int>(grantedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApprovalGrantsCompanion(')
          ..write('projectId: $projectId, ')
          ..write('nodeId: $nodeId, ')
          ..write('capability: $capability, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BridgeDatabase extends GeneratedDatabase {
  _$BridgeDatabase(QueryExecutor e) : super(e);
  $BridgeDatabaseManager get managers => $BridgeDatabaseManager(this);
  late final $NodesTable nodes = $NodesTable(this);
  late final $WorkflowsTable workflows = $WorkflowsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $AuditLogTable auditLog = $AuditLogTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ProjectRecordsTable projectRecords = $ProjectRecordsTable(this);
  late final $ApprovalGrantsTable approvalGrants = $ApprovalGrantsTable(this);
  late final NodesDao nodesDao = NodesDao(this as BridgeDatabase);
  late final WorkflowsDao workflowsDao = WorkflowsDao(this as BridgeDatabase);
  late final TasksDao tasksDao = TasksDao(this as BridgeDatabase);
  late final AuditDao auditDao = AuditDao(this as BridgeDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as BridgeDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        nodes,
        workflows,
        tasks,
        auditLog,
        settings,
        projectRecords,
        approvalGrants
      ];
}

typedef $$NodesTableCreateCompanionBuilder = NodesCompanion Function({
  required String id,
  required String name,
  required String kind,
  Value<String?> url,
  Value<int?> tabId,
  Value<String> permissionTier,
  Value<String> health,
  required int createdAt,
  Value<int> rowid,
});
typedef $$NodesTableUpdateCompanionBuilder = NodesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> kind,
  Value<String?> url,
  Value<int?> tabId,
  Value<String> permissionTier,
  Value<String> health,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$NodesTableFilterComposer
    extends Composer<_$BridgeDatabase, $NodesTable> {
  $$NodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tabId => $composableBuilder(
      column: $table.tabId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get permissionTier => $composableBuilder(
      column: $table.permissionTier,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get health => $composableBuilder(
      column: $table.health, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$NodesTableOrderingComposer
    extends Composer<_$BridgeDatabase, $NodesTable> {
  $$NodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tabId => $composableBuilder(
      column: $table.tabId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get permissionTier => $composableBuilder(
      column: $table.permissionTier,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get health => $composableBuilder(
      column: $table.health, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$NodesTableAnnotationComposer
    extends Composer<_$BridgeDatabase, $NodesTable> {
  $$NodesTableAnnotationComposer({
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

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get tabId =>
      $composableBuilder(column: $table.tabId, builder: (column) => column);

  GeneratedColumn<String> get permissionTier => $composableBuilder(
      column: $table.permissionTier, builder: (column) => column);

  GeneratedColumn<String> get health =>
      $composableBuilder(column: $table.health, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$NodesTableTableManager extends RootTableManager<
    _$BridgeDatabase,
    $NodesTable,
    Node,
    $$NodesTableFilterComposer,
    $$NodesTableOrderingComposer,
    $$NodesTableAnnotationComposer,
    $$NodesTableCreateCompanionBuilder,
    $$NodesTableUpdateCompanionBuilder,
    (Node, BaseReferences<_$BridgeDatabase, $NodesTable, Node>),
    Node,
    PrefetchHooks Function()> {
  $$NodesTableTableManager(_$BridgeDatabase db, $NodesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> url = const Value.absent(),
            Value<int?> tabId = const Value.absent(),
            Value<String> permissionTier = const Value.absent(),
            Value<String> health = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NodesCompanion(
            id: id,
            name: name,
            kind: kind,
            url: url,
            tabId: tabId,
            permissionTier: permissionTier,
            health: health,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String kind,
            Value<String?> url = const Value.absent(),
            Value<int?> tabId = const Value.absent(),
            Value<String> permissionTier = const Value.absent(),
            Value<String> health = const Value.absent(),
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              NodesCompanion.insert(
            id: id,
            name: name,
            kind: kind,
            url: url,
            tabId: tabId,
            permissionTier: permissionTier,
            health: health,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$NodesTable, Node>(table),
                    BaseReferences<_$BridgeDatabase, $NodesTable, Node>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NodesTableProcessedTableManager = ProcessedTableManager<
    _$BridgeDatabase,
    $NodesTable,
    Node,
    $$NodesTableFilterComposer,
    $$NodesTableOrderingComposer,
    $$NodesTableAnnotationComposer,
    $$NodesTableCreateCompanionBuilder,
    $$NodesTableUpdateCompanionBuilder,
    (Node, BaseReferences<_$BridgeDatabase, $NodesTable, Node>),
    Node,
    PrefetchHooks Function()>;
typedef $$WorkflowsTableCreateCompanionBuilder = WorkflowsCompanion Function({
  required String id,
  required String name,
  required String graphJson,
  required int createdAt,
  Value<int> rowid,
});
typedef $$WorkflowsTableUpdateCompanionBuilder = WorkflowsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> graphJson,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$WorkflowsTableFilterComposer
    extends Composer<_$BridgeDatabase, $WorkflowsTable> {
  $$WorkflowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get graphJson => $composableBuilder(
      column: $table.graphJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$WorkflowsTableOrderingComposer
    extends Composer<_$BridgeDatabase, $WorkflowsTable> {
  $$WorkflowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get graphJson => $composableBuilder(
      column: $table.graphJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$WorkflowsTableAnnotationComposer
    extends Composer<_$BridgeDatabase, $WorkflowsTable> {
  $$WorkflowsTableAnnotationComposer({
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

  GeneratedColumn<String> get graphJson =>
      $composableBuilder(column: $table.graphJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WorkflowsTableTableManager extends RootTableManager<
    _$BridgeDatabase,
    $WorkflowsTable,
    Workflow,
    $$WorkflowsTableFilterComposer,
    $$WorkflowsTableOrderingComposer,
    $$WorkflowsTableAnnotationComposer,
    $$WorkflowsTableCreateCompanionBuilder,
    $$WorkflowsTableUpdateCompanionBuilder,
    (Workflow, BaseReferences<_$BridgeDatabase, $WorkflowsTable, Workflow>),
    Workflow,
    PrefetchHooks Function()> {
  $$WorkflowsTableTableManager(_$BridgeDatabase db, $WorkflowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkflowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkflowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkflowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> graphJson = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkflowsCompanion(
            id: id,
            name: name,
            graphJson: graphJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String graphJson,
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkflowsCompanion.insert(
            id: id,
            name: name,
            graphJson: graphJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WorkflowsTable, Workflow>(table),
                    BaseReferences<_$BridgeDatabase, $WorkflowsTable, Workflow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkflowsTableProcessedTableManager = ProcessedTableManager<
    _$BridgeDatabase,
    $WorkflowsTable,
    Workflow,
    $$WorkflowsTableFilterComposer,
    $$WorkflowsTableOrderingComposer,
    $$WorkflowsTableAnnotationComposer,
    $$WorkflowsTableCreateCompanionBuilder,
    $$WorkflowsTableUpdateCompanionBuilder,
    (Workflow, BaseReferences<_$BridgeDatabase, $WorkflowsTable, Workflow>),
    Workflow,
    PrefetchHooks Function()>;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String id,
  Value<String?> workflowId,
  Value<String?> projectId,
  Value<String?> parentTaskId,
  Value<int> handoffDepth,
  required String sourceNode,
  required String targetNode,
  required String instruction,
  Value<String> status,
  Value<String?> result,
  Value<String?> error,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> id,
  Value<String?> workflowId,
  Value<String?> projectId,
  Value<String?> parentTaskId,
  Value<int> handoffDepth,
  Value<String> sourceNode,
  Value<String> targetNode,
  Value<String> instruction,
  Value<String> status,
  Value<String?> result,
  Value<String?> error,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$TasksTableFilterComposer
    extends Composer<_$BridgeDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workflowId => $composableBuilder(
      column: $table.workflowId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get handoffDepth => $composableBuilder(
      column: $table.handoffDepth, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceNode => $composableBuilder(
      column: $table.sourceNode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetNode => $composableBuilder(
      column: $table.targetNode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get instruction => $composableBuilder(
      column: $table.instruction, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TasksTableOrderingComposer
    extends Composer<_$BridgeDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workflowId => $composableBuilder(
      column: $table.workflowId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get handoffDepth => $composableBuilder(
      column: $table.handoffDepth,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceNode => $composableBuilder(
      column: $table.sourceNode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetNode => $composableBuilder(
      column: $table.targetNode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get instruction => $composableBuilder(
      column: $table.instruction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TasksTableAnnotationComposer
    extends Composer<_$BridgeDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workflowId => $composableBuilder(
      column: $table.workflowId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId, builder: (column) => column);

  GeneratedColumn<int> get handoffDepth => $composableBuilder(
      column: $table.handoffDepth, builder: (column) => column);

  GeneratedColumn<String> get sourceNode => $composableBuilder(
      column: $table.sourceNode, builder: (column) => column);

  GeneratedColumn<String> get targetNode => $composableBuilder(
      column: $table.targetNode, builder: (column) => column);

  GeneratedColumn<String> get instruction => $composableBuilder(
      column: $table.instruction, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TasksTableTableManager extends RootTableManager<
    _$BridgeDatabase,
    $TasksTable,
    Task,
    $$TasksTableFilterComposer,
    $$TasksTableOrderingComposer,
    $$TasksTableAnnotationComposer,
    $$TasksTableCreateCompanionBuilder,
    $$TasksTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$BridgeDatabase, $TasksTable, Task>),
    Task,
    PrefetchHooks Function()> {
  $$TasksTableTableManager(_$BridgeDatabase db, $TasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> workflowId = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String?> parentTaskId = const Value.absent(),
            Value<int> handoffDepth = const Value.absent(),
            Value<String> sourceNode = const Value.absent(),
            Value<String> targetNode = const Value.absent(),
            Value<String> instruction = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> result = const Value.absent(),
            Value<String?> error = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TasksCompanion(
            id: id,
            workflowId: workflowId,
            projectId: projectId,
            parentTaskId: parentTaskId,
            handoffDepth: handoffDepth,
            sourceNode: sourceNode,
            targetNode: targetNode,
            instruction: instruction,
            status: status,
            result: result,
            error: error,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> workflowId = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String?> parentTaskId = const Value.absent(),
            Value<int> handoffDepth = const Value.absent(),
            required String sourceNode,
            required String targetNode,
            required String instruction,
            Value<String> status = const Value.absent(),
            Value<String?> result = const Value.absent(),
            Value<String?> error = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TasksCompanion.insert(
            id: id,
            workflowId: workflowId,
            projectId: projectId,
            parentTaskId: parentTaskId,
            handoffDepth: handoffDepth,
            sourceNode: sourceNode,
            targetNode: targetNode,
            instruction: instruction,
            status: status,
            result: result,
            error: error,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TasksTable, Task>(table),
                    BaseReferences<_$BridgeDatabase, $TasksTable, Task>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TasksTableProcessedTableManager = ProcessedTableManager<
    _$BridgeDatabase,
    $TasksTable,
    Task,
    $$TasksTableFilterComposer,
    $$TasksTableOrderingComposer,
    $$TasksTableAnnotationComposer,
    $$TasksTableCreateCompanionBuilder,
    $$TasksTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$BridgeDatabase, $TasksTable, Task>),
    Task,
    PrefetchHooks Function()>;
typedef $$AuditLogTableCreateCompanionBuilder = AuditLogCompanion Function({
  Value<int> id,
  required int ts,
  required String nodeId,
  required String capability,
  required String decision,
  required String taskId,
});
typedef $$AuditLogTableUpdateCompanionBuilder = AuditLogCompanion Function({
  Value<int> id,
  Value<int> ts,
  Value<String> nodeId,
  Value<String> capability,
  Value<String> decision,
  Value<String> taskId,
});

class $$AuditLogTableFilterComposer
    extends Composer<_$BridgeDatabase, $AuditLogTable> {
  $$AuditLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get capability => $composableBuilder(
      column: $table.capability, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get decision => $composableBuilder(
      column: $table.decision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));
}

class $$AuditLogTableOrderingComposer
    extends Composer<_$BridgeDatabase, $AuditLogTable> {
  $$AuditLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get capability => $composableBuilder(
      column: $table.capability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get decision => $composableBuilder(
      column: $table.decision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));
}

class $$AuditLogTableAnnotationComposer
    extends Composer<_$BridgeDatabase, $AuditLogTable> {
  $$AuditLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get capability => $composableBuilder(
      column: $table.capability, builder: (column) => column);

  GeneratedColumn<String> get decision =>
      $composableBuilder(column: $table.decision, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);
}

class $$AuditLogTableTableManager extends RootTableManager<
    _$BridgeDatabase,
    $AuditLogTable,
    AuditLogData,
    $$AuditLogTableFilterComposer,
    $$AuditLogTableOrderingComposer,
    $$AuditLogTableAnnotationComposer,
    $$AuditLogTableCreateCompanionBuilder,
    $$AuditLogTableUpdateCompanionBuilder,
    (
      AuditLogData,
      BaseReferences<_$BridgeDatabase, $AuditLogTable, AuditLogData>
    ),
    AuditLogData,
    PrefetchHooks Function()> {
  $$AuditLogTableTableManager(_$BridgeDatabase db, $AuditLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<String> nodeId = const Value.absent(),
            Value<String> capability = const Value.absent(),
            Value<String> decision = const Value.absent(),
            Value<String> taskId = const Value.absent(),
          }) =>
              AuditLogCompanion(
            id: id,
            ts: ts,
            nodeId: nodeId,
            capability: capability,
            decision: decision,
            taskId: taskId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ts,
            required String nodeId,
            required String capability,
            required String decision,
            required String taskId,
          }) =>
              AuditLogCompanion.insert(
            id: id,
            ts: ts,
            nodeId: nodeId,
            capability: capability,
            decision: decision,
            taskId: taskId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AuditLogTable, AuditLogData>(table),
                    BaseReferences<_$BridgeDatabase, $AuditLogTable,
                        AuditLogData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AuditLogTableProcessedTableManager = ProcessedTableManager<
    _$BridgeDatabase,
    $AuditLogTable,
    AuditLogData,
    $$AuditLogTableFilterComposer,
    $$AuditLogTableOrderingComposer,
    $$AuditLogTableAnnotationComposer,
    $$AuditLogTableCreateCompanionBuilder,
    $$AuditLogTableUpdateCompanionBuilder,
    (
      AuditLogData,
      BaseReferences<_$BridgeDatabase, $AuditLogTable, AuditLogData>
    ),
    AuditLogData,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$BridgeDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$BridgeDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$BridgeDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$BridgeDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$BridgeDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$BridgeDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SettingsTable, Setting>(table),
                    BaseReferences<_$BridgeDatabase, $SettingsTable, Setting>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$BridgeDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$BridgeDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;
typedef $$ProjectRecordsTableCreateCompanionBuilder = ProjectRecordsCompanion
    Function({
  required String id,
  required String name,
  required int createdAt,
  Value<int> rowid,
});
typedef $$ProjectRecordsTableUpdateCompanionBuilder = ProjectRecordsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$ProjectRecordsTableFilterComposer
    extends Composer<_$BridgeDatabase, $ProjectRecordsTable> {
  $$ProjectRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ProjectRecordsTableOrderingComposer
    extends Composer<_$BridgeDatabase, $ProjectRecordsTable> {
  $$ProjectRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ProjectRecordsTableAnnotationComposer
    extends Composer<_$BridgeDatabase, $ProjectRecordsTable> {
  $$ProjectRecordsTableAnnotationComposer({
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

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProjectRecordsTableTableManager extends RootTableManager<
    _$BridgeDatabase,
    $ProjectRecordsTable,
    ProjectRecord,
    $$ProjectRecordsTableFilterComposer,
    $$ProjectRecordsTableOrderingComposer,
    $$ProjectRecordsTableAnnotationComposer,
    $$ProjectRecordsTableCreateCompanionBuilder,
    $$ProjectRecordsTableUpdateCompanionBuilder,
    (
      ProjectRecord,
      BaseReferences<_$BridgeDatabase, $ProjectRecordsTable, ProjectRecord>
    ),
    ProjectRecord,
    PrefetchHooks Function()> {
  $$ProjectRecordsTableTableManager(
      _$BridgeDatabase db, $ProjectRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectRecordsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectRecordsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProjectRecordsTable, ProjectRecord>(table),
                    BaseReferences<_$BridgeDatabase, $ProjectRecordsTable,
                        ProjectRecord>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProjectRecordsTableProcessedTableManager = ProcessedTableManager<
    _$BridgeDatabase,
    $ProjectRecordsTable,
    ProjectRecord,
    $$ProjectRecordsTableFilterComposer,
    $$ProjectRecordsTableOrderingComposer,
    $$ProjectRecordsTableAnnotationComposer,
    $$ProjectRecordsTableCreateCompanionBuilder,
    $$ProjectRecordsTableUpdateCompanionBuilder,
    (
      ProjectRecord,
      BaseReferences<_$BridgeDatabase, $ProjectRecordsTable, ProjectRecord>
    ),
    ProjectRecord,
    PrefetchHooks Function()>;
typedef $$ApprovalGrantsTableCreateCompanionBuilder = ApprovalGrantsCompanion
    Function({
  required String projectId,
  required String nodeId,
  required String capability,
  required int grantedAt,
  Value<int> rowid,
});
typedef $$ApprovalGrantsTableUpdateCompanionBuilder = ApprovalGrantsCompanion
    Function({
  Value<String> projectId,
  Value<String> nodeId,
  Value<String> capability,
  Value<int> grantedAt,
  Value<int> rowid,
});

class $$ApprovalGrantsTableFilterComposer
    extends Composer<_$BridgeDatabase, $ApprovalGrantsTable> {
  $$ApprovalGrantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get capability => $composableBuilder(
      column: $table.capability, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get grantedAt => $composableBuilder(
      column: $table.grantedAt, builder: (column) => ColumnFilters(column));
}

class $$ApprovalGrantsTableOrderingComposer
    extends Composer<_$BridgeDatabase, $ApprovalGrantsTable> {
  $$ApprovalGrantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get capability => $composableBuilder(
      column: $table.capability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get grantedAt => $composableBuilder(
      column: $table.grantedAt, builder: (column) => ColumnOrderings(column));
}

class $$ApprovalGrantsTableAnnotationComposer
    extends Composer<_$BridgeDatabase, $ApprovalGrantsTable> {
  $$ApprovalGrantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get capability => $composableBuilder(
      column: $table.capability, builder: (column) => column);

  GeneratedColumn<int> get grantedAt =>
      $composableBuilder(column: $table.grantedAt, builder: (column) => column);
}

class $$ApprovalGrantsTableTableManager extends RootTableManager<
    _$BridgeDatabase,
    $ApprovalGrantsTable,
    ApprovalGrant,
    $$ApprovalGrantsTableFilterComposer,
    $$ApprovalGrantsTableOrderingComposer,
    $$ApprovalGrantsTableAnnotationComposer,
    $$ApprovalGrantsTableCreateCompanionBuilder,
    $$ApprovalGrantsTableUpdateCompanionBuilder,
    (
      ApprovalGrant,
      BaseReferences<_$BridgeDatabase, $ApprovalGrantsTable, ApprovalGrant>
    ),
    ApprovalGrant,
    PrefetchHooks Function()> {
  $$ApprovalGrantsTableTableManager(
      _$BridgeDatabase db, $ApprovalGrantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApprovalGrantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApprovalGrantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApprovalGrantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> projectId = const Value.absent(),
            Value<String> nodeId = const Value.absent(),
            Value<String> capability = const Value.absent(),
            Value<int> grantedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ApprovalGrantsCompanion(
            projectId: projectId,
            nodeId: nodeId,
            capability: capability,
            grantedAt: grantedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String projectId,
            required String nodeId,
            required String capability,
            required int grantedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ApprovalGrantsCompanion.insert(
            projectId: projectId,
            nodeId: nodeId,
            capability: capability,
            grantedAt: grantedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ApprovalGrantsTable, ApprovalGrant>(table),
                    BaseReferences<_$BridgeDatabase, $ApprovalGrantsTable,
                        ApprovalGrant>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ApprovalGrantsTableProcessedTableManager = ProcessedTableManager<
    _$BridgeDatabase,
    $ApprovalGrantsTable,
    ApprovalGrant,
    $$ApprovalGrantsTableFilterComposer,
    $$ApprovalGrantsTableOrderingComposer,
    $$ApprovalGrantsTableAnnotationComposer,
    $$ApprovalGrantsTableCreateCompanionBuilder,
    $$ApprovalGrantsTableUpdateCompanionBuilder,
    (
      ApprovalGrant,
      BaseReferences<_$BridgeDatabase, $ApprovalGrantsTable, ApprovalGrant>
    ),
    ApprovalGrant,
    PrefetchHooks Function()>;

class $BridgeDatabaseManager {
  final _$BridgeDatabase _db;
  $BridgeDatabaseManager(this._db);
  $$NodesTableTableManager get nodes =>
      $$NodesTableTableManager(_db, _db.nodes);
  $$WorkflowsTableTableManager get workflows =>
      $$WorkflowsTableTableManager(_db, _db.workflows);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$AuditLogTableTableManager get auditLog =>
      $$AuditLogTableTableManager(_db, _db.auditLog);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ProjectRecordsTableTableManager get projectRecords =>
      $$ProjectRecordsTableTableManager(_db, _db.projectRecords);
  $$ApprovalGrantsTableTableManager get approvalGrants =>
      $$ApprovalGrantsTableTableManager(_db, _db.approvalGrants);
}
