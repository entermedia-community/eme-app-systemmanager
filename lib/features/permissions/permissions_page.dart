import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ph.dart';
import '../../core/values.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/section_page.dart';

/// Site permissions: which `permissionsapp` entries each `settingsrole` has.
class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key});

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  String? _roleId;
  Set<String>? _selected;
  var _busy = false;

  String _label(Json r) =>
      displayValue(r['name']).isEmpty ? '${r['id']}' : displayValue(r['name']);

  void _select(Json role) {
    setState(() {
      _roleId = '${role['id']}';
      _selected = valueIds(role['permissions']).toSet();
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await runServerAction(context, () async {
      final repo = ref.read(repositoryProvider);
      await repo.save(Store.roles, _roleId, {
        'permissions': _selected!.toList(),
      });
      return '';
    }, success: 'Permissions saved');
    if (mounted) setState(() => _busy = false);
    ref.invalidate(allRecordsProvider);
  }

  Future<void> _add() async {
    final name = await _askName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref.read(repositoryProvider).save(Store.roles, null, {
        'name': name.trim(),
      });
      ref.invalidate(allRecordsProvider);
      setState(() {
        _roleId = id;
        _selected = {};
      });
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete role?',
      message: 'Users with this role lose its permissions.',
    );
    if (!ok) return;
    try {
      await ref.read(repositoryProvider).delete(Store.roles, _roleId!);
      ref.invalidate(allRecordsProvider);
      setState(() {
        _roleId = null;
        _selected = null;
      });
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(
      allRecordsProvider((store: Store.roles, sort: 'name')),
    );
    final perms = ref.watch(
      allRecordsProvider((store: Store.permissions, sort: 'ordering')),
    );
    return SectionPage(
      subtitle: 'Choose a role, then tick what it may do.',
      actions: [
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Ph.plus, size: 16),
          label: const Text('New role'),
        ),
        if (_roleId != null)
          OutlinedButton.icon(
            onPressed: _delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.scheme.error,
            ),
            icon: const Icon(Ph.trash, size: 16),
            label: const Text('Delete role'),
          ),
        if (_roleId != null)
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
      ],
      child: roles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(allRecordsProvider),
        ),
        data: (roleList) {
          final role = roleList.firstWhereOrNull(
            (r) => '${r['id']}' == _roleId,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 240,
                child: ListView(
                  children: [
                    for (final r in roleList)
                      ListTile(
                        dense: true,
                        selected: '${r['id']}' == _roleId,
                        title: Text(_label(r)),
                        onTap: () => _select(r),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 24),
              Expanded(
                child: role == null || _selected == null
                    ? const EmptyState(
                        icon: Ph.shieldCheck,
                        title: 'Pick a role',
                      )
                    : perms.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => ErrorState(error: e),
                        data: (permList) => _PermissionList(
                          permissions: permList,
                          selected: _selected!,
                          onChanged: () => setState(() {}),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PermissionList extends StatelessWidget {
  const _PermissionList({
    required this.permissions,
    required this.selected,
    required this.onChanged,
  });
  final List<Json> permissions;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final groups = groupBy(
      permissions,
      (Json p) => displayValue(p['permissiontype']).isEmpty
          ? 'other'
          : displayValue(p['permissiontype']),
    );
    return ListView(
      children: [
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              e.key.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: context.colors.muted,
              ),
            ),
          ),
          for (final p in e.value)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains('${p['id']}'),
              title: Text(
                displayValue(p['name']).isEmpty
                    ? '${p['id']}'
                    : displayValue(p['name']),
              ),
              subtitle: displayValue(p['caption']).isEmpty
                  ? null
                  : Text(displayValue(p['caption'])),
              onChanged: (v) {
                v == true
                    ? selected.add('${p['id']}')
                    : selected.remove('${p['id']}');
                onChanged();
              },
            ),
        ],
      ],
    );
  }
}

Future<String?> _askName(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('New role'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
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
}
