import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../screens/call_screen.dart';
import '../theme.dart';

/// Green "Tap to return to call" bar shown above every screen while a call
/// is running in the background (after the call screen was minimized).
class CallBanner extends StatelessWidget {
  const CallBanner({
    super.key,
    required this.store,
    required this.navigatorKey,
    required this.child,
  });
  final ChatStore store;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final call = store.call;
        if (call == null) return child;
        return ListenableBuilder(
          listenable: call,
          builder: (context, _) {
            final show = !call.ended && !call.screenOpen;
            final top = MediaQuery.paddingOf(context).top;
            return Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: !show
                      ? const SizedBox(width: double.infinity)
                      : Material(
                          color: AppColors.online,
                          child: InkWell(
                            onTap: () {
                              final ctx = navigatorKey.currentContext;
                              if (ctx != null) {
                                CallScreen.open(ctx, store, call);
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, top + 6, 16, 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.call_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tap to return to call · ${call.title}',
                                      style: tx(
                                        13,
                                        weight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    call.connected
                                        ? call.elapsedLabel
                                        : 'Calling…',
                                    style: tx(
                                      13,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: show
                      ? MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: child,
                        )
                      : child,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
