import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/navigation/application/indoor_navigation_cubit.dart';
import 'package:rumbo_mobile_application/navigation/application/navigation_scan_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/beacon_identifier.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_observation.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/indoor_navigation.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/indoor_navigation_repository.dart';
import 'package:rumbo_mobile_application/navigation/domain/services/rssi_window_service.dart';
import 'package:rumbo_mobile_application/navigation/domain/services/route_tracking_service.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ar_platform_bridge.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/navigation_ar_coordinator.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/repositories/indoor_navigation_http_repository.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/route/indoor_navigation_view.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

final time = DateTime.utc(2026, 11, 23);
final id = BeaconIdentifier(
  uuid: '00000000-0000-0000-0000-000000000001',
  major: 1,
  minor: 2,
);
const target = NavigationTarget(
  siteId: 'site',
  nodeId: 'b',
  name: 'Consulta',
  preferences: MobilityPreferences(avoidStairs: true),
);
IndoorPosition fix(
  String node, {
  DateTime? at,
  String floor = 'f',
  String site = 'site',
  bool reliable = true,
  String version = 'v',
}) => IndoorPosition(
  siteId: site,
  floorId: floor,
  nodeId: node,
  modelVersionId: version,
  planVersionId: 'p',
  x: node == 'a' ? 0 : 10,
  y: 0,
  observedAt: at ?? time,
  reliable: reliable,
);
PublishedRoute route() => PublishedRoute(
  siteId: 'site',
  modelVersionId: 'v',
  nodes: const [
    RouteNode('a', 'f', 'p', 0, 0),
    RouteNode('b', 'f2', 'p', 10, 0),
  ],
);

class Scan implements NavigationScanService {
  final controller = StreamController<BleScanEvent>.broadcast();
  int starts = 0, stops = 0;
  @override
  Stream<BleScanEvent> get events => controller.stream;
  @override
  Future<void> start(Set<BeaconIdentifier> inventory) async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class Repository implements IndoorNavigationRepository {
  int calls = 0;
  NavigationTarget? receivedTarget;
  Object? failure;
  Completer<PublishedRoute>? pending;
  @override
  Future<Set<BeaconIdentifier>> beacons(String site) async => {id};
  @override
  Future<IndoorPosition?> resolve(
    String site,
    List<FilteredBeacon> signals,
  ) async => null;
  @override
  Future<PublishedRoute> route(
    NavigationTarget target,
    IndoorPosition origin,
  ) async {
    calls++;
    receivedTarget = target;
    if (failure != null) throw failure!;
    return pending?.future ??
        PublishedRoute(
          siteId: 'site',
          modelVersionId: 'v',
          nodes: [
            RouteNode(origin.nodeId, origin.floorId, 'p', origin.x, origin.y),
            const RouteNode('b', 'f2', 'p', 10, 0),
          ],
        );
  }
}

class ArTransport extends ArPlatformBridge {
  final incoming = StreamController<Map<Object?, Object?>>.broadcast();
  final messages = <String, Object>{};
  @override
  bool get isSupportedPlatform => true;
  @override
  Stream<Map<Object?, Object?>> get events => incoming.stream;
  @override
  Future<void> openNavigation(String destination) async {}
  @override
  Future<void> send(String receiver, Object payload) async {
    messages[receiver] = payload;
  }

  @override
  Future<void> updateHud(String status, int progress) async {}
  @override
  Future<void> suspend() async {}
}

void main() {
  test(
    'AR receives the real floor segment and returns to the same 2D session',
    () async {
      final now = DateTime.now().toUtc();
      final scan = Scan(), ar = ArTransport();
      final repo = Repository()..pending = Completer<PublishedRoute>();
      repo.pending!.complete(
        PublishedRoute(
          siteId: 'site',
          modelVersionId: 'v',
          nodes: const [
            RouteNode('a', 'f', 'p', 0, 0),
            RouteNode('b', 'f', 'p', 10, 5),
          ],
        ),
      );
      final cubit = IndoorNavigationCubit(repo, scan, clock: () => now);
      final coordinator = NavigationArCoordinator(cubit, ar);
      addTearDown(() async {
        coordinator.dispose();
        await ar.incoming.close();
        await cubit.close();
        await scan.controller.close();
      });
      await cubit.start(target);
      await cubit.acceptPosition(
        IndoorPosition(
          siteId: 'site',
          floorId: 'f',
          planVersionId: 'p',
          modelVersionId: 'v',
          nodeId: 'a',
          x: 0,
          y: 0,
          reliable: true,
          observedAt: now,
          metersPerUnit: .2,
        ),
      );
      final session = cubit.state.sessionId;
      final route = cubit.state.route;
      await coordinator.open();
      ar.incoming.add({'state': 'navigation_ready', 'reason': 'android_host'});
      await Future<void>.delayed(Duration.zero);
      final sent = ar.messages['ReceiveRoute']! as Map<String, Object>;
      expect(sent['destinationNodeId'], 'b');
      expect((sent['nodes'] as List).last['position'], [10, -5, 0]);
      ar.incoming.add({
        'state': 'route_accepted',
        'reason': 'sessionId=${sent['sessionId']}',
      });
      ar.incoming.add({'state': 'normal'});
      await Future<void>.delayed(Duration.zero);
      expect(ar.messages['ReceivePositionFix'], isNotNull);
      ar.incoming.add({'state': 'show_map'});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.mode, GuidanceMode.fallback);
      expect(cubit.state.sessionId, session);
      expect(cubit.state.route, same(route));
      expect(scan.starts, 1);
    },
  );

  test(
    'window rejects unknown, duplicate, stale and invalid readings; robust output resists outliers',
    () {
      final filter = RssiWindowService(alpha: 1);
      BleObservation sample(
        int value,
        int seconds, {
        String payload = '004C:02150000000000000000000000000000000100010002C5',
      }) => BleObservation(
        deviceId: 'opaque',
        rssi: value,
        observedAt: time.add(Duration(seconds: seconds)),
        manufacturerData: payload,
      );
      expect(filter.add(sample(-60, 0), time, {id}), true);
      expect(filter.add(sample(-60, 0), time, {id}), false);
      expect(filter.add(sample(0, 1), time, {id}), false);
      expect(filter.add(sample(-60, -60), time, {id}), false);
      expect(filter.add(sample(-60, 1, payload: ''), time, {id}), false);
      for (var i = 1; i < 5; i++) {
        filter.add(
          sample(i == 4 ? -10 : -60, i),
          time.add(Duration(seconds: i)),
          {id},
        );
      }
      final result = filter
          .snapshot(time.add(const Duration(seconds: 4)))
          .single;
      expect(result.rssi, -60);
      expect(result.filteredDeviation, 0);
      expect(result.rawDeviation, greaterThan(0));
      expect(filter.snapshot(time.add(const Duration(minutes: 1))), isEmpty);
    },
  );
  test(
    'route matching preserves floor and plan version and recognizes vertical transition',
    () {
      final service = RouteTrackingService();
      final a = service.match(route(), fix('a'))!;
      final b = service.match(route(), fix('b', floor: 'f2'), previous: a)!;
      expect(b.floorChanged, true);
      expect(b.fraction, 1);
      expect(service.match(route(), fix('b', floor: 'wrong')), null);
    },
  );
  test(
    'deviation needs reliable persistent independent fixes, resets on route',
    () {
      final d = DeviationService();
      expect(d.update(route(), fix('outside', reliable: false)), false);
      expect(d.update(route(), fix('outside')), false);
      expect(d.update(route(), fix('outside')), false);
      expect(
        d.update(
          route(),
          fix('outside', at: time.add(const Duration(seconds: 4))),
        ),
        false,
      );
      expect(
        d.update(
          route(),
          fix('outside', at: time.add(const Duration(seconds: 9))),
        ),
        true,
      );
      expect(
        d.update(route(), fix('a', at: time.add(const Duration(seconds: 10)))),
        false,
      );
    },
  );
  group('session', () {
    late Scan scan;
    late Repository repo;
    late IndoorNavigationCubit cubit;
    late DateTime now;
    setUp(() async {
      scan = Scan();
      repo = Repository();
      now = time;
      cubit = IndoorNavigationCubit(
        repo,
        scan,
        clock: () => now,
        cooldown: Duration.zero,
      );
      await cubit.start(target);
    });
    tearDown(() async {
      await cubit.close();
      await scan.controller.close();
    });
    test('rejects other sites, low confidence and stale positions', () async {
      await cubit.acceptPosition(fix('a', site: 'other'));
      expect(cubit.state.position, null);
      await cubit.acceptPosition(fix('a', reliable: false));
      expect(cubit.state.quality, LocationQuality.lowConfidence);
      expect(repo.calls, 0);
      await cubit.acceptPosition(
        fix('a', at: time.subtract(const Duration(minutes: 2))),
      );
      expect(cubit.state.position, null);
    });
    test(
      'preserves target/session across recalculation and AR fallback/recovery',
      () async {
        await cubit.acceptPosition(fix('a'));
        final session = cubit.state.sessionId;
        final oldRoute = cubit.state.route;
        cubit.tracking({
          'state': 'lost',
          'timestampUtc': time.toIso8601String(),
        });
        expect(cubit.state.mode, GuidanceMode.fallback);
        expect(cubit.state.route, same(oldRoute));
        cubit.tracking({
          'state': 'normal',
          'timestampUtc': time
              .add(const Duration(seconds: 1))
              .toIso8601String(),
        });
        expect(cubit.state.spatialReferenceReady, false);
        expect(cubit.state.sessionId, session);
        expect(cubit.state.target, same(target));
        cubit.tracking({
          'state': 'lost',
          'timestampUtc': time
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        });
        expect(cubit.state.route, same(oldRoute));
        expect(repo.receivedTarget!.preferences.avoidStairs, true);
      },
    );
    test(
      'signal loss suspends guidance without deleting destination',
      () async {
        await cubit.acceptPosition(fix('a'));
        now = time.add(const Duration(minutes: 1));
        cubit.tick();
        expect(cubit.state.quality, LocationQuality.signalLost);
        expect(cubit.state.canGuide, false);
        expect(cubit.state.target, same(target));
      },
    );
    test('failed route invalidates old guidance and retry recovers', () async {
      await cubit.acceptPosition(fix('a'));
      repo.failure = const NavigationFailure(
        'Sin ruta',
        code: 'ROUTE_NOT_FOUND',
      );
      await cubit.recalculate(retry: true);
      expect(cubit.state.routeInvalid, true);
      repo.failure = null;
      await cubit.recalculate(retry: true);
      expect(cubit.state.canGuide, true);
    });
    test(
      'concurrent route requests share one in flight; stopped sessions reject response',
      () async {
        repo.pending = Completer<PublishedRoute>();
        final first = cubit.acceptPosition(fix('a'));
        await Future<void>.delayed(Duration.zero);
        await cubit.recalculate(retry: true);
        expect(repo.calls, 1);
        await cubit.stop();
        repo.pending!.complete(route());
        await first;
        expect(cubit.state.route, null);
      },
    );
  });
  test('HTTP route uses real endpoint and all mobility preferences', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/sites/site/routes');
      expect(request.url.queryParameters['from'], 'a');
      expect(request.url.queryParameters['avoidStairs'], 'true');
      return http.Response(
        jsonEncode({
          'siteId': 'site',
          'modelVersionId': 'v',
          'nodes': [
            {
              'nodeId': 'a',
              'floorId': 'f',
              'planVersionId': 'p',
              'x': 0,
              'y': 0,
            },
            {
              'nodeId': 'b',
              'floorId': 'f2',
              'planVersionId': 'p',
              'x': 10,
              'y': 0,
            },
          ],
          'links': [
            {'fromNodeId': 'a', 'toNodeId': 'b'},
          ],
        }),
        200,
      );
    });
    final repo = IndoorNavigationHttpRepository(
      client,
      ApiConfiguration(baseUrl: Uri.parse('https://example.test')),
    );
    expect((await repo.route(target, fix('a'))).nodes.length, 2);
    expect(await repo.resolve('site', []), null);
  });
  test(
    'persistent deviation requests new route from the recognized origin',
    () async {
      final scan = Scan(), repo = Repository();
      var now = time;
      final cubit = IndoorNavigationCubit(
        repo,
        scan,
        clock: () => now,
        cooldown: Duration.zero,
      );
      await cubit.start(target);
      await cubit.acceptPosition(fix('a'));
      final session = cubit.state.sessionId;
      for (final seconds in [1, 5, 10]) {
        now = time.add(Duration(seconds: seconds));
        await cubit.acceptPosition(fix('outside', at: now));
      }
      expect(repo.calls, 2);
      expect(cubit.state.route!.nodes.first.id, 'outside');
      expect(cubit.state.target, same(target));
      expect(cubit.state.sessionId, session);
      expect(cubit.state.routeInvalid, false);
      await cubit.close();
      await scan.controller.close();
    },
  );
  test('obsolete route response is not applied after origin changes', () async {
    final scan = Scan(), repo = Repository();
    var now = time;
    final cubit = IndoorNavigationCubit(repo, scan, clock: () => now);
    await cubit.start(target);
    repo.pending = Completer<PublishedRoute>();
    final loading = cubit.acceptPosition(fix('a'));
    await Future<void>.delayed(Duration.zero);
    now = time.add(const Duration(seconds: 1));
    await cubit.acceptPosition(fix('outside', at: now));
    repo.pending!.complete(route());
    await loading;
    expect(cubit.state.route, null);
    expect(cubit.state.routeInvalid, true);
    await cubit.close();
    await scan.controller.close();
  });
  test('network failure and malformed graph never produce a route', () async {
    for (final client in [
      MockClient((_) async => throw http.ClientException('offline')),
      MockClient((_) async => http.Response('{"nodes":[]}', 200)),
    ]) {
      final repository = IndoorNavigationHttpRepository(
        client,
        ApiConfiguration(baseUrl: Uri.parse('https://example.test')),
      );
      await expectLater(
        repository.route(target, fix('a')),
        throwsA(isA<NavigationFailure>()),
      );
    }
  });
  test(
    'tracking ignores duplicate, stale, future and unknown events',
    () async {
      final scan = Scan(), repo = Repository();
      var now = time;
      final cubit = IndoorNavigationCubit(repo, scan, clock: () => now);
      await cubit.start(target);
      await cubit.acceptPosition(fix('a'));
      expect(
        cubit.tracking({
          'state': 'limited',
          'timestampUtc': now.toIso8601String(),
        }),
        true,
      );
      final fallback = cubit.state;
      expect(
        cubit.tracking({
          'state': 'normal',
          'timestampUtc': now.toIso8601String(),
        }),
        false,
      );
      expect(cubit.state, same(fallback));
      expect(
        cubit.tracking({
          'state': 'unknown',
          'timestampUtc': now.add(const Duration(seconds: 1)).toIso8601String(),
        }),
        false,
      );
      now = now.add(const Duration(seconds: 2));
      expect(
        cubit.tracking({
          'state': 'recovered',
          'timestampUtc': now.toIso8601String(),
        }),
        true,
      );
      expect(cubit.state.spatialReferenceReady, false);
      expect(
        cubit.tracking({
          'state': 'lost',
          'timestampUtc': now.add(const Duration(hours: 1)).toIso8601String(),
        }),
        false,
      );
      await cubit.close();
      await scan.controller.close();
    },
  );
  for (final code in [400, 403, 404, 422, 500]) {
    test('HTTP $code fails safely', () async {
      final repo = IndoorNavigationHttpRepository(
        MockClient(
          (_) async => http.Response('{"code":"NO_COMPATIBLE_ROUTE"}', code),
        ),
        ApiConfiguration(baseUrl: Uri.parse('https://example.test')),
      );
      await expectLater(
        repo.route(target, fix('a')),
        throwsA(isA<NavigationFailure>()),
      );
    });
  }
  testWidgets(
    'location searching, error and low confidence remain visible and accessible',
    (tester) async {
      final scan = Scan(), repo = Repository();
      final cubit = IndoorNavigationCubit(repo, scan, clock: () => time);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: IndoorNavigationView(navigation: cubit)),
        ),
      );
      expect(find.text('Buscando tu ubicación'), findsOneWidget);
      await tester.runAsync(() async {
        await cubit.start(target);
        await cubit.acceptPosition(fix('a', reliable: false));
      });
      await tester.pump();
      expect(find.text('Ubicación no confiable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await cubit.close();
        await scan.controller.close();
      });
    },
  );
}
