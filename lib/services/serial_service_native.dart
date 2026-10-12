import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'relay_controller.dart';

/// 네이티브 플랫폼에서는 Web Serial 미지원
bool get isWebSerialSupported => false;

/// 네이티브 USB Serial 지원 여부 (Android)
bool get isNativeUsbSupported => true;

/// Android 네이티브 USB Serial 서비스
///
/// usb_serial 패키지를 사용하여 ESP32와 USB 시리얼 통신.
class WebSerialService implements RelayController {
  UsbPort? _port;
  bool _isConnected = false;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();

  StreamSubscription<Uint8List>? _inputSub;
  String _buffer = '';

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<String> get responseStream => _responseController.stream;

  /// USB 장치 검색 후 연결
  Future<bool> connect() async {
    await disconnect();

    try {
      // 연결된 USB 장치 목록 조회
      _addResponse('[시스템] USB 장치 검색 중...');
      final devices = await UsbSerial.listDevices();

      if (devices.isEmpty) {
        _addResponse('[오류] 연결된 USB 장치가 없습니다. USB 케이블을 확인하세요.');
        return false;
      }

      // 장치 목록 로그
      for (final d in devices) {
        _addResponse('[시스템] 발견: ${d.productName ?? "알 수 없음"} '
            '(VID:0x${d.vid?.toRadixString(16).toUpperCase()}, '
            'PID:0x${d.pid?.toRadixString(16).toUpperCase()})');
      }

      // 첫 번째 장치 사용 (ESP32)
      final device = devices.first;
      _addResponse('[시스템] ${device.productName ?? "USB 장치"} 연결 시도...');

      _port = await device.create();
      if (_port == null) {
        _addResponse('[오류] USB 포트를 생성할 수 없습니다.');
        return false;
      }

      final openResult = await _port!.open();
      if (!openResult) {
        _addResponse('[오류] USB 포트를 열 수 없습니다. USB 권한을 확인하세요.');
        _port = null;
        return false;
      }

      // 시리얼 통신 설정: 115200 baud, 8N1
      await _port!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // DTR/RTS 신호 설정
      await _port!.setDTR(true);
      await _port!.setRTS(true);
      _addResponse('[시스템] 포트 설정 완료 (115200, 8N1, DTR/RTS ON)');

      // 수신 데이터 리스닝 (UTF-8 디코딩)
      _inputSub = _port!.inputStream?.listen((Uint8List data) {
        final text = utf8.decode(data, allowMalformed: true);
        _buffer += text;

        // 줄 단위 파싱
        while (_buffer.contains('\n')) {
          final newlineIndex = _buffer.indexOf('\n');
          final line = _buffer.substring(0, newlineIndex).trim();
          _buffer = _buffer.substring(newlineIndex + 1);

          if (line.isNotEmpty) {
            _addResponse('[ESP32] $line');
          }
        }
      });

      // 연결 상태 업데이트
      _isConnected = true;
      _connectionController.add(true);
      _addResponse('[연결] USB Serial 연결됨');

      // ESP32 부팅 대기
      await Future.delayed(const Duration(seconds: 2));
      _addResponse('[시스템] ESP32 준비 완료');

      return true;
    } catch (e) {
      _addResponse('[오류] 연결 실패: $e');
      await _closePort();
      return false;
    }
  }

  @override
  Future<void> relayOn() async {
    await sendCommand('1');
  }

  @override
  Future<void> relayOff() async {
    await sendCommand('0');
  }

  @override
  Future<void> doorOpen() async {
    await sendCommand('open');
  }

  @override
  Future<void> sendCommand(String command) async {
    if (!_isConnected || _port == null) {
      _addResponse('[오류] USB가 연결되어 있지 않습니다.');
      return;
    }

    try {
      final data = Uint8List.fromList(utf8.encode('$command\n'));
      await _port!.write(data);
      _addResponse('[전송] $command');
    } catch (e) {
      _addResponse('[오류] 전송 실패: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    final wasConnected = _isConnected;
    _buffer = '';

    await _inputSub?.cancel();
    _inputSub = null;

    await _closePort();

    if (wasConnected) {
      _isConnected = false;
      _connectionController.add(false);
      _addResponse('[연결 해제] USB 연결이 해제되었습니다.');
    }
  }

  Future<void> _closePort() async {
    try {
      if (_port != null) {
        await _port!.close();
        _port = null;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    disconnect();
    _connectionController.close();
    _responseController.close();
  }

  void _addResponse(String message) {
    _responseController.add(message);
  }
}
