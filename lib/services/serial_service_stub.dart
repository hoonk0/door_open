import 'dart:async';
import 'relay_controller.dart';

/// 비-웹 플랫폼에서는 Web Serial API 미지원
bool get isWebSerialSupported => false;

/// 스텁에서는 네이티브 USB도 미지원
bool get isNativeUsbSupported => false;

/// 비-웹 플랫폼용 WebSerialService 스텁
///
/// Android/iOS 등 네이티브 플랫폼에서는 Web Serial API가 없으므로
/// 모든 메서드가 no-op으로 동작하며, isWebSerialSupported가 false를 반환.
class WebSerialService implements RelayController {
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();

  @override
  bool get isConnected => false;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<String> get responseStream => _responseController.stream;

  Future<bool> connect() async => false;

  @override
  Future<void> relayOn() async {}

  @override
  Future<void> relayOff() async {}

  @override
  Future<void> doorOpen() async {}

  @override
  Future<void> sendCommand(String command) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    _connectionController.close();
    _responseController.close();
  }
}
