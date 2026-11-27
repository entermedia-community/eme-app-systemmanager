import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ph.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../theme/app_theme.dart';
import '../../core/api_client.dart';
import '../../widgets/common.dart';
import '../../widgets/section_page.dart';

/// Server status and maintenance actions (the legacy "Server" settings page).
class ServerPage extends ConsumerWidget {
  const ServerPage({super.key});

  Future<void> _act(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required Future<ActionResult> Function(SettingsRepository repo) run,
    required String done,
    String action = 'Continue',
    bool ask = true,
  }) async {
    // Frequent, safe actions (clear cache, reindex) run straight away.
    if (ask) {
      final ok = await confirm(
        context,
        title: title,
        message: message,
        action: action,
      );
      if (!ok || !context.mounted) return;
    }
    await runServerAction(context, () async {
      final r = await run(ref.read(repositoryProvider));
      if (!r.ok)
        throw ApiException(
          'The server answered "${r.status}"${r.message.isEmpty ? '' : ': ${r.message}'}',
        );
      return r.message;
    }, success: done);
    ref.invalidate(serverInfoProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(serverInfoProvider);
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        info.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(serverInfoProvider),
          ),
          data: (i) => _Panel(
            title: 'Server status',
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _Fact('Node ID', '${i['nodeid']}'),
                _Fact('Cluster ID', '${i['clusterid']}'),
                _Fact('Catalog ID', '${i['catalogid']}'),
                _Fact(
                  'Search logs',
                  i['logallsearches'] == true ? 'On' : 'Off',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Maintenance',
          child: _Stack(
            children: [
              _ActionButton(
                icon: Ph.broom,
                label: 'Clear cached data',
                hint: 'Safe. Server caches are rebuilt on demand.',
                tone: _Tone.tonal,
                onTap: () => _act(
                  context,
                  ref,
                  title: 'Clear cached data?',
                  message: 'Server caches are rebuilt on demand.',
                  run: (r) => r.clearCaches(),
                  done: 'Caches cleared',
                  ask: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Data management',
          child: _Stack(
            children: [
              _ActionButton(
                icon: Ph.arrowsClockwise,
                label: 'Reindex',
                hint: 'Full rebuild of the search index. Can take a while.',
                tone: _Tone.tonal,
                onTap: () => _act(
                  context,
                  ref,
                  title: 'Full reindex?',
                  message: 'Rebuilds the search index for the whole catalog. This can take a while.',
                  run: (r) => r.reindexAll(),
                  done: 'Reindexed',
                  ask: false,
                ),
              ),
              _ActionButton(
                icon: Ph.warning,
                label: 'View mapping conflicts',
                hint: "If the reindex fails, conflicts may be found here",
                tone: _Tone.neutral,
                onTap: () async {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const _MappingErrorsDialog(),
                  );
                },
              ),
              _ActionButton(
                icon: Ph.fileText,
                label: 'View Elastic mappings',
                hint: 'The full elastic database mappings',
                tone: _Tone.neutral,
                onTap: () async {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const _MappingsDialog(),
                  );
                },
              ),
              _ActionButton(
                icon: Ph.listChecks,
                label: 'Reset lists to defaults',
                hint: 'Merges lists loaded from the installation with your own lists.',
                tone: _Tone.danger,
                onTap: () => _act(
                  context,
                  ref,
                  title: 'Reset lists to defaults?',
                  message: 'Lists loaded from the installation are merged with your own lists.',
                  run: (r) => r.reloadLists(),
                  done: 'Lists reloaded',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Database snapshots',
          child: _Stack(
            children: [
              _ActionButton(
                icon: Ph.camera,
                label: 'View snapshots',
                hint: 'Snapshots store and restore the database state.',
                tone: _Tone.tonal,
                onTap: () async {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const _SnapshotsDialog(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Data entities',
          child: _Stack(
            children: [
              _ActionButton(
                icon: Ph.floppyDisk,
                label: 'Save all modules',
                hint: 'Writes every module to disk. Reindex afterwards.',
                tone: _Tone.tonal,
                onTap: () => _act(
                  context,
                  ref,
                  title: 'Save all modules?',
                  message:
                      'Saves every data entity module. Reindex afterwards.',
                  run: (r) => r.saveAllModules(),
                  done: 'Saved all modules',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Advanced',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: _ActionButton(
                  icon: Ph.magnifyingGlass,
                  label: info.value?['logallsearches'] == true
                      ? 'Search logs: on'
                      : 'Search logs: off',
                  hint: 'Toggle logging of every search.',
                  tone: _Tone.tonal,
                  onTap: () => _act(
                    context,
                    ref,
                    title: 'Toggle search logging?',
                    message: 'Turns logging of every search on or off.',
                    run: (r) => r.toggleSearchLogs(),
                    done: 'Search logging changed',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 300,
                child: _ActionButton(
                  icon: Ph.crown,
                  label: 'Change Elasticsearch master',
                  hint: 'Forces this cluster to be master, then reindexes.',
                  tone: _Tone.tonal,
                  onTap: () => _act(
                    context,
                    ref,
                    title: 'Make this node the master?',
                    message: 'Forces this cluster to become the master and reindexes everything.',
                    run: (r) => r.makeMaster(),
                    done: 'Master changed',
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          'Actions run on the server you are signed in to.',
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border.all(color: c.shellBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: context.colors.muted)),
      const SizedBox(height: 2),
      SelectableText(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

enum _Tone { primary, neutral, tonal, danger }

/// Buttons stacked vertically at a fixed readable width.
class _Stack extends StatelessWidget {
  const _Stack({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    required this.hint,
  });
  final IconData icon;
  final String label;
  final String hint;
  final _Tone tone;
  final Future<void> Function() onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  var _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tone = widget.tone;
    final icon = widget.icon;
    final label = widget.label;
    final hint = widget.hint;
    final (bg, fg) = switch (tone) {
      _Tone.primary => (scheme.primary, scheme.onPrimary),
      // Grayish: the common, safe action.
      _Tone.neutral => (
        scheme.onSurface.withValues(alpha: 0.12),
        scheme.onSurface,
      ),
      _Tone.tonal => (scheme.primary.withValues(alpha: 0.14), scheme.onSurface),
      // Slight red tint.
      _Tone.danger => (scheme.error.withValues(alpha: 0.14), scheme.error),
    };
    return FilledButton(
      onPressed: _busy ? null : _run,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg,
        disabledForegroundColor: fg,
        elevation: 0,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: _busy
                ? CircularProgressIndicator(strokeWidth: 2.2, color: fg)
                : Icon(icon, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: fg.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MappingErrorsDialog extends ConsumerWidget {
  const _MappingErrorsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Mapping conflicts'),
      content: SizedBox(
        width: 640,
        child: ref
            .watch(mappingErrorsProvider)
            .when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'),
              data: (list) => list.isEmpty
                  ? const Text('No errors detected')
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final e in list)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e['searchtype']}.${e['field']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SelectableText(
                                    '${e['error']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _MappingsDialog extends ConsumerWidget {
  const _MappingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Elastic mappings'),
      content: SizedBox(
        width: 720,
        height: 480,
        child: ref
            .watch(mappingsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (text) => SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SnapshotsDialog extends ConsumerWidget {
  const _SnapshotsDialog();

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final ok = await confirm(
      context,
      title: 'Restore $name?',
      message: 'Replaces the current database with this snapshot.',
      action: 'Restore',
    );
    if (!ok || !context.mounted) return;
    await runServerAction(
      context,
      () async =>
          (await ref.read(repositoryProvider).restoreSnapshot(name)).message,
      success: 'Snapshot restored',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snaps = ref.watch(snapshotsProvider);
    return AlertDialog(
      title: const Text('Database snapshots'),
      content: SizedBox(
        width: 560,
        child: snaps.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SelectableText('$e'),
          data: (list) => list.isEmpty
              ? const Text('No snapshots found')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in list)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${s['name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${s['shards']} sections',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () =>
                                    _restore(context, ref, '${s['name']}'),
                                child: const Text('Restore'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await runServerAction(
              context,
              () async =>
                  (await ref.read(repositoryProvider).createSnapshot()).message,
              success: 'Snapshot created',
            );
            ref.invalidate(snapshotsProvider);
          },
          child: const Text('Create new'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
