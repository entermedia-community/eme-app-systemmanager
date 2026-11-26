import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/download.dart';
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
                  _TablePicker(
                    key: ValueKey(current),
                    tables: list,
                    current: current,
                    onSelected: (t) => context.go(
                      '/database?table=${Uri.encodeQueryComponent(t)}',
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
      length: 3,
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Data'),
                Tab(text: 'Customize Fields'),
                Tab(text: 'Elastic System Info'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DataTab(table: table),
                _FieldsTab(table: table),
                _ElasticTab(table: table),
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
  List<Json> _terms = const [];

  Store get _store => Store.lists(widget.table);

  ({Store store, ListQuery query}) get _key => (
    store: _store,
    query: ListQuery(
      text: _text,
      page: _page,
      sortField: _sort,
      sortAscending: _asc,
      terms: _terms,
    ),
  );

  Future<void> _search(List<FieldDef> fields) async {
    final terms = await showDialog<List<Json>>(
      context: context,
      builder: (_) => _SearchDialog(
        fields: [
          for (final f in fields)
            if (!f.internal && !f.isComplex) f,
        ],
        terms: _terms,
      ),
    );
    if (terms == null) return;
    setState(() {
      _terms = terms;
      _page = 1;
    });
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Import into ${widget.table}',
    );
    if (picked.isEmpty || !mounted) return;
    final file = picked.first.xFile;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await runServerAction(
      context,
      () async =>
          (await ref
                  .read(repositoryProvider)
                  .importFile(widget.table, bytes: bytes, fileName: file.name))
              .message,
      success: 'Import complete',
    );
    ref.invalidate(recordsProvider);
  }

  Future<void> _export({required bool friendly}) =>
      runServerAction(context, () async {
        final bytes = await ref
            .read(repositoryProvider)
            .exportCsv(widget.table, friendly: friendly);
        saveBytes(bytes, '${widget.table}.csv', mimeType: 'text/csv');
        return '';
      }, success: 'Export ready');

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
            OutlinedButton.icon(
              onPressed: () => _search(fields),
              icon: Icon(
                Ph.magnifyingGlass,
                size: 16,
                color: _terms.isEmpty ? null : context.scheme.primary,
              ),
              label: Text(
                _terms.isEmpty ? 'Search' : 'Search (${_terms.length})',
              ),
            ),
            if (_terms.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  _terms = const [];
                  _page = 1;
                }),
                child: const Text('Clear'),
              ),
            OutlinedButton.icon(
              onPressed: () => _tableAction(
                'Reset fields of ${widget.table}?',
                'Restores the default field definitions. Export the data first.',
                () => repo.resetFields(widget.table),
                'Fields reset',
              ),
              icon: const Icon(Ph.rows, size: 16),
              label: const Text('Reset fields'),
            ),
            OutlinedButton.icon(
              onPressed: () => _tableAction(
                'Reset data of ${widget.table}?',
                'Restores the table to its default data. Export the data first.',
                () => repo.resetData(widget.table),
                'Data reset',
              ),
              icon: const Icon(Ph.database, size: 16),
              label: const Text('Reset data'),
            ),
            _ActionsMenu(
              total: page.value?.total,
              onSelected: (a) {
                final t = widget.table;
                final n = page.value?.total;
                switch (a) {
                  case _Act.import:
                    _import();
                  case _Act.export:
                    _export(friendly: false);
                  case _Act.exportText:
                    _export(friendly: true);
                  case _Act.reindex:
                    _tableAction(
                      'Reindex $t?',
                      'Rebuilds the search index for this table.',
                      () => repo.reindexTable(t),
                      'Reindexed',
                    );
                  case _Act.deleteAll:
                    _tableAction(
                      'Delete ${n ?? 'all'} records?',
                      'Removes every record of $t. Export the data first if you may need it.',
                      () => repo.deleteAllRecords(t),
                      'Records deleted',
                    );
                  case _Act.deleteTable:
                    _tableAction(
                      'Delete table $t?',
                      'All of its records are removed.',
                      () => repo.deleteTable(t),
                      'Table deleted',
                    );
                }
              },
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

class _ElasticTab extends ConsumerWidget {
  const _ElasticTab({required this.table});
  final String table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(elasticInfoProvider(table));
    return SectionPage(
      child: info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(elasticInfoProvider(table)),
        ),
        data: (i) {
          final mapping = i['mapping'];
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bean name: ${i['beanname'] ?? ''}'),
                const SizedBox(height: 12),
                SelectableText(
                  mapping == null
                      ? 'No mapping in the index yet.'
                      : const JsonEncoder.withIndent('  ').convert(mapping),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _Act { import, export, exportText, reindex, deleteAll, deleteTable }

/// The table's less frequent actions in one menu.
class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.onSelected, this.total});
  final void Function(_Act action) onSelected;
  final int? total;

  PopupMenuItem<_Act> _item(
    _Act a,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: a,
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final danger = context.scheme.error;
    return PopupMenuButton<_Act>(
      tooltip: 'Table actions',
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        _item(_Act.import, Ph.uploadSimple, 'Import'),
        _item(_Act.export, Ph.downloadSimple, 'Export'),
        _item(_Act.exportText, Ph.fileText, 'Export text'),
        const PopupMenuDivider(),
        _item(_Act.reindex, Ph.arrowsClockwise, 'Reindex'),
        const PopupMenuDivider(),
        _item(
          _Act.deleteAll,
          Ph.trash,
          total == null ? 'Delete all records' : 'Delete $total records',
          color: danger,
        ),
        _item(_Act.deleteTable, Ph.trash, 'Delete table', color: danger),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Ph.dotsThree, size: 18),
          label: const Text('Actions'),
        ),
      ),
    );
  }
}

/// Advanced search: one box per field. Filled boxes become terms.
class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.fields, required this.terms});
  final List<FieldDef> fields;
  final List<Json> terms;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final Map<String, TextEditingController> _c = {
    for (final f in widget.fields)
      f.id: TextEditingController(
        text:
            '${widget.terms.firstWhere((t) => t['field'] == f.id, orElse: () => const {})['value'] ?? ''}',
      ),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Json> _build() => [
    for (final f in widget.fields)
      if (_c[f.id]!.text.trim().isNotEmpty)
        {
          'field': f.id,
          // Free text fields match part of the value; lists, numbers and dates need the exact value.
          'operation': f.isList || f.isNumber || f.isDate || f.isBoolean
              ? 'matches'
              : 'contains',
          'value': _c[f.id]!.text.trim(),
        },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _c[f.id],
                    decoration: InputDecoration(
                      labelText: f.label(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => Navigator.pop(context, _build()),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _build()),
          child: const Text('Search'),
        ),
      ],
    );
  }
}

/// Type-to-filter table picker. Unlike DropdownMenu it builds only the rows on screen,
/// so it stays fast with hundreds of tables.
class _TablePicker extends StatelessWidget {
  const _TablePicker({
    super.key,
    required this.tables,
    required this.current,
    required this.onSelected,
  });
  final List<String> tables;
  final String? current;
  final void Function(String table) onSelected;

  static const _width = 280.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: current ?? ''),
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          // Showing the open table's own name should not hide the other tables.
          if (q.isEmpty || value.text == current) return tables;
          return tables.where((t) => t.toLowerCase().contains(q));
        },
        onSelected: (t) {
          if (t != current) onSelected(t);
        },
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: 'Table',
            isDense: true,
            suffixIcon: const Icon(Ph.caretDown, size: 14),
          ),
          onTap: () => controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        optionsViewBuilder: (context, onSelect, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 320,
                maxWidth: _width,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final t = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelect(t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        t,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: t == current ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
