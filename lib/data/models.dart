import '../core/values.dart';

typedef Json = Map<String, dynamic>;

/// Field definition from `settings/datamanager/fields/listfields`.
class FieldDef {
  FieldDef(this.raw);
  final Json raw;

  String get id => '${raw['id']}';
  String label([String lang = 'en']) {
    final n = localized(raw['name'], lang);
    return n.isNotEmpty ? n : id;
  }

  String get datatype => '${(raw['datatype'] as Map?)?['id'] ?? 'text'}';
  String? get rendertype => (raw['rendertype'] as Map?)?['id'] as String?;

  /// EME convention: a list field without listid uses its own id as the list.
  String get listId => (raw['listid'] as String?)?.isNotEmpty == true
      ? raw['listid'] as String
      : id;
  bool get editable => raw['editable'] != 'false';
  bool get internal => raw['internalfield'] == 'true';
  bool get multilanguage =>
      raw['multilanguage'] == 'true' || datatype == 'multilanguage';
  bool get isList => datatype == 'list';
  bool get isAssetRef => isList && listId == 'asset';
  bool get isCategory =>
      isList && (listId == 'category' || rendertype == 'category');
  bool get isMulti =>
      raw['multiple'] == 'true' ||
      const {'multiselect', 'entity', 'tageditor'}.contains(rendertype) ||
      datatype == 'multi';
  bool get isTags => rendertype == 'tageditor' || id == 'keywords';
  bool get isDate => datatype == 'date' || rendertype == 'date';
  bool get isBoolean => datatype == 'boolean';
  bool get isNumber =>
      const {'number', 'double', 'long', 'integer'}.contains(datatype);
  bool get isTextArea => rendertype == 'textarea' || rendertype == 'html';
  bool get isComplex =>
      const {'nested', 'objectarray', 'object', 'json'}.contains(datatype);
}

/// Record helpers shared by assets and entities.
extension RecordX on Json {
  String get id => '${this['id']}';

  String title([String lang = 'en']) {
    for (final k in ['name', 'displayname', 'headline', 'title']) {
      final v = localized(this[k], lang);
      if (v.isNotEmpty) return v;
    }
    return id;
  }
}
