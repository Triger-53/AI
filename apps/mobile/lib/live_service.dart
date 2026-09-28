import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'models.dart';

/// Native WebRTC media + authenticated application event socket.
/// No OpenAI key is stored in, requested by, or embedded in this app.
class LiveService {
  final String server, token;
  final void Function(Map<String, dynamic>) onEvent;
  RTCPeerConnection? _peer;
  RTCDataChannel? _channel;
  MediaStream? _microphone;
  MediaStream? _remote;
  WebSocket? _events;
  final RTCVideoRenderer _audio = RTCVideoRenderer();
  String? _id;
  bool _disposed = false, _closing = false, _hearTutor = false, _cancelCapture = false;
  final Completer<void> _started = Completer<void>();
  final Completer<void> _closed = Completer<void>();
  LiveService({required this.server, required this.token, required this.onEvent});

  Uri _uri(String path) {
    final uri = Uri.parse(server);
    final local = ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host);
    if (uri.userInfo.isNotEmpty || uri.query.isNotEmpty || uri.fragment.isNotEmpty ||
        uri.host.isEmpty || (uri.scheme != 'https' && !(kDebugMode && local && uri.scheme == 'http'))) {
      throw const FormatException('Use an HTTPS backend URL. Debug builds also allow localhost or the Android emulator.');
    }
    return uri.replace(path: '${uri.path.replaceAll(RegExp(r'/+$'), '')}$path');
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds:10);
    try {
      final request = await client.postUrl(_uri(path));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
      final response = await request.close().timeout(const Duration(seconds:35));
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds:35));
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw HttpException(parsed['detail'] is String ? parsed['detail'] : 'Session request failed (${response.statusCode}).');
      }
      return parsed;
    } finally { client.close(force: true); }
  }

  Future<void> start(Passage passage, String language) async {
    if (token.length < 24) { throw const FormatException('Enter your backend access token in Settings.'); }
    _uri('/sessions');
    await _audio.initialize();
    try {
      _microphone = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': false},
        'video': false,
      });
      if (_cancelCapture) { throw StateError('Capture cancelled'); }
      if (_disposed) { await _cleanup(); return; }
      _peer = await createPeerConnection({'iceServers': [], 'sdpSemantics': 'unified-plan'});
      _peer!.onTrack = (event) {
        if (_disposed || event.streams.isEmpty) { return; }
        _remote = event.streams.first;
        _audio.srcObject = _remote;
        setTutorAudible(_hearTutor);
      };
      _peer!.onConnectionState = (state) {
        if (!_closing && (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected)) {
          onEvent({'type': 'error', 'message': 'Audio connection lost. Live checking has stopped.'});
        }
      };
      for (final track in _microphone!.getAudioTracks()) {
        await _peer!.addTrack(track, _microphone!);
      }
      _channel = await _peer!.createDataChannel('oai-events', RTCDataChannelInit());
      _channel!.onMessage = (message) {
        if (message.isBinary) { return; }
        try {
          final event = jsonDecode(message.text) as Map<String, dynamic>;
          if (event['type'] == 'session.started' && !_started.isCompleted) { _started.complete(); }
          if (event['type'] == 'session.closed' && !_closed.isCompleted) { _closed.complete(); }
          if (event['type'] == 'session.output_transcript.delta' && _hearTutor) {
            onEvent({'type': 'caption', 'delta': event['delta'] ?? ''});
          }
        } catch (_) { /* Ignore unsupported provider events, never parse as app commands. */ }
      };
      final iceReady = Completer<void>();
      _peer!.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete && !iceReady.isCompleted) {
          iceReady.complete();
        }
      };
      await _peer!.setLocalDescription(await _peer!.createOffer());
      await iceReady.future.timeout(const Duration(seconds:15));
      if (_cancelCapture) { throw StateError('Capture cancelled'); }
      if (_disposed) { await _cleanup(); return; }
      final offer = await _peer!.getLocalDescription();
      final answer = await _post('/sessions', {'surah': passage.chapter.id,
        'start': passage.start, 'end': passage.end, 'language': language,
        'sdp': offer!.sdp, 'experimental_acknowledged': true});
      _id = answer['id'] as String;
      if (_cancelCapture) { throw StateError('Capture cancelled'); }
      if (_disposed) { await stop(); return; }
      final eventsUri = _uri('/sessions/$_id/events');
      _events = await WebSocket.connect(eventsUri.replace(scheme: eventsUri.scheme == 'https' ? 'wss' : 'ws').toString(),
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'}).timeout(const Duration(seconds:10));
      _events!.listen((raw) {
        if (_disposed) { return; }
        try { onEvent(jsonDecode(raw as String) as Map<String, dynamic>); }
        catch (_) { onEvent({'type':'error','message':'Invalid session event. Checking stopped.'}); }
      }, onError: (Object _) {
        if (!_closing) { onEvent({'type':'error','message':'Checking connection lost.'}); }
      }, onDone: () {
        if (!_closing) { onEvent({'type':'error','message':'Checking connection ended.'}); }
      });
      await _peer!.setRemoteDescription(RTCSessionDescription(answer['transport']['sdp'], 'answer'));
      await _started.future.timeout(const Duration(seconds:20));
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  void setTutorAudible(bool audible) {
    _hearTutor = audible;
    for (final track in _remote?.getAudioTracks() ?? <MediaStreamTrack>[]) { track.enabled = audible; }
    // RTCVideoRenderer.muted controls LOCAL microphones on native platforms;
    // it throws for a remote stream. Gate remote AudioTrack.enabled instead.
  }

  void retry() {
    setTutorAudible(false);
    _events?.add(jsonEncode({'type':'retry'}));
  }

  void cancelCapture() {
    _cancelCapture = true;
    for (final track in _microphone?.getTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = false;
      unawaited(track.stop());
    }
  }

  Future<bool> stop() async {
    if (_closing) { return _closed.isCompleted; }
    _closing = true;
    // Stop local capture immediately, even while provider finalization drains.
    for (final track in _microphone?.getTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = false;
      try { await track.stop(); } catch (_) { /* Continue closing the session. */ }
    }
    setTutorAudible(false);
    bool confirmed = _closed.isCompleted;
    try {
      if (_id != null) {
        final result = await _post('/sessions/$_id/end', {});
        confirmed = result['finalization_confirmed'] == true;
      }
    } catch (_) {
      try {
        await _channel?.send(RTCDataChannelMessage(jsonEncode({'type':'session.close'})));
        await _closed.future.timeout(const Duration(seconds:4));
        confirmed = true;
      } catch (_) { confirmed = false; }
    } finally { await _cleanup(); }
    return confirmed;
  }

  Future<void> _cleanup() async {
    final alreadyDisposed = _disposed;
    _disposed = true;
    _remote = null;
    for (final track in _microphone?.getTracks() ?? <MediaStreamTrack>[]) {
      try { await track.stop(); } catch (_) { /* Best-effort native cleanup. */ }
    }
    try { await _events?.close(); } catch (_) { /* Already disconnected. */ }
    try { await _microphone?.dispose(); } catch (_) { /* Already disposed. */ }
    try { await _channel?.close(); } catch (_) { /* Already closed. */ }
    try { await _peer?.close(); } catch (_) { /* Already closed. */ }
    try { await _peer?.dispose(); } catch (_) { /* Already disposed. */ }
    if (!alreadyDisposed) { await _audio.dispose(); }
    _events = null; _microphone = null; _channel = null; _peer = null;
  }
}
