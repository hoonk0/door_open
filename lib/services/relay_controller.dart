/// 릴레이 컨트롤러 추상 인터페이스
///
/// USB 시리얼, Wi-Fi 원격 등 다양한 통신 방식에서
/// 동일한 인터페이스로 릴레이를 제어할 수 있도록 추상화한 클래스.
/// 향후 Wi-Fi 원격 제어를 추가할 때 이 클래스를 상속받아 구현하면 됨.
abstract class RelayController {
  /// 현재 연결 상태
  bool get isConnected;

  /// 연결 상태 변경 스트림 (UI에서 구독하여 상태 표시에 사용)
  Stream<bool> get connectionStream;

  /// ESP32에서 수신한 응답 메시지 스트림 (로그 표시용)
  Stream<String> get responseStream;

  /// 릴레이 ON (ESP32에 "1\n" 전송)
  Future<void> relayOn();

  /// 릴레이 OFF (ESP32에 "0\n" 전송)
  Future<void> relayOff();

  /// 문 열기 (ESP32에 "open\n" 전송 → 2초간 릴레이 ON 후 자동 OFF)
  Future<void> doorOpen();

  /// 임의의 명령 전송 (확장용)
  Future<void> sendCommand(String command);

  /// 연결 해제
  Future<void> disconnect();

  /// 리소스 정리
  void dispose();
}
