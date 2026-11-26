import 'package:eme_app_systemmanager/core/api_client.dart';
import 'package:eme_app_systemmanager/data/models.dart';
import 'package:eme_app_systemmanager/data/repository.dart';
import 'package:eme_app_systemmanager/features/record/field_inputs.dart';
import 'package:eme_app_systemmanager/features/shell/sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListQuery', () {
    test('defaults match everything', () {
      final r = const ListQuery().toRequest('user');
      expect(r['page'], '1');
      expect((r['query'] as Map)['terms'], [
        {'field': 'id', 'operation': 'matches', 'value': '*'},
      ]);
      expect(r.containsKey('usersortby'), isFalse);
    });

    test('text becomes a freeform term and sort is typed by table', () {
      final r = const ListQuery(
        text: ' ann ',
        sortField: 'name',
        sortAscending: false,
      ).toRequest('group');
      expect(((r['query'] as Map)['terms'] as List).single, {
        'field': 'description',
        'operation': 'freeform',
        'value': 'ann',
      });
      expect(r['groupsortby'], 'nameDown');
    });

    test('field terms are sent with the text term', () {
      final r = const ListQuery(
        text: 'x',
        terms: [
          {'field': 'name', 'operation': 'contains', 'value': 'ann'},
        ],
      ).toRequest('user');
      final terms = (r['query'] as Map)['terms'] as List;
      expect(terms.length, 2);
      expect(terms.last, {
        'field': 'name',
        'operation': 'contains',
        'value': 'ann',
      });
    });

    test('terms are part of the equality', () {
      const a = ListQuery(
        terms: [
          {'field': 'a', 'operation': 'contains', 'value': '1'},
        ],
      );
      const b = ListQuery(
        terms: [
          {'field': 'a', 'operation': 'contains', 'value': '1'},
        ],
      );
      expect(a, b);
      expect(a, isNot(const ListQuery()));
    });

    test('has value equality so it can key a provider family', () {
      expect(
        const ListQuery(text: 'a', page: 2),
        const ListQuery(text: 'a', page: 2),
      );
      expect(const ListQuery(page: 1), isNot(const ListQuery(page: 2)));
    });
  });

  group('Store', () {
    test('equal stores are the same provider key', () {
      // Built twice from a runtime value, like the Database tab does on every build.
      final table = ['a', 'b'].join();
      expect(Store.lists(table), Store.lists(table));
      expect(Store.lists(table).hashCode, Store.lists(table).hashCode);
      expect(Store.lists('x'), isNot(Store.lists('y')));
      expect(
        (store: Store.lists(table), query: const ListQuery()),
        (store: Store.lists(table), query: const ListQuery()),
      );
    });
  });

  group('ActionResult', () {
    test('ok statuses', () {
      expect(const ActionResult('ok', {}).ok, isTrue);
      expect(const ActionResult('complete', {}).ok, isTrue);
      expect(const ActionResult('Error', {}).ok, isFalse);
    });

    test('message lists everything but the status', () {
      final r = ActionResult('ok', {
        'response': {'status': 'ok', 'time': '3s'},
      });
      expect(r.message, 'time: 3s');
    });
  });

  group('ApiClient.decodeBody', () {
    test('reads text/json bodies', () {
      expect(
        ApiClient.decodeBody('\n{ "response": {"status":"ok"} }')?['response'],
        {'status': 'ok'},
      );
    });
    test('html error pages are not json', () {
      expect(ApiClient.decodeBody('<!doctype html><html>404</html>'), isNull);
    });
  });

  group('FieldValue payload', () {
    FieldDef def(Map<String, dynamic> raw) => FieldDef(raw);

    test('booleans and text', () {
      final b = FieldValue(
        def({
          'id': 'enabled',
          'datatype': {'id': 'boolean'},
        }),
        'true',
      );
      expect(b.toPayload(), {'enabled': 'true'});
      final t = FieldValue(
        def({
          'id': 'value',
          'datatype': {'id': 'text'},
        }),
        'abc',
      );
      expect(t.toPayload(), {'value': 'abc'});
    });
  });

  group('sections', () {
    test('six settings sections in legacy order', () {
      expect(settingsSections.map((s) => s.id), [
        'server',
        'database',
        'parameters',
        'users',
        'groups',
        'permissions',
      ]);
    });

    test('location lookup', () {
      expect(sectionForLocation('/database')?.id, 'database');
      expect(sectionForLocation('/database/things')?.id, 'database');
      expect(sectionForLocation('/nowhere'), isNull);
    });
  });
}
