import 'option.dart';

enum OptionGroupKind { variant, size, remove, add }

enum SelectionType { single, multi }

OptionGroupKind _kindFromString(String? v) {
  switch (v) {
    case 'variant':
      return OptionGroupKind.variant;
    case 'size':
      return OptionGroupKind.size;
    case 'remove':
      return OptionGroupKind.remove;
    case 'add':
      return OptionGroupKind.add;
    default:
      return OptionGroupKind.size;
  }
}

SelectionType _selFromString(String? v) => v == 'multi' ? SelectionType.multi : SelectionType.single;

class OptionGroup {
  final int id;
  final String nameAr;
  final String? nameEn;
  final OptionGroupKind kind;
  final SelectionType selectionType;
  final bool isRequired;
  final int sortOrder;
  final List<Option> options;

  const OptionGroup({
    required this.id,
    required this.nameAr,
    this.nameEn,
    required this.kind,
    required this.selectionType,
    required this.isRequired,
    required this.sortOrder,
    required this.options,
  });

  factory OptionGroup.fromJson(Map<String, dynamic> j) => OptionGroup(
        id: j['id'] as int,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String?,
        kind: _kindFromString(j['kind'] as String?),
        selectionType: _selFromString(j['selection_type'] as String?),
        isRequired: (j['is_required'] as bool?) ?? false,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        options: ((j['options'] as List?) ?? const [])
            .map((e) => Option.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}
