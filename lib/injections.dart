import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:rumbo_mobile_application/navigation/application/destination_search_facade_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/destination_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_remote_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_sample_data_source.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/repositories/destination_repository_impl.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

final serviceLocator = GetIt.instance;

Future<void> setupDependencies() async {
  serviceLocator.registerLazySingleton<ApiConfiguration>(
    () => ApiConfiguration.fromEnvironment(),
  );
  serviceLocator.registerLazySingleton<http.Client>(() => http.Client());

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
