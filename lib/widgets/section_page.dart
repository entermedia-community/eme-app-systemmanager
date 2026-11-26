import 'package:flutter/material.dart';

import '../core/ph.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Standard page frame: padded body, optional search box and action buttons above the content.
class SectionPage extends StatelessWidget {
  const SectionPage({
    super.key,
    required this.child,
    this.search,
    this.actions = const [],
    this.subtitle,
  });
  final Widget child;
  final String? subtitle;
  final List<Widget> actions;

  /// Called with the text when the user submits the search box.
  final void Function(String text)? search;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                subtitle!,
                style: TextStyle(color: context.colors.muted),
              ),
            ),
          if (search != null || actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  if (search != null)
                    SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          isDense: true,
                          prefixIcon: Icon(Ph.magnifyingGlass, size: 16),
                        ),
                        onSubmitted: search,
                      ),
                    ),
                  const Spacer(),
                  for (final a in actions)
                    Padding(padding: const EdgeInsets.only(left: 8), child: a),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Runs a server action and shows what the server said (or the error), never a made-up success.
Future<void> runServerAction(
  BuildContext context,
  Future<String> Function() action, {
  required String success,
}) async {
  try {
    final detail = await action();
    if (context.mounted) {
      showMessage(context, detail.isEmpty ? success : '$success ($detail)');
    }
  } catch (e) {
    if (context.mounted) showMessage(context, '$e', error: true);
  }
}
