import 'package:eme_app_systemmanager/core/ph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/values.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../theme/app_theme.dart';

/// Edit value holder for one field. Keeps the server-facing value and builds the PUT payload.
class FieldValue {
  FieldValue(this.field, Object? initial) {
    final f = field;
    if (f.multilanguage || isLanguageMap(initial)) {
      multilang = isLanguageMap(initial)
          ? {for (final e in (initial as Map).entries) '${e.key}': '${e.value}'}
          : {'en': initial == null ? '' : displayValue(initial)};
      if (multilang!.isEmpty) multilang!['en'] = '';
    } else if (f.isMulti) {
      ids = valueIds(initial);
      _seedNames(initial);
    } else if (f.isList) {
      id = valueIds(initial).firstOrNull;
      _seedNames(initial);
    } else if (f.isDate) {
      date = parseDate(initial);
    } else if (f.isBoolean) {
      flag = '$initial' == 'true';
    } else {
      text = initial == null
          ? ''
          : (initial is String ? initial : displayValue(initial));
    }
  }

  final FieldDef field;
  Map<String, String>? multilang;
  List<String> ids = [];
  String? id;
  DateTime? date;
  bool flag = false;
  String text = '';

  /// Languages removed in the editor; sent as empty strings so the server clears them.
  final removedLanguages = <String>{};

  /// Known display names for list ids.
  final names = <String, String>{};
  var dirty = false;

  void _seedNames(Object? v) {
    final list = v is List ? v : [v];
    for (final e in list) {
      if (e is Map && e['id'] != null) {
        names['${e['id']}'] = localized(e['name']).isNotEmpty
            ? localized(e['name'])
            : '${e['id']}';
      }
    }
  }

  /// Payload entries for the server (multilanguage uses field.lang keys).
  Map<String, Object?> toPayload() {
    final f = field;
    if (multilang != null) {
      return {
        for (final l in removedLanguages) '${f.id}.$l': '',
        for (final e in multilang!.entries) '${f.id}.${e.key}': e.value,
      };
    }
    if (f.isMulti) return {f.id: ids};
    if (f.isList) return {f.id: id ?? ''};
    if (f.isDate) return {f.id: date == null ? '' : toServerDate(date!)};
    if (f.isBoolean) return {f.id: '$flag'};
    return {f.id: text};
  }
}

class FieldInput extends ConsumerStatefulWidget {
  const FieldInput({super.key, required this.value, required this.onChanged});
  final FieldValue value;
  final VoidCallback onChanged;

  @override
  ConsumerState<FieldInput> createState() => _FieldInputState();
}

class _FieldInputState extends ConsumerState<FieldInput> {
  FieldValue get v => widget.value;
  FieldDef get f => v.field;

  void _changed(VoidCallback update) {
    setState(update);
    v.dirty = true;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          f.label(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _input(context),
        if (f.raw['note'] is String &&
            (f.raw['note'] as String).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            f.raw['note'] as String,
            style: TextStyle(fontSize: 11.5, color: context.colors.muted),
          ),
        ],
      ],
    );
  }

  Widget _input(BuildContext context) {
    if (v.multilang != null)
      return _MultiLang(value: v, onChanged: () => _changed(() {}));
    if (f.isBoolean) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(
          value: v.flag,
          onChanged: (b) => _changed(() => v.flag = b),
        ),
      );
    }
    if (f.isDate) return _dateInput(context);
    if (f.isTags) return _TagsInput(value: v, onChanged: () => _changed(() {}));
    if (f.isMulti)
      return _MultiListInput(value: v, onChanged: () => _changed(() {}));
    if (f.isList) return _ListInput(value: v, onChanged: () => _changed(() {}));
    return TextFormField(
      initialValue: v.text,
      minLines: f.isTextArea ? 3 : 1,
      maxLines: f.isTextArea ? 8 : 1,
      keyboardType: f.isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: f.isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
          : null,
      onChanged: (t) => _changed(() => v.text = t),
    );
  }

  Widget _dateInput(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: v.date ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
        if (picked != null) _changed(() => v.date = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: v.date == null
              ? const Icon(Ph.calendarBlank, size: 14)
              : IconButton(
                  icon: const Icon(Ph.x, size: 16),
                  onPressed: () => _changed(() => v.date = null),
                ),
        ),
        child: Text(
          v.date == null ? 'Pick a date' : formatDate(v.date!),
          style: TextStyle(
            fontSize: 14,
            color: v.date == null ? context.colors.muted : null,
          ),
        ),
      ),
    );
  }
}

class _MultiLang extends StatefulWidget {
  const _MultiLang({required this.value, required this.onChanged});
  final FieldValue value;
  final VoidCallback onChanged;

  @override
  State<_MultiLang> createState() => _MultiLangState();
}

class _MultiLangState extends State<_MultiLang> {
  Map<String, String> get map => widget.value.multilang!;

  @override
  Widget build(BuildContext context) {
    final missing = knownLanguages.keys
        .where((k) => !map.containsKey(k))
        .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final lang in map.keys.toList())
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(
                      knownLanguages[lang] ?? lang,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey(lang),
                      initialValue: map[lang],
                      onChanged: (t) {
                        map[lang] = t;
                        widget.onChanged();
                      },
                    ),
                  ),
                  if (lang != 'en')
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Ph.x, size: 16),
                      onPressed: () => setState(() {
                        map.remove(lang);
                        widget.value.removedLanguages.add(lang);
                        widget.onChanged();
                      }),
                    ),
                ],
              ),
            ),
          if (missing.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                tooltip: 'Add language',
                onSelected: (l) => setState(() {
                  map[l] = '';
                  widget.value.removedLanguages.remove(l);
                }),
                itemBuilder: (_) => [
                  for (final l in missing)
                    PopupMenuItem(value: l, child: Text(knownLanguages[l]!)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Ph.translate,
                        size: 13,
                        color: context.scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add language',
                        style: TextStyle(
                          color: context.scheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListInput extends ConsumerWidget {
  const _ListInput({required this.value, required this.onChanged});
  final FieldValue value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(listOptionsProvider(value.field.listId));
    final list = options.value ?? const <Json>[];
    for (final o in list) {
      value.names[o.id] = localized(o['name']).isNotEmpty
          ? localized(o['name'])
          : o.id;
    }
    final entries = {
      for (final o in list) o.id: value.names[o.id]!,
      if (value.id != null && value.id!.isNotEmpty)
        value.id!: value.names[value.id] ?? value.id!,
    };
    return LayoutBuilder(
      builder: (context, box) => DropdownMenu<String>(
        width: box.maxWidth,
        initialSelection: value.id,
        enableFilter: true,
        requestFocusOnTap: true,
        hintText: options.isLoading
            ? 'Loading…'
            : (options.hasError ? 'Could not load options' : 'Choose…'),
        menuHeight: 320,
        dropdownMenuEntries: [
          const DropdownMenuEntry(value: '', label: '— None —'),
          for (final e in entries.entries)
            DropdownMenuEntry(value: e.key, label: e.value),
        ],
        onSelected: (id) {
          value.id = id;
          onChanged();
        },
      ),
    );
  }
}

class _MultiListInput extends ConsumerWidget {
  const _MultiListInput({required this.value, required this.onChanged});
  final FieldValue value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options =
        ref.watch(listOptionsProvider(value.field.listId)).value ??
        const <Json>[];
    for (final o in options) {
      value.names[o.id] = localized(o['name']).isNotEmpty
          ? localized(o['name'])
          : o.id;
    }
    final remaining = options.where((o) => !value.ids.contains(o.id)).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final id in value.ids)
          InputChip(
            label: Text(value.names[id] ?? id),
            onDeleted: () {
              value.ids = [...value.ids]..remove(id);
              onChanged();
            },
          ),
        PopupMenuButton<String>(
          tooltip: 'Add',
          enabled: remaining.isNotEmpty,
          constraints: const BoxConstraints(maxHeight: 360, minWidth: 220),
          onSelected: (id) {
            value.ids = [...value.ids, id];
            onChanged();
          },
          itemBuilder: (_) => [
            for (final o in remaining)
              PopupMenuItem(value: o.id, child: Text(value.names[o.id]!)),
          ],
          child: Chip(
            avatar: Icon(Ph.plus, size: 16, color: context.scheme.primary),
            label: Text(
              remaining.isEmpty && options.isEmpty
                  ? 'No options'
                  : 'Add ${value.field.label().toLowerCase()}',
            ),
          ),
        ),
      ],
    );
  }
}

class _TagsInput extends StatefulWidget {
  const _TagsInput({required this.value, required this.onChanged});
  final FieldValue value;
  final VoidCallback onChanged;

  @override
  State<_TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<_TagsInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String t) {
    final tag = t.trim();
    if (tag.isEmpty || widget.value.ids.contains(tag)) return;
    setState(() => widget.value.ids = [...widget.value.ids, tag]);
    _ctrl.clear();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            hintText: 'Type a tag and press Enter',
          ),
          onSubmitted: _add,
        ),
        if (v.ids.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in v.ids)
                InputChip(
                  label: Text(v.names[t] ?? t),
                  onDeleted: () {
                    setState(() => v.ids = [...v.ids]..remove(t));
                    widget.onChanged();
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
