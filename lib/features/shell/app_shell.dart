import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ph.dart';
import '../../core/settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../auth/auth_controller.dart';
import 'sections.dart';

class SidebarOpen extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final sidebarOpenProvider = NotifierProvider<SidebarOpen, bool>(
  SidebarOpen.new,
);

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final open = ref.watch(sidebarOpenProvider) && wide;
    final current = sectionForLocation(location);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
            ref.read(sidebarOpenProvider.notifier).toggle(),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            ref.read(sidebarOpenProvider.notifier).toggle(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          drawer: wide
              ? null
              : Drawer(
                  width: 280,
                  child: _Sidebar(current: current, inDrawer: true),
                ),
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: open ? 248 : 0,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 248,
                    maxWidth: 248,
                    child: _Sidebar(current: current),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(current: current, wide: wide),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.current, required this.wide});
  final SettingsSection? current;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.shell,
        border: Border(bottom: BorderSide(color: c.shellBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu (⌘B)',
            icon: const Icon(Ph.list, size: 20),
            onPressed: () => wide
                ? ref.read(sidebarOpenProvider.notifier).toggle()
                : Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 6),
          Text(
            current?.label ?? 'Settings',
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.current, this.inDrawer = false});
  final SettingsSection? current;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(authProvider).user;
    final dark = ref.watch(settingsProvider).themeMode == ThemeMode.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(right: BorderSide(color: c.shellBorder)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: BrandMark(size: 16),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'SETTINGS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: c.muted,
                ),
              ),
            ),
            for (final s in settingsSections)
              _Item(
                section: s,
                active: s.id == current?.id,
                onTap: () {
                  if (inDrawer) Navigator.of(context).pop();
                  context.go(s.path);
                },
              ),
            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'SWITCH MANAGERS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: c.muted,
                ),
              ),
            ),
            for (final m in _managers)
              _ManagerLink(manager: m, active: m.label == 'System Manager'),
            const SizedBox(height: 6),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(dark ? Ph.sun : Ph.moonStars, size: 18),
              title: Text(dark ? 'Light theme' : 'Dark theme'),
              onTap: () => ref.read(settingsProvider.notifier).toggleTheme(),
            ),
            if (user != null)
              ListTile(
                dense: true,
                leading: UserAvatar(
                  name: user.displayName,
                  imageUrl: user.portrait,
                  size: 30,
                ),
                title: Text(user.displayName, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  user.email ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Ph.signOut, size: 18),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.section,
    required this.active,
    required this.onTap,
  });
  final SettingsSection section;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = context.scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: active ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: c.subtle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  active ? section.activeIcon : section.icon,
                  size: 18,
                  color: active ? accent : c.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? accent : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Manager {
  const _Manager(this.label, this.icon, this.href);
  final String label;
  final IconData icon;
  final String href;
}

// All links point to '#' for now.
const _managers = [
  _Manager('System Manager', Ph.gear, '#'),
  _Manager('Data Manager', Ph.database, '#'),
  _Manager('Job Manager', Ph.listChecks, '#'),
];

class _ManagerLink extends StatelessWidget {
  const _ManagerLink({required this.manager, required this.active});
  final _Manager manager;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = context.scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: active ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: c.subtle,
          onTap: active ? null : () {}, // href '#': no navigation yet
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(manager.icon, size: 18, color: active ? accent : c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    manager.label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? accent : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
