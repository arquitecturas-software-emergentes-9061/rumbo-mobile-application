import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:rumbo_mobile_application/navigation/application/ble_diagnostics_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/ble_diagnostics_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ble_platform_data_provider.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/permissions/android_ble_permission_service.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/permissions/ble_permission_service.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/repositories/ble_diagnostics_repository_impl.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_bloc.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

final serviceLocator = GetIt.instance;

Future<void> setupDependencies() async {
  serviceLocator.registerLazySingleton<ApiConfiguration>(
    () => ApiConfiguration.fromEnvironment(),
  );
  serviceLocator.registerLazySingleton<http.Client>(() => http.Client());
  serviceLocator.registerLazySingleton<BlePlatformDataProvider>(
    () => const BlePlatformDataProvider(),
  );
  serviceLocator.registerLazySingleton<
    BleDiagnosticsRepository<AndroidBleSessionConfiguration>
  >(
    () => BleDiagnosticsRepositoryImpl(
      blePlatformDataProvider: serviceLocator<BlePlatformDataProvider>(),
    ),
  );
  serviceLocator.registerLazySingleton<BlePermissionService>(
    () => AndroidBlePermissionService(
      blePlatformDataProvider: serviceLocator<BlePlatformDataProvider>(),
    ),
  );
  serviceLocator.registerLazySingleton<
    BleDiagnosticsFacadeService<AndroidBleSessionConfiguration>
  >(
    () => BleDiagnosticsFacadeService(
      bleDiagnosticsRepository:
          serviceLocator<
            BleDiagnosticsRepository<AndroidBleSessionConfiguration>
          >(),
      blePermissionService: serviceLocator<BlePermissionService>(),
    ),
  );
  serviceLocator.registerFactory<BleDiagnosticsBloc>(
    () => BleDiagnosticsBloc(
      bleDiagnosticsFacadeService:
          serviceLocator<
            BleDiagnosticsFacadeService<AndroidBleSessionConfiguration>
          >(),
    ),
  );
}
