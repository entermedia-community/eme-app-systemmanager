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

  /// Boolean values already saved, so the switch keeps its state without reloading the list.
  final _saved = <String, bool>{};

  static bool _isBool(Map<String, dynamic> r) =>
      '${r['valuetype']}' == 'boolean';

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

  /// Saves a switch straight away. Throws when the server refuses, so the switch can go back.
  Future<void> _setBool(String id, bool value) async {
    final repo = ref.read(repositoryProvider);
    await repo.save(Store.catalogSettings, id, {'value': '$value'});
    // The legacy page clears the caches after a save so the new value is used right away.
    await repo.clearCaches();
    _saved[id] = value;
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
          onPressed: () {
            _saved.clear();
            ref.invalidate(recordsProvider);
          },
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
            TableColumn(
              'value',
              'Value',
              flex: 3,
              sortable: false,
              cell: (_, r) => _isBool(r)
                  ? _BoolSwitch(
                      key: ValueKey('${r['id']}'),
                      value: _saved['${r['id']}'] ?? '${r['value']}' == 'true',
                      onChanged: (v) => _setBool('${r['id']}', v),
                    )
                  : Text(
                      displayValue(r['value']),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
          rows: p.hits,
          page: p.page,
          pages: p.pages,
          total: p.total,
          onPage: (n) => setState(() => _page = n),
          // Booleans are switched in the row, with no dialog.
          onTap: (r) => _isBool(r) ? null : _edit(r),
          rowKey: (r) => '${r['id']}',
        ),
      ),
    );
  }
}

/// A switch that saves on change. It shows the new state at once and goes back if the save fails.
class _BoolSwitch extends StatefulWidget {
  const _BoolSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final Future<void> Function(bool value) onChanged;

  @override
  State<_BoolSwitch> createState() => _BoolSwitchState();
}

class _BoolSwitchState extends State<_BoolSwitch> {
  late var _value = widget.value;
  var _busy = false;

  Future<void> _change(bool v) async {
    setState(() {
      _value = v;
      _busy = true;
    });
    try {
      await widget.onChanged(v);
    } catch (e) {
      if (mounted) {
        setState(() => _value = !v);
        showMessage(context, 'Could not save: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Switch(value: _value, onChanged: _busy ? null : _change),
  );
}
