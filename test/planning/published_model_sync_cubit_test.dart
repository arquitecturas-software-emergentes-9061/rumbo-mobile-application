import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/planning/application/published_model_sync_service.dart';
import 'package:rumbo_mobile_application/planning/domain/published_indoor_model.dart';
import 'package:rumbo_mobile_application/planning/domain/published_model_repository.dart';
import 'package:rumbo_mobile_application/planning/presentation/published_model_sync_cubit.dart';
import 'published_model_fixture.dart';

class TestModelRepository implements PublishedModelRepository {
  List<PublishedSite> sites = const [
    PublishedSite(id: 'site', name: 'Sede Central'),
  ];
  Future<PublishedIndoorModel> Function(String) read = (site) async =>
      publishedModel(site: site);
  @override
  Future<List<PublishedSite>> listSites() async => sites;
  @override
  Future<PublishedIndoorModel> synchronize(String site) => read(site);
  @override
  void clear() {}
}

void main() {
  late TestModelRepository repo;
  late PublishedModelSyncCubit cubit;
  setUp(() {
    repo = TestModelRepository();
    cubit = PublishedModelSyncCubit(PublishedModelSyncService(repo));
  });
  tearDown(() => cubit.close());
  test('catalog selects published site and loads the complete model', () async {
    await cubit.loadSites();
    expect(cubit.state.phase, ModelSyncPhase.ready);
    expect(cubit.state.model!.nodes.length, 2);
    expect(cubit.state.checkedAt, isNotNull);
  });
  test('refresh hides old data until current version is checked', () async {
    await cubit.loadSites();
    final pending = Completer<PublishedIndoorModel>();
    repo.read = (_) => pending.future;
    final refresh = cubit.refresh();
    expect(cubit.state.phase, ModelSyncPhase.syncing);
    expect(cubit.state.model, isNull);
    pending.complete(publishedModel(version: 'v2'));
    await refresh;
    expect(cubit.state.model!.versionId, 'v2');
    expect(cubit.state.versionChanged, isTrue);
  });
  test('network failure removes previously visible model', () async {
    await cubit.loadSites();
    repo.read = (_) async => throw const PublishedModelFailure('Sin conexión');
    await cubit.refresh();
    expect(cubit.state.phase, ModelSyncPhase.error);
    expect(cubit.state.message, 'Sin conexión');
    expect(cubit.state.model, isNull);
  });
  test('late previous-site response cannot replace selection', () async {
    repo.sites = const [
      PublishedSite(id: 'site', name: 'Uno'),
      PublishedSite(id: 'other', name: 'Dos'),
    ];
    await cubit.loadSites();
    final pending = Completer<PublishedIndoorModel>();
    repo.read = (site) => site == 'site'
        ? pending.future
        : Future.value(publishedModel(site: site));
    final old = cubit.refresh();
    await cubit.selectSite('other');
    pending.complete(publishedModel());
    await old;
    expect(cubit.state.siteId, 'other');
    expect(cubit.state.model!.siteId, 'other');
  });
  test('empty catalog clears previous selection and graph', () async {
    await cubit.loadSites();
    repo.sites = [];
    await cubit.loadSites();
    expect(cubit.state.phase, ModelSyncPhase.empty);
    expect(cubit.state.model, isNull);
    expect(cubit.state.siteId, isNull);
  });
}
