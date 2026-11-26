import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/values.dart';
import '../../data/field_defs.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../widgets/common.dart';
import '../../widgets/data_table.dart';
import '../../widgets/record_dialog.dart';
import '../../widgets/section_page.dart';
import '../../core/ph.dart';

/// Catalog settings (`catalogsettings` table): label and value per setting.
class ParametersPage extends ConsumerStatefulWidget {
  const ParametersPage({super.key});

  @override
  ConsumerState<ParametersPage> createState() => _ParametersPageState();
}

class _ParametersPageState extends ConsumerState<ParametersPage> {
  var _text = '';
  var _page = 1;

  ({Store store, ListQuery query}) get _key => (
    store: Store.catalogSettings,
    query: ListQuery(
      text: _text,
      page: _page,
      hitsPerPage: 50,
      sortField: 'name',
    ),
  );

  Future<void> _edit(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    final saved = await showRecordDialog(
      context,
      title: displayValue(row['name']).isEmpty ? id : displayValue(row['name']),
      fields: [textField('name', 'Label'), textField('value', 'Value')],
      initial: row,
      onSave: (payload) async {
        final repo = ref.read(repositoryProvider);
        await repo.save(Store.catalogSettings, id, payload);
        // The legacy page clears the caches after a save so the new value is used right away.
        await repo.clearCaches();
      },
    );
    if (saved) ref.invalidate(recordsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(recordsProvider(_key));
    return SectionPage(
      subtitle: 'Settings for this catalog. Saving clears the server caches.',
      search: (t) => setState(() {
        _text = t;
        _page = 1;
      }),
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(recordsProvider),
          icon: const Icon(Ph.arrowsClockwise, size: 16),
          label: const Text('Refresh'),
        ),
      ],
      child: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: '$e',
          onRetry: () => ref.invalidate(recordsProvider),
        ),
        data: (p) => SettingsTable(
          columns: [
            TableColumn(
              'name',
              'Label',
              flex: 3,
              cell: (_, r) => Text(
                displayValue(r['name']).isEmpty
                    ? '${r['id']}'
                    : displayValue(r['name']),
              ),
            ),
            const TableColumn('id', 'Id', flex: 2),
            const TableColumn('value', 'Value', flex: 3, sortable: false),
          ],
          rows: p.hits,
          page: p.page,
          pages: p.pages,
          total: p.total,
          onPage: (n) => setState(() => _page = n),
          onTap: _edit,
          rowKey: (r) => '${r['id']}',
        ),
      ),
    );
  }
}
