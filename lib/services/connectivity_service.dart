import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/sensor_model.dart';

enum ConnectionMode { qr, manual, usb }
enum ConnectionState { disconnected, connecting, connected, error }

/// Manages WebSocket lifecycle, reconnection, and message routing.
class ConnectivityService extends ChangeNotifier {
  // ── Public state ────────────────────────────────────────────────────────────
  ConnectionState state = ConnectionState.disconnected;
  ConnectionMode? activeMode;
  String?  lastError;
  String?  connectedUrl;
  String   hostName   = '';
  String   hostOs     = '';

  // ── Streams for consumers ────────────────────────────────────────────────────
  final _catalogueCtrl = StreamController<List<SensorDescriptor>>.broadcast();
  final _readingsCtrl  = StreamController<List<SensorReading>>.broadcast();
  final _cmdResultCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<List<SensorDescriptor>> get catalogueStream => _catalogueCtrl.stream;
  Stream<List<SensorReading>>   get readingsStream   => _readingsCtrl.stream;
  Stream<Map<String, dynamic>>  get cmdResultStream  => _cmdResultCtrl.stream;

  // ── Internal ─────────────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer?  _retryTimer;
  int     _retryCount  = 0;
  String? _pendingUrl;

  static const _maxRetries      = 5;
  static const _baseRetryMs     = 1500;
  static const List<String> _usbCandidates = [
    'ws://10.0.2.2:5050/ws',   // Android emulator
    'ws://192.168.42.129:5050/ws', // USB tethering gateway (common)
    'ws://192.168.137.1:5050/ws',  // Windows Mobile Hotspot fallback
  ];

  // ─── Connect API ─────────────────────────────────────────────────────────────

  Future<void> connectManual(String ip, {int port = 5050}) =>
      _initConnect('ws://$ip:$port/ws', ConnectionMode.manual);

  Future<void> connectFromQr(String rawUrl) =>
      _initConnect(rawUrl, ConnectionMode.qr);

  Future<void> connectUsb() async {
    _setState(ConnectionState.connecting);
    for (final url in _usbCandidates) {
      try {
        final info = await http
            .get(Uri.parse(url.replaceFirst('ws://', 'http://').replaceFirst('/ws', '/info')))
            .timeout(const Duration(seconds: 2));
        if (info.statusCode == 200) {
          await _initConnect(url, ConnectionMode.usb);
          return;
        }
      } catch (_) {}
    }
    _setError('No PC found on USB tethering. Enable USB Tethering on your phone.');
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _pendingUrl = null;
    _retryCount = 0;
    state = ConnectionState.disconnected;
    notifyListeners();
  }

  void sendCommand(String command, [Map<String, String>? args]) {
    if (state != ConnectionState.connected) return;
    final msg = json.encode({
      'type': 'command',
      'payload': {'command': command, if (args != null) 'args': args},
    });
    _channel?.sink.add(msg);
  }

  // ─── Internal ────────────────────────────────────────────────────────────────

  Future<void> _initConnect(String url, ConnectionMode mode) async {
    await disconnect();
    _pendingUrl = url;
    activeMode  = mode;
    await _attempt(url);
  }

  Future<void> _attempt(String url) async {
    _setState(ConnectionState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;          // throws if connection fails
      connectedUrl = url;
      _retryCount  = 0;
      _setState(ConnectionState.connected);

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
        cancelOnError: false,
      );

      // Fetch host info
      _fetchInfo(url);
    } catch (e) {
      _scheduleRetry(url);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg     = json.decode(raw as String) as Map<String, dynamic>;
      final type    = msg['type'] as String;
      final payload = msg['payload'];

      switch (type) {
        case 'catalogue':
          final list = (payload as List)
              .map((e) => SensorDescriptor.fromJson(e as Map<String, dynamic>))
              .toList();
          _catalogueCtrl.add(list);

        case 'readings':
          final list = (payload as List)
              .map((e) => SensorReading.fromJson(e as Map<String, dynamic>))
              .toList();
          _readingsCtrl.add(list);

        case 'commandResult':
          _cmdResultCtrl.add(payload as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  void _onError(Object e) => _scheduleRetry(_pendingUrl ?? '');
  void _onDone()          => _scheduleRetry(_pendingUrl ?? '');

  void _scheduleRetry(String url) {
    if (url.isEmpty || _retryCount >= _maxRetries) {
      _setError('Connection lost. Max retries reached. Tap to reconnect.');
      return;
    }
    _retryCount++;
    final delay = Duration(milliseconds: _baseRetryMs * _retryCount);
    _setState(ConnectionState.connecting);
    debugPrint('[WS] Retry #$_retryCount in ${delay.inSeconds}s...');
    _retryTimer = Timer(delay, () => _attempt(url));
  }

  Future<void> _fetchInfo(String wsUrl) async {
    try {
      final httpUrl = wsUrl
          .replaceFirst('ws://', 'http://')
          .replaceFirst('/ws', '/info');
      final resp = await http.get(Uri.parse(httpUrl))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        hostName = data['host'] as String? ?? '';
        hostOs   = data['os']   as String? ?? '';
        notifyListeners();
      }
    } catch (_) {}
  }

  void _setState(ConnectionState s) {
    state = s;
    if (s == ConnectionState.connected) lastError = null;
    notifyListeners();
  }

  void _setError(String msg) {
    lastError = msg;
    state = ConnectionState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _catalogueCtrl.close();
    _readingsCtrl.close();
    _cmdResultCtrl.close();
    super.dispose();
  }
}
