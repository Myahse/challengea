import 'package:flutter_test/flutter_test.dart';
import 'package:challengea/chat_store.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:challengea/games/challenge.dart';
import 'package:challengea/games/four_logic.dart';
import 'package:challengea/games/games.dart';
import 'package:challengea/games/sudoku_logic.dart';
import 'package:challengea/main.dart';
import 'package:challengea/screens/chat_home.dart';
import 'package:challengea/screens/map_screen.dart';
import 'package:challengea/screens/profile_screen.dart';

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
    await tester.pumpWidget(
      MaterialApp(home: MapScreen(store: ChatStore(), useRealMap: false)),
    );
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

  testWidgets(
    'a 1-to-1 call connects, becomes a group call when inviting, and ends',
    (tester) async {
      final store = ChatStore();
      final maurice = store.friends.firstWhere((p) => p.name == 'Maurice');
      final awa = store.friends.firstWhere((p) => p.name == 'Awa');
      final call = store.startCall([maurice]);
      expect(call.connected, isFalse);
      expect(call.title, 'Maurice');

      await tester.pump(const Duration(seconds: 4));
      expect(call.connected, isTrue);
      expect(call.joined.length, 1);

      call.invite(awa);
      expect(call.isGroup, isTrue);
      expect(call.title, 'Group call');
      await tester.pump(const Duration(seconds: 5));
      expect(call.joined.length, 2);

      call.toggleMic();
      expect(call.micOn, isFalse);
      call.end();
      expect(store.call, isNull);
    },
  );

  test('feed: like, follow, comment and replies update the counts', () {
    final feed = ChatStore().feed;
    final post = feed.forYou.first;
    final likes = post.likes;
    feed.toggleLike(post);
    expect(post.likes, likes + 1);
    feed.like(post); // double-tap on an already liked video keeps one like
    expect(post.likes, likes + 1);

    final bob = post.author;
    final followers = bob.followers;
    feed.toggleFollow(bob);
    expect(bob.followed, isTrue);
    expect(bob.followers, followers + 1);

    final count = post.commentCount;
    feed.addComment(post, 'Nice!');
    expect(post.comments.first.text, 'Nice!');
    feed.addComment(post, 'Thanks', replyTo: post.comments.first);
    expect(post.comments.first.replies.single.text, 'Thanks');
    expect(post.commentCount, count + 2);
  });

  testWidgets('profile shows the tabs from Figma and opens on my profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ChatStore();
    final bob = store.feed.forYou.first.author;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(store: store, creator: bob),
      ),
    );
    expect(find.text('Bob Reeze'), findsOneWidget);
    expect(find.text('@Boby_pop'), findsOneWidget);
    expect(find.text('24 posts'), findsOneWidget);
    expect(find.text('45 tags'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Following'),
      findsNWidgets(2),
    ); // the button + the "Following" stat tile
  });

  test('sudoku: generated grids are valid and duels share the same puzzle', () {
    for (final seed in [1, 2, 42, 999]) {
      final p = SudokuPuzzle.generate(seed: seed);
      expect(SudokuPuzzle.isValidSolution(p.solution), isTrue);
      expect(p.blanks, 42);
      for (var i = 0; i < 81; i++) {
        final g = p.givens[i ~/ 9][i % 9];
        if (g != 0) expect(g, p.solution[i ~/ 9][i % 9]);
      }
    }
    expect(
      SudokuPuzzle.generate(seed: 7).givens,
      SudokuPuzzle.generate(seed: 7).givens,
    );
  });

  test('four in a row: detects wins and the friend blocks or wins', () {
    final b = FourBoard();
    for (var c = 0; c < 3; c++) {
      b.drop(c, 1);
    }
    // I threaten column 3: the friend must block it.
    expect(b.pickMove(Random(1)), 3);
    b.drop(3, 1);
    expect(b.winLine(1), [(5, 0), (5, 1), (5, 2), (5, 3)]);

    final w = FourBoard();
    for (var i = 0; i < 3; i++) {
      w.drop(6, 2);
    }
    expect(w.pickMove(Random(1)), 6); // friend takes its own win first
  });

  testWidgets('winning a game posts the result in the chat with a Rematch', (
    tester,
  ) async {
    final store = ChatStore();
    final marc = store.friends.firstWhere((p) => p.name == 'Marc');
    postResult(store, marc, fourInRow, 'I won', won: true);
    final node = store.nodeFor(marc);
    expect(node.messages.last.game, fourInRow);
    await tester.pump(const Duration(seconds: 2));
    expect(node.messages.last.sender, marc); // the friend answers
  });
}
