import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ph.dart';
import '../../core/values.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/data_table.dart';
import '../../widgets/record_dialog.dart';
import '../../widgets/section_page.dart';

/// Database tables: browse and edit their rows, and manage their fields.
class DatabasePage extends ConsumerWidget {
  const DatabasePage({super.key, this.table});
  final String? table;

  Future<void> _newTable(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('New table'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Table name'),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await runServerAction(context, () async {
      await ref.read(repositoryProvider).addTable(name.trim());
      return '';
    }, success: 'Table created');
    ref.invalidate(tablesProvider);
    if (context.mounted)
      context.go(
        '/database?table=${Uri.encodeQueryComponent(name.trim().toLowerCase())}',
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    return tables.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorState(error: e, onRetry: () => ref.invalidate(tablesProvider)),
      data: (list) {
        final current = table != null && list.contains(table)
            ? table
            : (list.isEmpty ? null : list.first);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(current),
                      initialValue: current,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Table',
                        isDense: true,
                      ),
                      items: [
                        for (final t in list)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (t) => t == null
                          ? null
                          : context.go(
                              '/database?table=${Uri.encodeQueryComponent(t)}',
                            ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _newTable(context, ref),
                    icon: const Icon(Ph.plus, size: 16),
                    label: const Text('New table'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (current == null)
                const Expanded(
                  child: EmptyState(icon: Ph.database, title: 'No tables'),
                )
              else
                Expanded(
                  child: _TableView(key: ValueKey(current), table: current),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TableView extends ConsumerWidget {
  const _TableView({super.key, required this.table});
  final String table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Data'),
                Tab(text: 'Fields'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DataTab(table: table),
                _FieldsTab(table: table),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataTab extends ConsumerStatefulWidget {
  const _DataTab({required this.table});
  final String table;

  @override
  ConsumerState<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends ConsumerState<_DataTab> {
  var _text = '';
  var _page = 1;
  String? _sort;
  var _asc = true;

  Store get _store => Store.lists(widget.table);

  ({Store store, ListQuery query}) get _key => (
    store: _store,
    query: ListQuery(
      text: _text,
      page: _page,
      sortField: _sort,
      sortAscending: _asc,
    ),
  );

  Future<void> _open(List<FieldDef> fields, [Json? row]) async {
    final repo = ref.read(repositoryProvider);
    final id = row == null ? null : '${row['id']}';
    final saved = await showRecordDialog(
      context,
      title: row == null ? 'New ${widget.table}' : id!,
      fields: [
        for (final f in fields)
          if (!f.internal && f.editable && !f.isComplex) f,
      ],
      initial: row,
      onSave: (payload) async {
        await repo.save(_store, id, payload);
      },
      onDelete: id == null ? null : () => repo.delete(_store, id),
    );
    if (saved) ref.invalidate(recordsProvider);
  }

  Future<void> _tableAction(
    String title,
    String message,
    Future<ActionResult> Function() run,
    String done,
  ) async {
    final ok = await confirm(
      context,
      title: title,
      message: message,
      action: 'Continue',
    );
    if (!ok || !mounted) return;
    await runServerAction(
      context,
      () async => (await run()).message,
      success: done,
    );
    ref.invalidate(recordsProvider);
    ref.invalidate(tablesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(tableFieldsProvider(widget.table));
    final page = ref.watch(recordsProvider(_key));
    final repo = ref.read(repositoryProvider);
    return fieldsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(error: e),
      data: (fields) {
        final shown = [
          for (final f in fields)
            if (!f.internal && !f.isComplex && f.id != 'id') f,
        ].take(6).toList();
        return SectionPage(
          search: (t) => setState(() {
            _text = t;
            _page = 1;
          }),
          actions: [
            OutlinedButton(
              onPressed: () => _tableAction(
                'Reindex ${widget.table}?',
                'Rebuilds the search index for this table.',
                () => repo.reindexTable(widget.table),
                'Reindexed',
              ),
              child: const Text('Reindex'),
            ),
            OutlinedButton(
              onPressed: () => _tableAction(
                'Delete table ${widget.table}?',
                'All of its records are removed.',
                () => repo.deleteTable(widget.table),
                'Table deleted',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.scheme.error,
              ),
              child: const Text('Delete table'),
            ),
            FilledButton.icon(
              onPressed: () => _open(fields),
              icon: const Icon(Ph.plus, size: 16),
              label: const Text('Add'),
            ),
          ],
          child: page.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(recordsProvider),
            ),
            data: (p) => SettingsTable(
              columns: [
                const TableColumn('id', 'Id', flex: 2),
                for (final f in shown)
                  TableColumn(
                    f.id,
                    f.label(),
                    flex: 2,
                    cell: (_, r) => Text(
                      displayValue(r[f.id]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              rows: p.hits,
              page: p.page,
              pages: p.pages,
              total: p.total,
              sortField: _sort,
              sortAscending: _asc,
              onSort: (f) => setState(() {
                _asc = _sort == f ? !_asc : true;
                _sort = f;
              }),
              onPage: (n) => setState(() => _page = n),
              onTap: (r) => _open(fields, r),
              rowKey: (r) => '${r['id']}',
            ),
          ),
        );
      },
    );
  }
}

class _FieldsTab extends ConsumerWidget {
  const _FieldsTab({required this.table});
  final String table;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('New field'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Label'),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (label == null || label.trim().isEmpty || !context.mounted) return;
    await runServerAction(context, () async {
      await ref.read(repositoryProvider).addField(table, label.trim());
      return '';
    }, success: 'Field added');
    ref.invalidate(tableFieldsProvider(table));
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, FieldDef f) async {
    final ok = await confirm(
      context,
      title: 'Remove field ${f.id}?',
      message: 'The field is hidden from this table. Existing data stays in the index.',
      action: 'Remove',
    );
    if (!ok || !context.mounted) return;
    await runServerAction(context, () async {
      await ref.read(repositoryProvider).removeField(table, f.id);
      return '';
    }, success: 'Field removed');
    ref.invalidate(tableFieldsProvider(table));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fields = ref.watch(tableFieldsProvider(table));
    return SectionPage(
      subtitle:
          'Editing a field\'s type and view layout is not available here yet.',
      actions: [
        FilledButton.icon(
          onPressed: () => _add(context, ref),
          icon: const Icon(Ph.plus, size: 16),
          label: const Text('Add field'),
        ),
      ],
      child: fields.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(tableFieldsProvider(table)),
        ),
        data: (list) => SettingsTable(
          columns: [
            const TableColumn('id', 'Id', flex: 2, sortable: false),
            TableColumn(
              'name',
              'Label',
              flex: 2,
              sortable: false,
              cell: (_, r) => Text(FieldDef(r).label()),
            ),
            TableColumn(
              'datatype',
              'Type',
              flex: 1,
              sortable: false,
              cell: (_, r) => Text(FieldDef(r).datatype),
            ),
            TableColumn(
              'x',
              '',
              flex: 1,
              sortable: false,
              cell: (c, r) => Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Remove field',
                  icon: Icon(Ph.trash, size: 16, color: c.colors.muted),
                  onPressed: () => _remove(c, ref, FieldDef(r)),
                ),
              ),
            ),
          ],
          rows: [for (final f in list) f.raw],
          total: list.length,
          rowKey: (r) => '${r['id']}',
        ),
      ),
    );
  }
}
