import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_territory_app/main.dart';

void main() {
  testWidgets('App builds and runs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RunnerTerritoryApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
