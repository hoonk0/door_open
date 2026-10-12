export 'web_serial_service.dart';
export 'web_serial_bindings.dart' show isWebSerialSupported;

/// 웹에서는 네이티브 USB 미지원
bool get isNativeUsbSupported => false;
