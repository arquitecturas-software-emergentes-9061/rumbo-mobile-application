import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/published_model_sync_service.dart';
import '../domain/published_indoor_model.dart';
import '../domain/published_model_repository.dart';

enum ModelSyncPhase { loadingSites, syncing, ready, empty, error }

class ModelSyncState {
  ModelSyncState({
    required this.phase,
    List<PublishedSite> sites = const [],
    this.siteId,
    this.model,
    this.message,
    this.checkedAt,
    this.versionChanged = false,
  }) : sites = List.unmodifiable(sites);
  final ModelSyncPhase phase;
  final List<PublishedSite> sites;
  final String? siteId, message;
  final PublishedIndoorModel? model;
  final DateTime? checkedAt;
  final bool versionChanged;
}

class PublishedModelSyncCubit extends Cubit<ModelSyncState> {
  PublishedModelSyncCubit(this.service)
    : super(ModelSyncState(phase: ModelSyncPhase.loadingSites));
  final PublishedModelSyncService service;
  List<PublishedSite> _sites = const [];
  String? _site;
  final _versions = <String, String>{};
  int _request = 0;

  Future<void> loadSites() async {
    final request = ++_request;
    emit(ModelSyncState(phase: ModelSyncPhase.loadingSites));
    try {
      final sites = await service.listSites();
      if (!_current(request)) return;
      _sites = sites;
      if (sites.isEmpty) {
        _site = null;
        emit(ModelSyncState(phase: ModelSyncPhase.empty));
        return;
      }
      await selectSite(
        sites.any((site) => site.id == _site) ? _site! : sites.first.id,
      );
    } catch (error) {
      if (_current(request)) _failed(error);
    }
  }

  Future<void> refresh() => _site == null ? loadSites() : selectSite(_site!);

  Future<void> selectSite(String siteId) async {
    if (!_sites.any((site) => site.id == siteId)) return;
    _site = siteId;
    final request = ++_request;
    emit(
      ModelSyncState(
        phase: ModelSyncPhase.syncing,
        sites: _sites,
        siteId: siteId,
      ),
    );
    try {
      final model = await service.synchronize(siteId);
      if (!_current(request)) return;
      final previous = _versions[siteId];
      _versions[siteId] = model.versionId;
      emit(
        ModelSyncState(
          phase: ModelSyncPhase.ready,
          sites: _sites,
          siteId: siteId,
          model: model,
          checkedAt: DateTime.now(),
          versionChanged: previous != null && previous != model.versionId,
        ),
      );
    } catch (error) {
      if (_current(request)) _failed(error);
    }
  }

  bool _current(int request) => !isClosed && request == _request;
  void _failed(Object error) => emit(
    ModelSyncState(
      phase: ModelSyncPhase.error,
      sites: _sites,
      siteId: _site,
      message: error is PublishedModelFailure
          ? error.message
          : 'No se pudo comprobar el mapa. Sincroniza de nuevo.',
    ),
  );
}
