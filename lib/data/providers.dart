import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../features/auth/auth_controller.dart';
import 'models.dart';
import 'repository.dart';

final repositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(apiClientProvider)),
);

/// Changes with the signed-in user so per-user data reloads.
final sessionKeyProvider = Provider<String>(
  (ref) => ref.watch(authProvider.select((s) => s.userId)),
);

/// One page of records for a store. Invalidate it after a save or delete.
final recordsProvider = FutureProvider.autoDispose
    .family<SearchPage, ({Store store, ListQuery query})>((ref, key) {
      ref.watch(sessionKeyProvider);
      return ref.watch(repositoryProvider).search(key.store, key.query);
    });

/// Every record of a small table (roles, permissions).
final allRecordsProvider = FutureProvider.autoDispose
    .family<List<Json>, ({Store store, String? sort})>((ref, key) {
      ref.watch(sessionKeyProvider);
      return ref.watch(repositoryProvider).all(key.store, sortField: key.sort);
    });

final listOptionsProvider = FutureProvider.family<List<Json>, String>((
  ref,
  listId,
) {
  ref.watch(sessionKeyProvider);
  return ref.watch(repositoryProvider).listOptions(listId);
});

final tablesProvider = FutureProvider.autoDispose<List<String>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(repositoryProvider).tables();
});

final tableFieldsProvider = FutureProvider.autoDispose
    .family<List<FieldDef>, String>((ref, table) {
      ref.watch(sessionKeyProvider);
      return ref.watch(repositoryProvider).fields(table);
    });

final serverInfoProvider = FutureProvider.autoDispose<Json>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(repositoryProvider).serverInfo();
});

final snapshotsProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(repositoryProvider).snapshots();
});

final mappingErrorsProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(repositoryProvider).mappingErrors();
});

final mappingsProvider = FutureProvider.autoDispose<String>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(repositoryProvider).mappings();
});
