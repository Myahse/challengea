import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

/// Live events from the server ("message.new", "match.updated"...).
/// Reconnects by itself when the network comes back.
class Realtime {
  Realtime(this.baseUrl, this.token, this.onEvent, {this.onConnected});

  final String baseUrl;
  final String token;
  final void Function(String type, dynamic data) onEvent;
  final void Function()? onConnected;
  StompClient? _client;

  void connect() {
    final wsUrl = '${baseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws';
    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 3),
        heartbeatIncoming: const Duration(seconds: 20),
        heartbeatOutgoing: const Duration(seconds: 20),
        onConnect: (_) {
          _client?.subscribe(
            destination: '/user/queue/events',
            callback: (frame) {
              final body = frame.body;
              if (body == null) return;
              final e = jsonDecode(body);
              if (e is Map) onEvent('${e['type']}', e['data']);
            },
          );
          onConnected?.call();
        },
        onWebSocketError: (_) {},
        onStompError: (_) {},
      ),
    )..activate();
  }

  bool get connected => _client?.connected ?? false;

  void close() => _client?.deactivate();
}
