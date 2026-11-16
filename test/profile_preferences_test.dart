import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumbo_mobile_application/profiles/infrastructure/profile_repository.dart';
import 'package:rumbo_mobile_application/profiles/presentation/views/profile/profile_preferences_panel.dart';
import 'package:rumbo_mobile_application/shared/infrastructure/config/api_configuration.dart';

void main() {
  const labels = ['Evitar escaleras', 'Ruta más simple', 'Indicaciones por voz'];
  const fields = ['avoidStairs', 'simplerRoute', 'voiceGuidance'];
  const error = 'No se pudieron actualizar las preferencias.';
  final config = ApiConfiguration(baseUrl: Uri.parse('http://localhost:8080'));

  for (var index = 0; index < fields.length; index++) {
    for (final outcome in ['success', '400', '500', 'network']) {
      testWidgets('${fields[index]} handles PUT $outcome', (tester) async {
        // Mixed values catch accidentally resetting the other preferences.
        final confirmed = <String, bool>{
          'avoidStairs': true,
          'simplerRoute': false,
          'voiceGuidance': true,
        };
        final changed = {...confirmed, fields[index]: !confirmed[fields[index]]!};
        final response = Completer<http.Response>();
        final writes = <http.Request>[];
        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/profiles/me/preferences');
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({...confirmed, 'configured': true}),
              200,
            );
          }
          expect(request.method, 'PUT');
          writes.add(request);
          if (writes.length > 1) return http.Response('{}', 500);
          return response.future;
        });
        addTearDown(client.close);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfilePreferencesPanel(
                  repository: ProfileRepository(client, config),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        SwitchListTile tile(int i) => tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, labels[i]),
        );

        for (var i = 0; i < fields.length; i++) {
          expect(tile(i).value, confirmed[fields[i]]);
        }
        await tester.tap(find.text(labels[index]));
        await tester.pump();

        expect(writes, hasLength(1));
        expect(jsonDecode(writes.single.body), changed);
        expect(writes.single.headers['content-type'], 'application/json');
        for (var i = 0; i < fields.length; i++) {
          expect(tile(i).onChanged, isNull);
        }
        await tester.tap(find.text(labels[(index + 1) % labels.length]));
        await tester.pump();
        expect(writes, hasLength(1));

        if (outcome == 'network') {
          response.completeError(http.ClientException('offline'));
        } else {
          response.complete(
            http.Response(
              outcome == 'success'
                  ? jsonEncode({...changed, 'configured': true})
                  : '{}',
              outcome == 'success' ? 200 : int.parse(outcome),
            ),
          );
        }
        await tester.pumpAndSettle();

        final expected = outcome == 'success' ? changed : confirmed;
        for (var i = 0; i < fields.length; i++) {
          expect(tile(i).value, expected[fields[i]]);
          expect(tile(i).onChanged, isNotNull);
        }
        expect(
          find.text(error),
          outcome == 'success' ? findsNothing : findsOneWidget,
        );

        // A later rejection must retain the latest successful API response.
        if (outcome == 'success') {
          await tester.tap(find.text(labels[index]));
          await tester.pumpAndSettle();
          expect(writes, hasLength(2));
          expect(jsonDecode(writes.last.body), confirmed);
          for (var i = 0; i < fields.length; i++) {
            expect(tile(i).value, changed[fields[i]]);
            expect(tile(i).onChanged, isNotNull);
          }
          expect(find.text(error), findsOneWidget);
        }
      });
    }
  }
}
