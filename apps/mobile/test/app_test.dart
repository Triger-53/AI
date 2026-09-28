import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_janab/main.dart';
import 'package:quran_janab/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { SharedPreferences.setMockInitialValues({}); });

  test('Full corpus has stable chapter and ayah counts', () async {
    final chapters = await Chapter.load();
    expect(chapters.length, 114);
    expect(chapters.fold<int>(0, (n, c) => n + c.verses.length), 6236);
    expect(chapters.first.verses.length, 7);
    expect(chapters.last.id, 114);
  });

  test('History round trips without storing audio or credentials', () async {
    final store = AppStore(await SharedPreferences.getInstance());
    await store.add(PracticeRecord(surah: 1, start: 1, end: 7, seconds: 60,
      reviews: 1, demo: true, completed: false, date: DateTime(2026, 9, 28)));
    expect(store.history.single.demo, isTrue);
    expect(store.history.single.surah, 1);
    await store.clearHistory();
    expect(store.history, isEmpty);
  });

  testWidgets('Home opens the passage setup with demo as default', (tester) async {
    final store = AppStore(await SharedPreferences.getInstance());
    final chapters = await Chapter.load();
    await tester.pumpWidget(JanabApp(store: store, chapters: chapters));
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare your practice'), findsOneWidget);
    expect(find.text('Explore demo'), findsOneWidget);
    expect(find.text('Connect microphone'), findsNothing);
  });

  testWidgets('Arabic preference selects Arabic app locale', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'ar'});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(JanabApp(store: store, chapters: await Chapter.load()));
    expect(find.text('قرآن جناب'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('ar'));
  });
}
