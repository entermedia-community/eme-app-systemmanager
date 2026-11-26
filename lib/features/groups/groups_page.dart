import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ph.dart';
import '../../core/values.dart';
import '../../data/field_defs.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../widgets/common.dart';
import '../../widgets/data_table.dart';
import '../../widgets/record_dialog.dart';
import '../../widgets/section_page.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  var _text = '';
  var _page = 1;

  ({Store store, ListQuery query}) get _key => (
    store: Store.groups,
    query: ListQuery(text: _text, page: _page, sortField: 'name'),
  );

  static final _fields = [
    textField('name', 'Name'),
    boolField('enabled', 'Enabled'),
  ];

  Future<void> _open([Json? row]) async {
    final repo = ref.read(repositoryProvider);
    final id = row == null ? null : '${row['id']}';
    final saved = await showRecordDialog(
      context,
      title: row == null
          ? 'New group'
          : displayValue(row['name']).isEmpty
          ? id!
          : displayValue(row['name']),
      fields: _fields,
      initial: row,
      onSave: (payload) async {
        await repo.save(Store.groups, id, payload);
      },
      onDelete: id == null ? null : () => repo.delete(Store.groups, id),
      deleteMessage: 'Members lose the permissions this group gave them.',
    );
    if (saved) ref.invalidate(recordsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(recordsProvider(_key));
    return SectionPage(
      search: (t) => setState(() {
        _text = t;
        _page = 1;
      }),
      actions: [
        FilledButton.icon(
          onPressed: _open,
          icon: const Icon(Ph.plus, size: 16),
          label: const Text('New group'),
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
            const TableColumn('name', 'Name', flex: 3),
            const TableColumn('id', 'Id', flex: 2),
            TableColumn(
              'enabled',
              'Enabled',
              flex: 1,
              cell: (_, r) => Text('${r['enabled']}' == 'false' ? 'No' : 'Yes'),
            ),
          ],
          rows: p.hits,
          page: p.page,
          pages: p.pages,
          total: p.total,
          onPage: (n) => setState(() => _page = n),
          onTap: _open,
          rowKey: (r) => '${r['id']}',
        ),
      ),
    );
  }
}
