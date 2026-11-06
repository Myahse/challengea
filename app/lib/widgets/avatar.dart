import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'glass.dart';

/// A person as a glossy bubble with their initial. Swap the initial for the
/// profile picture once people can upload one.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(
    this.person, {
    super.key,
    required this.diameter,
    this.border = 0,
  });
  final Person person;
  final double diameter;
  final double border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: orbBody(person.color, shadow: diameter >= 44).copyWith(
        border: border > 0
            ? Border.all(color: Colors.white, width: border)
            : null,
      ),
      foregroundDecoration: orbShine,
      alignment: Alignment.center,
      child: Text(
        person.initials,
        style: tx(
          diameter * .38,
          weight: FontWeight.w600,
          color: Colors.white.withValues(alpha: .92),
        ),
      ),
    );
  }
}

/// Group bubble content: members packed inside one circle.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar(this.members, {super.key, required this.diameter});
  final List<Person> members;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(members.length > 5 ? 4 : 5).toList();
    final extra = members.length - shown.length;
    final n = shown.length + (extra > 0 ? 1 : 0);
    final r = diameter / 2;
    // Size of each mini avatar so they fit around the center.
    final mini = n <= 2
        ? diameter * .52
        : (n == 3 ? diameter * .46 : diameter * .40);
    final ring = n <= 2 ? r * .36 : r * .44;
    final children = <Widget>[];
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + i * 2 * pi / n + (n == 2 ? pi / 4 : 0);
      final c = Offset(r + ring * cos(a), r + ring * sin(a));
      final Widget w = (extra > 0 && i == n - 1)
          ? Container(
              width: mini,
              height: mini,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.nightCard,
              ),
              alignment: Alignment.center,
              child: Text(
                '+$extra',
                style: tx(
                  mini * .36,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : PersonAvatar(shown[i], diameter: mini, border: 1.5);
      children.add(
        Positioned(left: c.dx - mini / 2, top: c.dy - mini / 2, child: w),
      );
    }
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}
