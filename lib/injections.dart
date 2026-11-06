import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

final serviceLocator = GetIt.instance;

Future<void> setupDependencies() async {
  serviceLocator.registerLazySingleton<ApiConfiguration>(
    () => ApiConfiguration.fromEnvironment(),
  );
  serviceLocator.registerLazySingleton<http.Client>(() => http.Client());
}
