import 'package:flutter/widgets.dart';

import '../../core/ph.dart';

/// One entry of the Settings sidebar (same order and names as the legacy `settingsmenu`).
class SettingsSection {
  const SettingsSection(
    this.id,
    this.label,
    this.path,
    this.icon,
    this.activeIcon,
  );
  final String id;
  final String label;
  final String path;
  final IconData icon;
  final IconData activeIcon;
}

const settingsSections = [
  SettingsSection(
    'server',
    'Server',
    '/server',
    Ph.hardDrives,
    PhFill.hardDrives,
  ),
  SettingsSection(
    'database',
    'Database',
    '/database',
    Ph.database,
    PhFill.database,
  ),
  SettingsSection(
    'parameters',
    'Catalog Parameters',
    '/parameters',
    Ph.sliders,
    PhFill.sliders,
  ),
  SettingsSection('users', 'Users', '/users', Ph.user, PhFill.user),
  SettingsSection('groups', 'Groups', '/groups', Ph.users, PhFill.users),
  SettingsSection(
    'permissions',
    'Site Permissions',
    '/permissions',
    Ph.shieldCheck,
    PhFill.shieldCheck,
  ),
];

SettingsSection? sectionForLocation(String location) {
  for (final s in settingsSections) {
    if (location == s.path || location.startsWith('${s.path}/')) return s;
  }
  return null;
}
