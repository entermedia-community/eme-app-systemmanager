import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../features/record/field_inputs.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Generic edit/create form over [FieldDef]s. [onSave] gets the server payload;
/// [onDelete] is only offered for an existing record.
Future<bool> showRecordDialog(
  BuildContext context, {
  required String title,
  required List<FieldDef> fields,
  Json? initial,
  required Future<void> Function(Map<String, Object?> payload) onSave,
  Future<void> Function()? onDelete,
  String deleteMessage = 'This cannot be undone.',
  List<Widget> extra = const [],
  List<FieldDef> advancedFields = const [],
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => RecordDialog(
      title: title,
      fields: fields,
      initial: initial,
      onSave: onSave,
      onDelete: onDelete,
      deleteMessage: deleteMessage,
      extra: extra,
      advancedFields: advancedFields,
    ),
  );
  return saved ?? false;
}

class RecordDialog extends ConsumerStatefulWidget {
  const RecordDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.initial,
    this.onDelete,
    this.deleteMessage = 'This cannot be undone.',
    this.extra = const [],
    this.advancedFields = const [],
  });
  final String title;
  final List<FieldDef> fields;

  /// Fields tucked under a collapsed "Advanced Settings" section.
  final List<FieldDef> advancedFields;
  final Json? initial;
  final Future<void> Function(Map<String, Object?> payload) onSave;
  final Future<void> Function()? onDelete;
  final String deleteMessage;

  /// Extra widgets shown under the form (e.g. group membership).
  final List<Widget> extra;

  @override
  ConsumerState<RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends ConsumerState<RecordDialog> {
  late final List<FieldValue> _values = [
    for (final f in [...widget.fields, ...widget.advancedFields])
      FieldValue(f, widget.initial?[f.id]),
  ];
  var _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final payload = <String, Object?>{};
    for (final v in _values) {
      if (v.field.editable && v.dirty) payload.addAll(v.toPayload());
    }
    await widget.onSave(payload);
  });

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete ${widget.title}?',
      message: widget.deleteMessage,
    );
    if (ok) await _run(widget.onDelete!);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in _values.take(widget.fields.length))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FieldInput(value: v, onChanged: () => setState(() {})),
                ),
              if (widget.advancedFields.isNotEmpty)
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 4),
                    title: const Text(
                      'Advanced Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    children: [
                      for (final v in _values.skip(widget.fields.length))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FieldInput(
                            value: v,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                    ],
                  ),
                ),
              ...widget.extra,
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.scheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: context.scheme.error),
            child: const Text('Delete'),
          ),
        const Spacer(),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
