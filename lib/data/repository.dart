import '../core/api_client.dart';
import 'models.dart';

/// Where a kind of record lives on the server. Most tables use the generic
/// `lists/*` services; users and groups have their own under `settings/*`.
class Store {
  const Store._(this.type, this._search, this._data, this._create);

  /// `lists/{search,data,create}/<type>`.
  const Store.lists(String type)
    : this._(
        type,
        'lists/search/$type',
        'lists/data/$type',
        'lists/create/$type',
      );

  /// `settings/<area>/{search,data,create}`.
  const Store.settings(String type, String area)
    : this._(
        type,
        'settings/$area/search',
        'settings/$area/data',
        'settings/$area/create',
      );

  final String type;
  final String _search;
  final String _data;
  final String _create;

  /// Value equality: a store built again on each build must be the same provider key.
  @override
  bool operator ==(Object other) =>
      other is Store &&
      other.type == type &&
      other._search == _search &&
      other._data == _data;

  @override
  int get hashCode => Object.hash(type, _search, _data);

  static const catalogSettings = Store.lists('catalogsettings');
  static const roles = Store.lists('settingsrole');
  static const permissions = Store.lists('permissionsapp');
  static const users = Store.settings('user', 'users');
  static const groups = Store.settings('group', 'groups');
}

class SearchPage {
  const SearchPage({
    required this.hits,
    required this.total,
    required this.page,
    required this.pages,
  });
  final List<Json> hits;
  final int total;
  final int page;
  final int pages;
}

/// Search request for a [Store]. Immutable with value equality so it can key a provider family.
class ListQuery {
  const ListQuery({
    this.text = '',
    this.page = 1,
    this.hitsPerPage = 25,
    this.sortField,
    this.sortAscending = true,
  });

  final String text;
  final int page;
  final int hitsPerPage;
  final String? sortField;
  final bool sortAscending;

  ListQuery copyWith({
    String? text,
    int? page,
    int? hitsPerPage,
    String? Function()? sortField,
    bool? sortAscending,
  }) => ListQuery(
    text: text ?? this.text,
    page: page ?? this.page,
    hitsPerPage: hitsPerPage ?? this.hitsPerPage,
    sortField: sortField != null ? sortField() : this.sortField,
    sortAscending: sortAscending ?? this.sortAscending,
  );

  Json toRequest(String type) => {
    'page': '$page',
    'hitsperpage': '$hitsPerPage',
    'query': {
      'terms': [
        text.trim().isEmpty
            ? {'field': 'id', 'operation': 'matches', 'value': '*'}
            : {
                'field': 'description',
                'operation': 'freeform',
                'value': text.trim(),
              },
      ],
    },
    if (sortField != null)
      '${type}sortby': '$sortField${sortAscending ? 'Up' : 'Down'}',
  };

  @override
  bool operator ==(Object other) =>
      other is ListQuery &&
      other.text == text &&
      other.page == page &&
      other.hitsPerPage == hitsPerPage &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending;

  @override
  int get hashCode =>
      Object.hash(text, page, hitsPerPage, sortField, sortAscending);
}

/// Server side status of an action (reindex, clear cache, ...), exactly as the server reports it.
class ActionResult {
  const ActionResult(this.status, this.raw);
  final String status;
  final Json raw;

  bool get ok =>
      const {'ok', 'complete', 'success'}.contains(status.toLowerCase());

  /// Everything else the server said, for display (time, message, ...).
  String get message {
    final r = raw['response'];
    final parts = <String>[];
    if (r is Map) {
      for (final e in r.entries) {
        if (e.key == 'status') continue;
        parts.add('${e.key}: ${e.value}');
      }
    }
    return parts.join(', ');
  }
}

/// Reindex, reset lists, snapshots and the like can take several minutes.
const longRunning = Duration(minutes: 30);

class SettingsRepository {
  SettingsRepository(this.api);
  final ApiClient api;

  static List<Json> _list(Object? v) => [
    for (final r in v as List? ?? const [])
      if (r is Json) r,
  ];

  // ---- generic records ----

  Future<SearchPage> search(Store store, ListQuery q) async {
    final res = await api.postJson(store._search, q.toRequest(store.type));
    final r = res['response'] as Map? ?? const {};
    return SearchPage(
      hits: _list(res['results']),
      total: int.tryParse('${r['totalhits'] ?? ''}') ?? 0,
      page: int.tryParse('${r['page'] ?? ''}') ?? q.page,
      pages: int.tryParse('${r['pages'] ?? ''}') ?? 1,
    );
  }

  Future<Json> load(Store store, String id) async {
    final res = await api.getJson('${store._data}/$id');
    final data = res['data'];
    if (data is! Json) throw ApiException('Record not found');
    return data;
  }

  /// Updates the record, or creates it when [id] is null. Returns the record id.
  Future<String> save(Store store, String? id, Json values) async {
    if (id != null) {
      await api.putJson('${store._data}/$id', values);
      return id;
    }
    final res = await api.postJson(store._create, values);
    final newId =
        (res['response'] as Map?)?['id'] ?? (res['data'] as Map?)?['id'];
    if (newId == null)
      throw ApiException('The server did not return the new record id');
    return '$newId';
  }

  Future<void> delete(Store store, String id) =>
      api.delete('${store._data}/$id');

  /// Every record of a small table (roles, permissions, ...), unpaged.
  Future<List<Json>> all(Store store, {String? sortField}) async {
    final page = await search(
      store,
      ListQuery(hitsPerPage: 500, sortField: sortField),
    );
    return page.hits;
  }

  Future<List<Json>> listOptions(String listId, {String text = ''}) async {
    final res = await api.postJson('lists/search/$listId', {
      'page': '1',
      'hitsperpage': '200',
      'query': {
        'terms': [
          text.isEmpty
              ? {'field': 'id', 'operation': 'matches', 'value': '*'}
              : {
                  'field': 'name',
                  'operation': 'contains',
                  'value': text.toLowerCase(),
                },
        ],
      },
    });
    return _list(res['results']);
  }

  // ---- database (tables and fields) ----

  Future<List<String>> tables() async {
    final res = await api.getJson('settings/datamanager/listtables');
    return [
      for (final r in _list(res['results']))
        if ('${r['name'] ?? r['id'] ?? ''}'.isNotEmpty)
          '${r['name'] ?? r['id']}',
    ];
  }

  Future<void> addTable(String name) async {
    await api.postForm('settings/datamanager/addtable', {'tablename': name});
  }

  Future<ActionResult> deleteTable(String name) =>
      _action('settings/datamanager/table/deletetable', {'searchtype': name});

  Future<ActionResult> reindexTable(String name) => _action(
    'settings/datamanager/table/reindex',
    {'searchtype': name},
    longRunning,
  );

  Future<List<FieldDef>> fields(String searchType) async {
    final res = await api.getJson(
      'settings/datamanager/fields/listfields',
      query: {'searchtype': searchType},
    );
    return [for (final r in _list(res['results'])) FieldDef(r)];
  }

  Future<void> addField(String table, String label, {String? dataType}) async {
    await api.postForm('settings/datamanager/fields/addnew', {
      'searchtype': table,
      'newproperty': label,
      if (dataType != null) 'datatype.value': dataType,
    });
  }

  Future<void> removeField(String table, String fieldId) async {
    await api.postForm('settings/datamanager/fields/remove', {
      'searchtype': table,
      'id': fieldId,
    });
  }

  // ---- users and groups ----

  Future<void> addUserToGroup(String userId, String groupId) async {
    await api.postForm('settings/users/groupadd', {
      'groupid': groupId,
      'addUsernames': userId,
    });
  }

  Future<void> removeUserFromGroup(String userId, String groupId) async {
    await api.postForm('settings/users/groupremove', {
      'groupid': groupId,
      'removeUsernames': userId,
    });
  }

  // ---- server actions ----

  Future<ActionResult> _action(
    String path, [
    Map<String, String> fields = const {},
    Duration? timeout,
  ]) async {
    final res = await api.postForm(path, fields, receiveTimeout: timeout);
    final r = res['response'];
    final status = r is Map
        ? '${r['status'] ?? 'ok'}'
        : '${res['status'] ?? 'ok'}';
    return ActionResult(status, res);
  }

  Future<ActionResult> clearCaches() => _action('system/cleardatacache');
  Future<ActionResult> reindexAll() =>
      _action('server/reindex', const {}, longRunning);
  Future<ActionResult> saveAllModules() =>
      _action('system/savemodules', const {}, longRunning);
  Future<ActionResult> reloadLists() =>
      _action('system/reloadlists', const {}, longRunning);
  Future<ActionResult> makeMaster() =>
      _action('system/makemaster', const {}, longRunning);
  Future<ActionResult> toggleSearchLogs() => _action('system/togglesearchlogs');
  Future<ActionResult> createSnapshot() =>
      _action('system/snapshotcreate', const {}, longRunning);
  Future<ActionResult> restoreSnapshot(String id) =>
      _action('system/snapshotrestore', {'id': id}, longRunning);

  Future<Json> serverInfo() => api.getJson('system/serverinfo');

  Future<List<Json>> mappingErrors() async =>
      _list((await api.getJson('system/mappingerrors'))['results']);

  Future<String> mappings() async =>
      '${(await api.getJson('system/mappings'))['mappings'] ?? ''}';

  Future<List<Json>> snapshots() async =>
      _list((await api.getJson('system/snapshots'))['results']);
}
