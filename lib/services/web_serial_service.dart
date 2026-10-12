import 'dart:async';
import 'dart:js_interop';
import 'relay_controller.dart';
import 'web_serial_bindings.dart';

/// Web Serial API를 통한 릴레이 컨트롤러 구현
class WebSerialService implements RelayController {
  SerialPort? _port;
  ReadableStreamReader? _reader;
  WritableStreamWriter? _writer;

  bool _isConnected = false;
  bool _isReading = false;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();

  final JsTextEncoder _encoder = JsTextEncoder();
  final JsTextDecoder _decoder = JsTextDecoder();

  String _buffer = '';

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<String> get responseStream => _responseController.stream;

  /// 브라우저의 시리얼 포트 선택 다이얼로그를 열고 연결
  Future<bool> connect() async {
    await disconnect();

    try {
      final filters = <JSAny>[
        SerialPortFilter(usbVendorId: 0x10C4), // Silicon Labs CP2102/CP2104
        SerialPortFilter(usbVendorId: 0x1A86), // QinHeng CH340/CH341
        SerialPortFilter(usbVendorId: 0x0403), // FTDI FT232
        SerialPortFilter(usbVendorId: 0x067B), // Prolific PL2303
        SerialPortFilter(usbVendorId: 0x303A), // Espressif native USB
      ].toJS;

      _addResponse('[시스템] 포트 선택 중...');
      _port = await serial.requestPort(
        SerialPortRequestOptions(filters: filters),
      ).toDart;
      _addResponse('[시스템] 포트 선택 완료, 열기 시도...');

      // 포트 열기: 115200 baud, 8N1
      await _port!.open(SerialOptions(
        baudRate: 115200,
        dataBits: 8,
        stopBits: 1,
        parity: 'none',
        flowControl: 'none',
        bufferSize: 255,
      )).toDart;
      _addResponse('[시스템] 포트 열기 성공');

      // Writer 획득
      _writer = _port!.writable?.getWriter();
      if (_writer == null) {
        _addResponse('[오류] writable 스트림을 얻을 수 없습니다.');
        await _closePort();
        return false;
      }

      // 연결 상태 업데이트
      _isConnected = true;
      _connectionController.add(true);

      // 수신 루프 먼저 시작 (부팅 메시지 캡처)
      _startReadLoop();

      // DTR/RTS 신호 설정 시도 (플랫폼별 차이 대응)
      await _initSignals();

      _addResponse('[연결] Web Serial 포트 연결됨');
      return true;
    } catch (e) {
      _addResponse('[오류] 연결 실패: $e');
      await _closePort();
      return false;
    }
  }

  /// DTR/RTS 신호 초기화
  ///
  /// ESP32 CP2102 자동리셋 회로 동작 순서:
  /// 1. DTR=true, RTS=true → 안정 상태
  /// 2. RTS만 토글 → EN 리셋 펄스 (정상 부팅)
  /// 3. 2초 대기 → ESP32 부팅 완료
  Future<void> _initSignals() async {
    try {
      // 1단계: 양쪽 다 안정 상태로
      await _port!.setSignals(SerialOutputSignals(
        dataTerminalReady: true,
        requestToSend: true,
      )).toDart;
      await Future.delayed(const Duration(milliseconds: 200));

      // 2단계: RTS 토글로 ESP32 리셋 (정상 부팅 모드)
      await _port!.setSignals(SerialOutputSignals(
        dataTerminalReady: true,
        requestToSend: false,
      )).toDart;
      await Future.delayed(const Duration(milliseconds: 50));

      // 3단계: 양쪽 해제
      await _port!.setSignals(SerialOutputSignals(
        dataTerminalReady: false,
        requestToSend: false,
      )).toDart;

      _addResponse('[시스템] 신호 초기화 완료');
    } catch (e) {
      _addResponse('[경고] 신호 설정 실패 (무시): $e');
    }

    // ESP32 부팅 대기
    _addResponse('[시스템] ESP32 부팅 대기 중...');
    await Future.delayed(const Duration(seconds: 2));
    _addResponse('[시스템] ESP32 준비 완료');

    // 연결 테스트: 빈 줄 전송하여 버퍼 클리어
    try {
      final data = _encoder.encode('\n');
      await _writer!.write(data).toDart;
      _addResponse('[시스템] 연결 테스트 전송 완료');
    } catch (e) {
      _addResponse('[경고] 테스트 전송 실패: $e');
    }
  }

  /// 수신 데이터 읽기 루프
  void _startReadLoop() async {
    if (_port?.readable == null) return;

    _isReading = true;

    try {
      _reader = _port!.readable!.getReader();

      while (_isReading) {
        final result = await _reader!.read().toDart;

        if (result.done) break;

        final value = result.value;
        if (value != null) {
          final text = _decoder.decode(value);

          // 수신 원본 데이터 hex 로깅 (디버깅용)
          final dartBytes = value.toDart;
          if (dartBytes.isNotEmpty) {
            final hex = dartBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
            _addResponse('[수신 HEX] $hex');
          }

          _buffer += text;

          // 줄 단위(\n)로 파싱
          while (_buffer.contains('\n')) {
            final newlineIndex = _buffer.indexOf('\n');
            final line = _buffer.substring(0, newlineIndex).trim();
            _buffer = _buffer.substring(newlineIndex + 1);

            if (line.isNotEmpty) {
              _addResponse('[ESP32] $line');
            }
          }
        }
      }
    } catch (e) {
      if (_isReading) {
        _addResponse('[오류] 수신 중 오류: $e');
        if (_isConnected) {
          _isConnected = false;
          _connectionController.add(false);
          _addResponse('[연결 해제] 연결이 끊어졌습니다.');
        }
      }
    } finally {
      _isReading = false;
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
    if (!_isConnected || _writer == null) {
      _addResponse('[오류] 시리얼이 연결되어 있지 않습니다.');
      return;
    }

    try {
      final data = _encoder.encode('$command\n');
      await _writer!.write(data).toDart;
      _addResponse('[전송] $command');
    } catch (e) {
      _addResponse('[오류] 전송 실패: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    final wasConnected = _isConnected;
    _isReading = false;
    _buffer = '';

    try {
      if (_reader != null) {
        await _reader!.cancel().toDart;
        _reader!.releaseLock();
        _reader = null;
      }
    } catch (_) {}

    try {
      if (_writer != null) {
        _writer!.releaseLock();
        _writer = null;
      }
    } catch (_) {}

    await _closePort();

    if (wasConnected) {
      _isConnected = false;
      _connectionController.add(false);
      _addResponse('[연결 해제] 시리얼 연결이 해제되었습니다.');
    }
  }

  Future<void> _closePort() async {
    try {
      if (_port != null) {
        await _port!.close().toDart;
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
