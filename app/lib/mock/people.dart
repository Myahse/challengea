import 'package:flutter/material.dart';

import '../models.dart';

/// The Marcory cast used by the demo (and mirrored by the API mock loader).
/// These are the same instances the bubbles, the map and the feed share.
class MockPeople {
  static const me = Person('me', 'Moise', Color(0xFFFF8A3D));

  static const melanie = Person('melanie', 'Mélanie', Color(0xFFB07A4F));
  static const marc = Person('marc', 'Marc', Color(0xFFF06BA8));
  static const brendon = Person('brendon', 'Brendon', Color(0xFFF59FC4));
  static const clena = Person(
    'clena',
    'Clena',
    Color(0xFF8B6CF6),
    online: false,
  );
  static const maurice = Person('maurice', 'Maurice', Color(0xFFC9A27E));
  static const awa = Person('awa', 'Awa', Color(0xFF4FB3F6));
  static const yao = Person('yao', 'Yao', Color(0xFF5CC98A), online: false);
  static const mom = Person('maman', 'Maman', Color(0xFFE5A93B));
  static const papa = Person('papa', 'Papa', Color(0xFF7D8CA3));
  static const aicha = Person('aicha', 'Aïcha', Color(0xFFD96C6C));
  static const celine = Person('celine', 'Celine May', Color(0xFF9B6B4F));
  static const bob = Person('bob', 'Bob Reeze', Color(0xFF2F5D50));

  /// Dropped in one by one from the demo "+" button.
  static const extras = [
    Person('koffi', 'Koffi', Color(0xFF6FA8DC)),
    Person('fatou', 'Fatou', Color(0xFFE38BD1)),
    Person('ibrahim', 'Ibrahim', Color(0xFFA3C95C)),
    Person('nadia', 'Nadia', Color(0xFFF0A35E)),
    Person('serge', 'Serge', Color(0xFF8E9AF0)),
  ];

  /// People the video feed can @-mention.
  static const feedFriends = [
    melanie,
    marc,
    brendon,
    clena,
    maurice,
    awa,
    yao,
    celine,
  ];
}
