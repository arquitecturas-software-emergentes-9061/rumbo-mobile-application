import 'package:rumbo_mobile_application/navigation/infrastructure/models/destination_model.dart';

abstract interface class DestinationDataSource {
  Future<List<DestinationModel>> fetchDirectory();
}
