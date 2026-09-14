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
  int get hashCode => Object.hash(id, workflowId, sourceNode, targetNode,
      instruction, status, result, error, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.workflowId == this.workflowId &&
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

abstract class _$BridgeDatabase extends GeneratedDatabase {
  _$BridgeDatabase(QueryExecutor e) : super(e);
  $BridgeDatabaseManager get managers => $BridgeDatabaseManager(this);
  late final $NodesTable nodes = $NodesTable(this);
  late final $WorkflowsTable workflows = $WorkflowsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $AuditLogTable auditLog = $AuditLogTable(this);
  late final NodesDao nodesDao = NodesDao(this as BridgeDatabase);
  late final WorkflowsDao workflowsDao = WorkflowsDao(this as BridgeDatabase);
  late final TasksDao tasksDao = TasksDao(this as BridgeDatabase);
  late final AuditDao auditDao = AuditDao(this as BridgeDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [nodes, workflows, tasks, auditLog];
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
}
