import 'package:flutter/material.dart';

import '../models.dart';
import 'people.dart';

/// A friend pin on the drawn map, in pixels centered on Marcory.
class MockSpot {
  const MockSpot(
    this.person,
    this.position, {
    required this.place,
    required this.status,
    required this.updated,
    required this.common,
  });

  final Person person;
  final Offset position;
  final String place;
  final String status;
  final String updated;
  final int common;
}

/// Canned replies the demo sends back after you write in a chat.
const mockReplies = [
  'Ok !',
  'Grave',
  'On se fait une partie ?',
  'Haha',
  'Je suis là',
];

/// Friends on the map, in drawn-map pixels (centered on Marcory).
List<MockSpot> mockSpots() => [
  MockSpot(
    MockPeople.celine,
    const Offset(560, 760),
    place: 'Marcory, Abidjan',
    status: 'On my way to the match',
    updated: '2 min ago',
    common: 20,
  ),
  MockSpot(
    MockPeople.melanie,
    const Offset(985, 640),
    place: 'Remblais, Marcory',
    status: 'At the market',
    updated: '5 min ago',
    common: 12,
  ),
  MockSpot(
    MockPeople.marc,
    const Offset(420, 1210),
    place: 'Koumassi',
    status: 'Playing Sudoku',
    updated: 'just now',
    common: 8,
  ),
  MockSpot(
    MockPeople.brendon,
    const Offset(905, 1250),
    place: 'Avenue des Métiers',
    status: 'Story time',
    updated: '10 min ago',
    common: 15,
  ),
  MockSpot(
    MockPeople.maurice,
    const Offset(770, 1490),
    place: 'Grand Carrefour, Koumassi',
    status: 'Free tonight?',
    updated: '1 h ago',
    common: 5,
  ),
  MockSpot(
    MockPeople.awa,
    const Offset(1060, 985),
    place: 'Marcory Zone 4',
    status: 'Coffee break',
    updated: '20 min ago',
    common: 9,
  ),
  MockSpot(
    MockPeople.clena,
    const Offset(300, 870),
    place: 'Treichville',
    status: 'Offline',
    updated: '3 h ago',
    common: 3,
  ),
  MockSpot(
    MockPeople.yao,
    const Offset(1180, 820),
    place: 'Biétry',
    status: 'At the barbershop',
    updated: '40 min ago',
    common: 4,
  ),
];

/// Bubbles on the chat home, with a few messages already in them.
List<BubbleNode> mockBubbles([DateTime? now]) {
  final t = now ?? DateTime.now();
  return [
    BubbleNode.person(
      MockPeople.melanie,
      home: const Offset(.44, .17),
      size: 53,
      tag: Icons.bookmark,
      messages: [
        Message(
          'Tu as vu le nouveau jeu dans Tales ?',
          sender: MockPeople.melanie,
          time: t.subtract(const Duration(minutes: 40)),
        ),
        Message(
          'Pas encore, je teste ce soir',
          time: t.subtract(const Duration(minutes: 38)),
        ),
        Message(
          'Je te challenge dès que tu es en ligne',
          sender: MockPeople.melanie,
          time: t.subtract(const Duration(minutes: 36)),
        ),
      ],
    ),
    BubbleNode.group(
      id: 'g_family',
      members: [MockPeople.mom, MockPeople.papa, MockPeople.aicha],
      home: const Offset(.78, .18),
      name: 'Family group',
      messages: [
        Message(
          'Dîner dimanche chez nous',
          sender: MockPeople.mom,
          time: t.subtract(const Duration(hours: 3)),
        ),
        Message(
          'Je ramène le dessert',
          sender: MockPeople.aicha,
          time: t.subtract(const Duration(hours: 2)),
        ),
        Message(
          'J’apporte le vin',
          sender: MockPeople.papa,
          time: t.subtract(const Duration(hours: 1, minutes: 40)),
        ),
      ],
    ),
    BubbleNode.person(
      MockPeople.marc,
      home: const Offset(.19, .36),
      size: 52,
      tag: Icons.favorite,
      messages: [
        Message(
          'On se fait un Sudoku en duel ?',
          sender: MockPeople.marc,
          time: t.subtract(const Duration(minutes: 12)),
        ),
      ],
    ),
    BubbleNode.person(MockPeople.awa, home: const Offset(.50, .47), size: 30),
    BubbleNode.person(
      MockPeople.brendon,
      home: const Offset(.75, .51),
      size: 54,
      storyRing: true,
      messages: [
        Message(
          'Regarde ma story',
          sender: MockPeople.brendon,
          time: t.subtract(const Duration(minutes: 5)),
        ),
      ],
    ),
    BubbleNode.group(
      id: 'g_tales',
      members: [MockPeople.marc, MockPeople.brendon, MockPeople.awa],
      home: const Offset(.33, .22),
      name: 'Tales',
      messages: [
        Message(
          'Qui est chaud pour un Four in a row ?',
          sender: MockPeople.brendon,
          time: t.subtract(const Duration(minutes: 25)),
        ),
        Message(
          'Moi. Perdant paie les allocos.',
          sender: MockPeople.marc,
          time: t.subtract(const Duration(minutes: 22)),
        ),
      ],
    ),
    BubbleNode.person(MockPeople.clena, home: const Offset(.20, .62), size: 26),
    BubbleNode.person(
      MockPeople.maurice,
      home: const Offset(.53, .76),
      size: 52,
      unread: 6,
      messages: [
        Message(
          'Tu passes au Grand Carrefour ?',
          sender: MockPeople.maurice,
          time: t.subtract(const Duration(minutes: 30)),
        ),
        Message(
          'Dans une heure',
          time: t.subtract(const Duration(minutes: 29)),
        ),
        Message(
          'Ok je t’attends devant la station',
          sender: MockPeople.maurice,
          time: t.subtract(const Duration(minutes: 3)),
        ),
      ],
    ),
    BubbleNode.person(MockPeople.yao, home: const Offset(.86, .78), size: 24),
    BubbleNode.person(
      MockPeople.celine,
      home: const Offset(.12, .84),
      size: 40,
      messages: [
        Message(
          'Je suis au stade, tu viens ?',
          sender: MockPeople.celine,
          time: t.subtract(const Duration(minutes: 8)),
        ),
      ],
    ),
  ];
}
