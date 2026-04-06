import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runner_territory_app/screens/home/run_summary_screen.dart';
import 'package:runner_territory_app/models/app_models.dart';

// Minimal wrapper — RunSummaryScreen only needs MaterialApp + its runData args.
Widget buildSummaryScreen(Map<String, dynamic> runData) {
  return MaterialApp(
    home: RunSummaryScreen(runData: runData),
  );
}

Territory _fakeTerritory({double areaSqKm = 0.42}) {
  return Territory(
    id: 'test-id',
    ownerId: 'user-1',
    ownerName: 'Test Runner',
    areaSqKm: areaSqKm,
    polygonPoints: const [
      LatLng(37.77, -122.41),
      LatLng(37.78, -122.41),
      LatLng(37.78, -122.42),
      LatLng(37.77, -122.42),
    ],
    createdAt: DateTime(2026, 4, 4),
  );
}

Map<String, dynamic> _baseRunData({Territory? claimedTerritory}) => {
      'distanceKm': 3.14,
      'timeSeconds': 1200,
      'route': <LatLng>[],
      'claimedTerritory': claimedTerritory,
      'maxSpeedKph': 12.5,
      'userId': 'user-1',
      'userName': 'Test Runner',
    };

void main() {
  group('RunSummaryScreen — no territory claimed', () {
    testWidgets('shows "Run Complete!" title', (tester) async {
      await tester.pumpWidget(buildSummaryScreen(_baseRunData()));
      await tester.pump();

      expect(find.text('Run Complete!'), findsOneWidget);
    });

    testWidgets('shows motivational subtitle', (tester) async {
      await tester.pumpWidget(buildSummaryScreen(_baseRunData()));
      await tester.pump();

      expect(find.text('Great effort, keep it up!'), findsOneWidget);
    });

    testWidgets('territory card is absent', (tester) async {
      await tester.pumpWidget(buildSummaryScreen(_baseRunData()));
      await tester.pump();

      expect(find.text('Territory Claimed'), findsNothing);
    });

    testWidgets('displays formatted distance', (tester) async {
      await tester.pumpWidget(buildSummaryScreen(_baseRunData()));
      await tester.pump();

      expect(find.text('3.14'), findsOneWidget);
      expect(find.text('KILOMETERS'), findsOneWidget);
    });

    testWidgets('displays TIME stat row', (tester) async {
      await tester.pumpWidget(buildSummaryScreen(_baseRunData()));
      await tester.pump();

      // 1200 seconds = 20:00
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
    });

    testWidgets('Share Run and Back to Dashboard buttons are present',
        (tester) async {
      await tester.pumpWidget(buildSummaryScreen(_baseRunData()));
      await tester.pump();

      expect(find.text('Share Run'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);
    });
  });

  group('RunSummaryScreen — territory claimed', () {
    // Pump helper: advances past the 300 ms Future.delayed that starts confetti.
    Future<void> pumpClaimed(WidgetTester tester, Territory territory) async {
      await tester.pumpWidget(
          buildSummaryScreen(_baseRunData(claimedTerritory: territory)));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shows "Territory Claimed!" title', (tester) async {
      await pumpClaimed(tester, _fakeTerritory());
      expect(find.text('Territory Claimed!'), findsOneWidget);
    });

    testWidgets('shows "You\'ve marked your territory!" subtitle',
        (tester) async {
      await pumpClaimed(tester, _fakeTerritory());
      expect(find.text("You've marked your territory!"), findsOneWidget);
    });

    testWidgets('territory card shows correct area', (tester) async {
      await pumpClaimed(tester, _fakeTerritory(areaSqKm: 0.42));
      expect(find.text('Territory Claimed'), findsOneWidget);
      expect(find.textContaining('0.42 km²'), findsOneWidget);
    });

    testWidgets('territory card shows flag icon', (tester) async {
      await pumpClaimed(tester, _fakeTerritory());
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('verified icon is shown on territory card', (tester) async {
      await pumpClaimed(tester, _fakeTerritory());
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });
  });

  group('RunSummaryScreen — edge cases', () {
    testWidgets('zero distance renders "0.00"', (tester) async {
      final data = {
        ..._baseRunData(),
        'distanceKm': 0.0,
        'timeSeconds': 0,
      };
      await tester.pumpWidget(buildSummaryScreen(data));
      await tester.pump();

      expect(find.text('0.00'), findsOneWidget);
    });

    testWidgets('pace shows "--:--" when distance is zero', (tester) async {
      final data = {
        ..._baseRunData(),
        'distanceKm': 0.0,
        'timeSeconds': 600,
      };
      await tester.pumpWidget(buildSummaryScreen(data));
      await tester.pump();

      expect(find.text('--:--/km'), findsOneWidget);
    });

    testWidgets('time over 1 hour displays hh:mm:ss format', (tester) async {
      final data = {
        ..._baseRunData(),
        'timeSeconds': 3661, // 1:01:01
      };
      await tester.pumpWidget(buildSummaryScreen(data));
      await tester.pump();

      expect(find.text('01:01:01'), findsOneWidget);
    });

    testWidgets('missing optional keys do not crash (null safety)', (tester) async {
      // Pass only required-ish keys — optionals should fall back to defaults.
      final minimal = <String, dynamic>{};
      await tester.pumpWidget(buildSummaryScreen(minimal));
      await tester.pump();

      // Should not throw and should show fallback "Run Complete!" path.
      expect(find.text('Run Complete!'), findsOneWidget);
    });

  });
}
