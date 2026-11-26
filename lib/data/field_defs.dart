import 'models.dart';

/// Static field definitions for forms whose layout is fixed (the legacy views `useredit`, `groupgeneral`, ...).
FieldDef textField(String id, String label, {bool area = false}) => FieldDef({
  'id': id,
  'name': {'en': label},
  'datatype': {'id': 'text'},
  if (area) 'rendertype': {'id': 'textarea'},
});

FieldDef boolField(String id, String label) => FieldDef({
  'id': id,
  'name': {'en': label},
  'datatype': {'id': 'boolean'},
});

FieldDef listField(String id, String label, String listId) => FieldDef({
  'id': id,
  'name': {'en': label},
  'datatype': {'id': 'list'},
  'listid': listId,
});
