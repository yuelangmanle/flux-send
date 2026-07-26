import 'dart:io';

import 'package:localsend_app/provider/network/webrtc/signaling_provider.dart';
import 'package:test/test.dart';

void main() {
  test('Flux should not start WebRTC signaling when no signaling server is configured', () {
    final state = SignalingState(
      signalingServers: normalizeFluxSignalingServers(null),
      stunServers: normalizeFluxStunServers(['stun:example.com'], null),
      connections: const {},
    );

    expect(state.signalingServers, isEmpty);
    expect(state.stunServers, isEmpty);
    expect(shouldStartSignalingConnection(state), isFalse);
  });

  test('Flux should ignore the legacy LocalSend public signaling server', () {
    final state = SignalingState(
      signalingServers: normalizeFluxSignalingServers([
        ' wss://public.localsend.org/v1/ws ',
        ' wss://flux.example.com/ws ',
      ]),
      stunServers: normalizeFluxStunServers(
        [' stun:flux.example.com '],
        [' wss://public.localsend.org/v1/ws ', ' wss://flux.example.com/ws '],
      ),
      connections: const {},
    );

    expect(state.signalingServers, ['wss://flux.example.com/ws']);
    expect(state.stunServers, ['stun:flux.example.com']);
    expect(shouldStartSignalingConnection(state), isTrue);
  });

  test('Flux should never print WebRTC private keys to logs', () {
    final source = File('lib/provider/network/webrtc/signaling_provider.dart').readAsStringSync();

    expect(source, isNot(contains('private key')));
    expect(source, isNot(contains('key.privateKey}')));
  });
}
