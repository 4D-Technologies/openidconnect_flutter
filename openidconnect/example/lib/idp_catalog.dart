import 'package:material_ui/material_ui.dart';

import 'idp_profile.dart';

/// In-memory list of identity providers the example can switch between.
class IdpCatalog extends ChangeNotifier {
  IdpCatalog({List<IdpProfile>? seed})
    : _profiles = List<IdpProfile>.of(seed ?? builtInIdpProfiles) {
    selected = _profiles.first;
  }

  final List<IdpProfile> _profiles;
  late IdpProfile selected;

  List<IdpProfile> get profiles => List<IdpProfile>.unmodifiable(_profiles);

  static IdpCatalog of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IdpCatalogScope>();
    assert(scope != null, 'IdpCatalogScope is missing from the widget tree.');
    return scope!.notifier!;
  }

  void select(IdpProfile profile) {
    selected = profile;
    notifyListeners();
  }

  void add(IdpProfile profile) {
    _profiles.add(profile);
    selected = profile;
    notifyListeners();
  }
}

class IdpCatalogScope extends InheritedNotifier<IdpCatalog> {
  const IdpCatalogScope({
    super.key,
    required IdpCatalog catalog,
    required super.child,
  }) : super(notifier: catalog);
}
