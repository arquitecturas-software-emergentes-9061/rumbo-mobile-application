import '../domain/published_indoor_model.dart';
import '../domain/published_model_repository.dart';

/// Only a successful server revalidation may make a model available to the UI.
class PublishedModelSyncService {
  const PublishedModelSyncService(this.repository);
  final PublishedModelRepository repository;
  Future<List<PublishedSite>> listSites() => repository.listSites();
  Future<PublishedIndoorModel> synchronize(String siteId) =>
      repository.synchronize(siteId);
  void clear() => repository.clear();
}
