import 'package:material_ui/material_ui.dart';
import 'package:openidconnect_example/choose.dart';
import 'package:openidconnect_example/idp_catalog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final catalog = IdpCatalog();

  @override
  Widget build(BuildContext context) {
    return IdpCatalogScope(
      catalog: catalog,
      child: const MaterialApp(home: ChoosePage()),
    );
  }
}
