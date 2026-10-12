@JS()
library;

import 'dart:js_interop';

// ── Web Serial API 지원 여부 확인 ──

@JS('navigator.serial')
external JSObject? get _navigatorSerial;

/// 현재 브라우저가 Web Serial API를 지원하는지 확인
bool get isWebSerialSupported => _navigatorSerial != null;

// ── navigator.serial ──

@JS('navigator.serial')
external Serial get serial;

/// navigator.serial 인터페이스
extension type Serial._(JSObject _) implements JSObject {
  /// 사용자에게 시리얼 포트 선택 다이얼로그를 표시하고 선택된 포트를 반환.
  /// 반드시 사용자 제스처(클릭) 안에서 호출해야 브라우저가 허용함.
  external JSPromise<SerialPort> requestPort([SerialPortRequestOptions? options]);
}

// ── requestPort() 옵션 / 필터 ──

/// requestPort()에 전달할 옵션 (USB VID/PID 필터)
extension type SerialPortRequestOptions._(JSObject _) implements JSObject {
  external factory SerialPortRequestOptions({JSArray filters});
}

/// USB Vendor/Product ID 필터
extension type SerialPortFilter._(JSObject _) implements JSObject {
  external factory SerialPortFilter({int usbVendorId});
}

// ── SerialPort ──

/// Web Serial의 SerialPort 인터페이스
extension type SerialPort._(JSObject _) implements JSObject {
  external JSPromise open(SerialOptions options);
  external JsReadableStream? get readable;
  external JsWritableStream? get writable;
  external JSPromise setSignals(SerialOutputSignals signals);
  external JSPromise close();
}

// ── SerialPort.open() 옵션 ──

/// port.open()에 전달할 시리얼 통신 설정
extension type SerialOptions._(JSObject _) implements JSObject {
  external factory SerialOptions({
    int baudRate,
    int dataBits,
    int stopBits,
    String parity,
    String flowControl,
    int bufferSize,
  });
}

/// setSignals()에 전달할 출력 신호 설정
extension type SerialOutputSignals._(JSObject _) implements JSObject {
  external factory SerialOutputSignals({
    bool dataTerminalReady,
    bool requestToSend,
  });
}

// ── ReadableStream / Reader ──

extension type JsReadableStream._(JSObject _) implements JSObject {
  external ReadableStreamReader getReader();
}

extension type ReadableStreamReader._(JSObject _) implements JSObject {
  external JSPromise<ReadResult> read();
  external void releaseLock();
  external JSPromise cancel([JSAny? reason]);
}

/// reader.read() 결과: { value: Uint8Array, done: boolean }
extension type ReadResult._(JSObject _) implements JSObject {
  external bool get done;
  external JSUint8Array? get value;
}

// ── WritableStream / Writer ──

extension type JsWritableStream._(JSObject _) implements JSObject {
  external WritableStreamWriter getWriter();
}

extension type WritableStreamWriter._(JSObject _) implements JSObject {
  external JSPromise write(JSAny chunk);
  external void releaseLock();
  external JSPromise close();
}

// ── TextEncoder / TextDecoder ──

@JS('TextEncoder')
extension type JsTextEncoder._(JSObject _) implements JSObject {
  external factory JsTextEncoder();
  external JSUint8Array encode(String input);
}

@JS('TextDecoder')
extension type JsTextDecoder._(JSObject _) implements JSObject {
  external factory JsTextDecoder();
  external String decode([JSAny? input]);
}
