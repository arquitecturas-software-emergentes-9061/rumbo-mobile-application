import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rumbo_mobile_application/navigation/application/ble_diagnostics_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/ble_diagnostics_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ble_platform_data_provider.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/android_ble_session_configuration.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/permissions/android_ble_permission_service.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/permissions/ble_permission_service.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/repositories/ble_diagnostics_repository_impl.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_bloc.dart';
import 'package:rumbo_mobile_application/navigation/application/destination_search_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/destination_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_remote_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_sample_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/repositories/destination_repository_impl.dart';
import 'iam/application/session_facade.dart';
import 'iam/application/authorized_client.dart';
import 'iam/domain/session_repository.dart';
import 'iam/infrastructure/auth_api.dart';
import 'iam/infrastructure/secure_session_storage.dart';
import 'iam/infrastructure/session_repository_impl.dart';
import 'iam/presentation/session_cubit.dart';
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
  serviceLocator.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  serviceLocator.registerLazySingleton<SecureSessionStorage>(
    () => SecureSessionStorage(serviceLocator()),
  );
  serviceLocator.registerLazySingleton<AuthApi>(
    () => AuthApi(serviceLocator(), serviceLocator()),
  );
  serviceLocator.registerLazySingleton<SessionRepository>(
    () => SessionRepositoryImpl(serviceLocator(), serviceLocator()),
  );
  serviceLocator.registerLazySingleton<SessionFacade>(
    () => SessionFacade(serviceLocator()),
  );
  serviceLocator.registerLazySingleton<AuthorizedClient>(
    () => AuthorizedClient(serviceLocator(), serviceLocator()),
  );
  serviceLocator.registerFactory<SessionCubit>(
    () => SessionCubit(serviceLocator()),
  );

  _registerDestinationSearch();
}

void _registerDestinationSearch() {
  const useSample = bool.fromEnvironment('RUMBO_USE_SAMPLE_DIRECTORY');
  serviceLocator.registerLazySingleton<DestinationDataSource>(
    () => useSample
        ? const DestinationSampleDataSource()
        : DestinationRemoteDataSource(
            client: serviceLocator<http.Client>(),
            configuration: serviceLocator<ApiConfiguration>(),
          ),
  );
  serviceLocator.registerLazySingleton<DestinationRepository>(
    () => DestinationRepositoryImpl(serviceLocator<DestinationDataSource>()),
  );
  serviceLocator.registerLazySingleton<DestinationSearchFacadeService>(
    () => DestinationSearchFacadeService(
      repository: serviceLocator<DestinationRepository>(),
    ),
  );
}
