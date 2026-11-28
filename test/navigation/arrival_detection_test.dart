import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_mobile_application/navigation/application/navigation_session_closer.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/indoor_navigation.dart';
import 'package:rumbo_mobile_application/navigation/domain/services/arrival_detection_service.dart';
import 'package:rumbo_mobile_application/navigation/presentation/widgets/arrival_confirmation_sheet.dart';

final _t0 = DateTime.utc(2026, 11, 28, 15);

PublishedRoute _route() => PublishedRoute(
  siteId: 'site',
  modelVersionId: 'v1',
  nodes: const [
    RouteNode('entrada', 'p1', 'plan1', 0, 0),
    RouteNode('pasillo', 'p1', 'plan1', 5, 0),
    RouteNode('cardiologia', 'p1', 'plan1', 10, 0),
  ],
);

IndoorPosition _fix(
  int second, {
  String node = 'cardiologia',
  String floor = 'p1',
  bool reliable = true,
  String model = 'v1',
}) => IndoorPosition(
  siteId: 'site',
  floorId: floor,
  nodeId: node,
  modelVersionId: model,
  planVersionId: 'plan1',
  x: 10,
  y: 0,
  observedAt: _t0.add(Duration(seconds: second)),
  reliable: reliable,
);

VioObservation _vio(
  double second,
  double meters, {
  String node = 'cardiologia',
  bool tracking = true,
}) => VioObservation(
  nodeId: node,
  metersToNode: meters,
  observedAt: _t0.add(Duration(milliseconds: (second * 1000).round())),
  tracking: tracking,
);

void main() {
  group('ArrivalDetectionService', () {
    late ArrivalDetectionService detector;

    setUp(() => detector = ArrivalDetectionService()..watch(_route()));

    test('BLE alone needs three steady fixes over four seconds', () {
      expect(detector.onBle(_fix(0)).arrived, isFalse);
      expect(detector.onBle(_fix(2)).arrived, isFalse);
      final third = detector.onBle(_fix(4));
      expect(third.arrived, isTrue);
      expect(third.evidence, ArrivalEvidence.ble);
    });

    test('one fix at the destination is not an arrival', () {
      expect(detector.onBle(_fix(0)).arrived, isFalse);
      expect(detector.onBle(_fix(10, node: 'pasillo')).arrived, isFalse);
      expect(detector.onBle(_fix(12)).arrived, isFalse);
    });

    test('an unreliable fix or another map version restarts the count', () {
      detector.onBle(_fix(0));
      detector.onBle(_fix(2));
      expect(detector.onBle(_fix(3, reliable: false)).arrived, isFalse);
      expect(detector.onBle(_fix(4)).arrived, isFalse);
      detector.onBle(_fix(6));
      expect(detector.onBle(_fix(7, model: 'v2')).arrived, isFalse);
      expect(detector.onBle(_fix(8)).arrived, isFalse);
    });

    test('the destination node on another floor never counts', () {
      for (var s = 0; s <= 10; s += 2) {
        expect(detector.onBle(_fix(s, floor: 'p2')).arrived, isFalse);
      }
    });

    test('old or repeated fixes are ignored', () {
      detector.onBle(_fix(0));
      detector.onBle(_fix(2));
      expect(detector.onBle(_fix(2)).arrived, isFalse);
      expect(detector.onBle(_fix(1)).arrived, isFalse);
      expect(detector.onBle(_fix(4)).arrived, isTrue);
    });

    test('BLE and VIO agreeing confirm at once', () {
      expect(detector.onBle(_fix(0)).arrived, isFalse);
      final both = detector.onVio(_vio(0.5, 0.8));
      expect(both.arrived, isTrue);
      expect(both.evidence, ArrivalEvidence.bleAndVio);
    });

    test(
      'VIO alone needs two seconds inside the radius on the right floor',
      () {
        detector.onBle(_fix(0, node: 'pasillo'));
        expect(detector.onVio(_vio(1, 1.2)).arrived, isFalse);
        expect(detector.onVio(_vio(2, 1.0)).arrived, isFalse);
        final steady = detector.onVio(_vio(3, 0.6));
        expect(steady.arrived, isTrue);
        expect(steady.evidence, ArrivalEvidence.vio);
      },
    );

    test('VIO without a BLE fix on the destination floor is not trusted', () {
      detector.onBle(_fix(0, node: 'pasillo', floor: 'p2'));
      for (var s = 1; s <= 6; s++) {
        expect(detector.onVio(_vio(s.toDouble(), 0.5)).arrived, isFalse);
      }
    });

    test('a lost AR reference or a jump outside the radius restarts VIO', () {
      detector.onBle(_fix(0, node: 'pasillo'));
      detector.onVio(_vio(1, 1.0));
      expect(detector.onVio(_vio(2, 1.0, tracking: false)).arrived, isFalse);
      expect(detector.onVio(_vio(3, 1.0)).arrived, isFalse);
      expect(detector.onVio(_vio(4, 4.0)).arrived, isFalse);
      expect(detector.onVio(_vio(5, 1.0)).arrived, isFalse);
      expect(detector.onVio(_vio(7, 1.0)).arrived, isTrue);
    });

    test('a stale BLE fix does not confirm a later VIO reading', () {
      detector.onBle(_fix(0));
      expect(detector.onVio(_vio(5, 0.5, node: 'pasillo')).arrived, isFalse);
      expect(detector.onVio(_vio(6, 0.5)).arrived, isFalse);
    });

    test('an arrival is reported once until the detector is reset', () {
      detector.onBle(_fix(0));
      expect(detector.onVio(_vio(0.5, 0.5)).arrived, isTrue);
      expect(detector.onVio(_vio(1, 0.4)).arrived, isFalse);
      expect(detector.onBle(_fix(2)).arrived, isFalse);

      detector.reset();
      detector.onBle(_fix(3));
      expect(detector.onVio(_vio(3.5, 0.5)).arrived, isTrue);
    });

    test('"not yet" keeps it quiet for a while and needs fresh evidence', () {
      detector.onBle(_fix(0));
      expect(detector.onVio(_vio(0.5, 0.5)).arrived, isTrue);

      detector.snooze(_t0.add(const Duration(seconds: 1)));
      detector.onBle(_fix(2));
      expect(detector.onVio(_vio(2.5, 0.5)).arrived, isFalse);

      detector.onBle(_fix(22));
      expect(detector.onVio(_vio(22.5, 0.5)).arrived, isTrue);
    });

    test('a new route to another destination starts from scratch', () {
      detector.onBle(_fix(0));
      detector.onBle(_fix(2));
      detector.watch(
        PublishedRoute(
          siteId: 'site',
          modelVersionId: 'v1',
          nodes: const [
            RouteNode('entrada', 'p1', 'plan1', 0, 0),
            RouteNode('pasillo', 'p1', 'plan1', 5, 0),
          ],
        ),
      );
      expect(detector.onBle(_fix(4)).arrived, isFalse);
    });

    test('without a route nothing is detected', () {
      final idle = ArrivalDetectionService();
      expect(idle.onBle(_fix(0)).arrived, isFalse);
      expect(idle.onVio(_vio(1, 0.2)).arrived, isFalse);
    });
  });

  group('NavigationSessionCloser', () {
    test('closes a session once even when asked at the same time', () async {
      final calls = <String>[];
      final release = Completer<void>();
      final closer = NavigationSessionCloser((id, ending) async {
        calls.add('$id:${ending.name}');
        await release.future;
      });

      final first = closer.close('s1', NavigationEnding.arrived);
      final second = closer.close('s1', NavigationEnding.cancelled);
      release.complete();

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(await closer.close('s1', NavigationEnding.arrived), isFalse);
      expect(calls, ['s1:arrived']);
      expect(closer.isClosed('s1'), isTrue);
    });

    test('a failed close can be tried again', () async {
      var attempts = 0;
      final closer = NavigationSessionCloser((_, _) async {
        if (++attempts == 1) throw StateError('offline');
      });

      await expectLater(
        closer.close('s1', NavigationEnding.arrived),
        throwsStateError,
      );
      expect(closer.isClosed('s1'), isFalse);
      expect(await closer.close('s1', NavigationEnding.arrived), isTrue);
      expect(attempts, 2);
    });

    test('an empty session id is never closed', () async {
      var called = false;
      final closer = NavigationSessionCloser((_, _) async => called = true);
      expect(await closer.close('', NavigationEnding.cancelled), isFalse);
      expect(called, isFalse);
    });
  });

  group('ArrivalConfirmationSheet', () {
    Future<ArrivalAnswer?> open(WidgetTester tester) async {
      ArrivalAnswer? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  answer = await ArrivalConfirmationSheet.show(
                    context,
                    destinationName: 'Cardiología',
                  ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('names the destination and finishes on "Sí, terminar"', (
      tester,
    ) async {
      ArrivalAnswer? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  answer = await ArrivalConfirmationSheet.show(
                    context,
                    destinationName: 'Cardiología',
                  ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Llegaste a Cardiología'), findsOneWidget);
      await tester.tap(find.text('Sí, terminar'));
      await tester.pumpAndSettle();
      expect(answer, ArrivalAnswer.finish);
    });

    testWidgets('closing it without answering keeps guiding', (tester) async {
      await open(tester);
      expect(find.text('Todavía no'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Llegaste a Cardiología'), findsNothing);
    });
  });
}
