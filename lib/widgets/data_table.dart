import 'package:flutter/material.dart';

import '../core/ph.dart';
import '../core/values.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

class TableColumn {
  const TableColumn(
    this.id,
    this.label, {
    this.flex = 1,
    this.cell,
    this.sortable = true,
  });
  final String id;
  final String label;
  final int flex;
  final bool sortable;

  /// Custom cell; defaults to the record's [id] value as text.
  final Widget Function(BuildContext context, Json row)? cell;
}

/// A simple paged table for settings records.
class SettingsTable extends StatelessWidget {
  const SettingsTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onTap,
    this.page = 1,
    this.pages = 1,
    this.total,
    this.onPage,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.rowKey,
  });

  final List<TableColumn> columns;
  final List<Json> rows;
  final void Function(Json row)? onTap;
  final int page;
  final int pages;
  final int? total;
  final void Function(int page)? onPage;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final String Function(Json row)? rowKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: context.scheme.surface,
              border: Border.all(color: c.shellBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: c.subtle,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      for (final col in columns)
                        Expanded(
                          flex: col.flex,
                          child: InkWell(
                            onTap: onSort != null && col.sortable
                                ? () => onSort!(col.id)
                                : null,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    col.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: c.muted,
                                    ),
                                  ),
                                ),
                                if (sortField == col.id)
                                  Icon(
                                    sortAscending ? Ph.caretUp : Ph.caretDown,
                                    size: 12,
                                    color: c.muted,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: c.shellBorder),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return InkWell(
                        key: rowKey == null ? null : ValueKey(rowKey!(row)),
                        onTap: onTap == null ? null : () => onTap!(row),
                        hoverColor: c.subtle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              for (final col in columns)
                                Expanded(
                                  flex: col.flex,
                                  child: col.cell != null
                                      ? col.cell!(context, row)
                                      : Text(
                                          displayValue(row[col.id]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (pages > 1 || total != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                if (total != null)
                  Text(
                    '$total records',
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                const Spacer(),
                if (pages > 1) ...[
                  IconButton(
                    onPressed: page > 1 ? () => onPage?.call(page - 1) : null,
                    icon: const Icon(Ph.caretLeft, size: 16),
                  ),
                  Text('$page / $pages', style: const TextStyle(fontSize: 13)),
                  IconButton(
                    onPressed: page < pages
                        ? () => onPage?.call(page + 1)
                        : null,
                    icon: const Icon(Ph.caretRight, size: 16),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
