import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ph.dart';
import '../../core/values.dart';
import '../../data/field_defs.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/data_table.dart';
import '../../widgets/record_dialog.dart';
import '../../widgets/section_page.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  var _text = '';
  var _page = 1;
  String? _sort = 'firstName';
  var _asc = true;

  ({Store store, ListQuery query}) get _key => (
    store: Store.users,
    query: ListQuery(
      text: _text,
      page: _page,
      hitsPerPage: 15,
      sortField: _sort,
      sortAscending: _asc,
    ),
  );

  // Same fields as the legacy `useredit` view.
  static final _fields = [
    textField('firstName', 'First name'),
    textField('lastName', 'Last name'),
    textField('email', 'Email'),
    textField('screenname', 'Screen name'),
    textField('phone', 'Phone'),
    textField('country', 'Country'),
    textField('address1', 'Address'),
    textField('address2', 'Address 2'),
    textField('city', 'City'),
    textField('state_province', 'State / province'),
    textField('postal_code', 'Postal code'),
    textField('notes', 'Notes', area: true),
    boolField('enabled', 'Enabled'),
  ];

  Future<void> _open([Json? row]) async {
    final repo = ref.read(repositoryProvider);
    final id = row == null ? null : '${row['id']}';
    final saved = await showRecordDialog(
      context,
      title: row == null ? 'New user' : id!,
      fields: _fields,
      initial: row,
      onSave: (payload) async {
        await repo.save(Store.users, id, payload);
      },
      onDelete: id == null ? null : () => repo.delete(Store.users, id),
      deleteMessage: 'The user and their sign-in keys are removed.',
      tabLabels: const ['Profile', 'Access'],
      extraOnSecondTab: true,
      extra: [if (id != null) _UserAccess(userId: id)],
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
          label: const Text('New user'),
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
            const TableColumn('id', 'User', flex: 2),
            const TableColumn('firstName', 'First name', flex: 2),
            const TableColumn('lastName', 'Last name', flex: 2),
            const TableColumn('email', 'Email', flex: 3),
            TableColumn(
              'enabled',
              'Status',
              flex: 1,
              sortable: false,
              cell: (c, r) => '${r['enabled']}' == 'false'
                  ? Pill('Disabled', color: c.scheme.error)
                  : const Text('Active'),
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
          onTap: _open,
          rowKey: (r) => '${r['id']}',
        ),
      ),
    );
  }
}

/// Role and group membership of one user.
class _UserAccess extends ConsumerStatefulWidget {
  const _UserAccess({required this.userId});
  final String userId;

  @override
  ConsumerState<_UserAccess> createState() => _UserAccessState();
}

class _UserAccessState extends ConsumerState<_UserAccess> {
  String? _role;
  String? _group;
  String? _message;

  Future<void> _do(Future<void> Function() action, String done) async {
    setState(() => _message = null);
    try {
      await action();
      if (mounted) setState(() => _message = done);
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles =
        ref
            .watch(allRecordsProvider((store: Store.roles, sort: 'name')))
            .value ??
        const [];
    final groups =
        ref
            .watch(allRecordsProvider((store: Store.groups, sort: 'name')))
            .value ??
        const [];
    final repo = ref.read(repositoryProvider);
    String label(Json r) => displayValue(r['name']).isEmpty
        ? '${r['id']}'
        : displayValue(r['name']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Access', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  isDense: true,
                ),
                items: [
                  for (final r in roles)
                    DropdownMenuItem(
                      value: '${r['id']}',
                      child: Text(label(r)),
                    ),
                ],
                onChanged: (v) => setState(() => _role = v),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _role == null
                  ? null
                  : () => _do(() async {
                      await repo.save(
                        const Store.lists('userprofile'),
                        widget.userId,
                        {'settingsrole': _role},
                      );
                    }, 'Role saved'),
              child: const Text('Set role'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _group,
                decoration: const InputDecoration(
                  labelText: 'Group',
                  isDense: true,
                ),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(
                      value: '${g['id']}',
                      child: Text(label(g)),
                    ),
                ],
                onChanged: (v) => setState(() => _group = v),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _group == null
                  ? null
                  : () => _do(
                      () => repo.addUserToGroup(widget.userId, _group!),
                      'Added to group',
                    ),
              child: const Text('Add'),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: _group == null
                  ? null
                  : () => _do(
                      () => repo.removeUserFromGroup(widget.userId, _group!),
                      'Removed from group',
                    ),
              child: const Text('Remove'),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              style: TextStyle(color: context.colors.muted, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}
