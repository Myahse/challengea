import 'package:flutter_test/flutter_test.dart';
import 'package:challengea/chat_store.dart';
import 'package:flutter/material.dart';
import 'package:challengea/main.dart';
import 'package:challengea/screens/chat_home.dart';
import 'package:challengea/screens/map_screen.dart';

void main() {
  testWidgets('chat home shows the bubble field', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ChatHome(store: ChatStore())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Maurice'), findsOneWidget);
  });

  testWidgets('app opens on the chat home', (tester) async {
    await tester.pumpWidget(ChallengeaApp(store: ChatStore()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tales'), findsOneWidget);
  });

  test('merging two friends creates a group, merging again adds to it', () {
    final store = ChatStore();
    final marc = store.nodes.firstWhere((n) => n.displayName == 'Marc');
    final melanie = store.nodes.firstWhere((n) => n.displayName == 'Mélanie');
    final awa = store.nodes.firstWhere((n) => n.displayName == 'Awa');

    final first = store.merge(marc, melanie);
    expect(first.created, isTrue);
    expect(first.group.members.map((m) => m.name), ['Mélanie', 'Marc']);

    final second = store.merge(awa, first.group);
    expect(second.created, isFalse);
    expect(second.group.members.length, 3);
    expect(store.canMerge(awa, first.group), isFalse); // already a member

    store.removeMember(first.group, awa.members.first);
    store.removeMember(first.group, marc.members.first);
    expect(
      store.nodes.contains(first.group),
      isFalse,
    ); // < 2 members dissolves it
  });

  test('messaging a friend from the map creates their chat bubble once', () {
    final store = ChatStore();
    final celine = store.spots
        .firstWhere((s) => s.person.name == 'Celine May')
        .person;
    final before = store.nodes.length;
    final node = store.nodeFor(celine);
    expect(store.nodes.length, before + 1);
    expect(identical(store.nodeFor(celine), node), isTrue);
  });

  testWidgets('map page opens a friend card when a pin is tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: MapScreen(store: ChatStore())));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Celine'));
    await tester
        .pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        )
        .catchError((_) => 0);
    expect(find.text('20 friends in common'), findsOneWidget);
    expect(find.text('Celine May'), findsOneWidget);
  });
}
