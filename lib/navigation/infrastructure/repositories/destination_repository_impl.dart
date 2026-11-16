import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/destination_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/destination_data_source.dart';

class DestinationRepositoryImpl implements DestinationRepository {
  const DestinationRepositoryImpl(this._dataSource);

  final DestinationDataSource _dataSource;

  @override
  Future<List<Destination>> fetchDirectory() async {
    final models = await _dataSource.fetchDirectory();
    return models.map((m) => m.toEntity()).toList(growable: false);
  }
}
