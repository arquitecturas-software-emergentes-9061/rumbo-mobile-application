import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'iam/application/session_facade.dart';
import 'iam/presentation/session_cubit.dart';
import 'package:rumbo_mobile_application/injections.dart' as di;
import 'package:rumbo_mobile_application/shared/infrastructure/navigation/router.dart';
import 'package:rumbo_mobile_application/shared/presentation/utils/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.setupDependencies();
  runApp(const RumboApp());
}

class RumboApp extends StatefulWidget {
  const RumboApp({super.key});
  @override
  State<RumboApp> createState() => _RumboAppState();
}

class _RumboAppState extends State<RumboApp> {
  late final SessionCubit _session;
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    _session = di.serviceLocator<SessionCubit>();
    _router = buildRouter(di.serviceLocator<SessionFacade>());
    _session.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _session,
      child: MaterialApp.router(
        title: 'Rumbo',
        debugShowCheckedModeBanner: false,
        theme: RumboTheme.light,
        routerConfig: _router,
      ),
    );
  }
}


