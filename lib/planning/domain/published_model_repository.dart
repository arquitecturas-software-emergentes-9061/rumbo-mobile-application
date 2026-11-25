import 'published_indoor_model.dart';

abstract class PublishedModelRepository {
  Future<List<PublishedSite>> listSites();
  Future<PublishedIndoorModel> synchronize(String siteId);
  void clear();
}

class PublishedModelFailure implements Exception {
  const PublishedModelFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
