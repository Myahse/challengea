import 'package:flutter_test/flutter_test.dart';
import 'package:nteri/chat_store.dart';
import 'package:nteri/main.dart';

void main() {
  testWidgets('chat home shows the bubble field', (tester) async {
    await tester.pumpWidget(NteriApp(store: ChatStore()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Maurice'), findsOneWidget);
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
    expect(store.nodes.contains(first.group), isFalse); // < 2 members dissolves it
  });
}
