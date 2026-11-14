import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/injections.dart' as di;
import 'package:rumbo_mobile_application/shared/infrastructure/navigation/router.dart';
import 'package:rumbo_mobile_application/shared/presentation/utils/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.setupDependencies();
  runApp(const RumboApp());
}

class RumboApp extends StatelessWidget {
  const RumboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rumbo',
      debugShowCheckedModeBanner: false,
      theme: RumboTheme.light,
      routerConfig: buildRouter(),
    );
  }
}


