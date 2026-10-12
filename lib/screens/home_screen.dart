import 'dart:async';
import 'package:flutter/material.dart';
import '../services/serial_service.dart';

/// USB 시리얼 지원 여부 (Web Serial 또는 Native USB)
bool get _isSerialSupported => isWebSerialSupported || isNativeUsbSupported;

/// 메인 홈 화면
///
/// 연결/해제 버튼, 릴레이 제어 버튼, 로그 영역으로 구성.
/// Web Serial API 또는 네이티브 USB Serial을 통해 ESP32와 통신.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Serial 서비스 인스턴스
  final WebSerialService _serialService = WebSerialService();

  // 연결 상태
  bool _isConnected = false;

  // 로그 메시지 리스트
  final List<String> _logs = [];

  // 로그 영역 자동 스크롤을 위한 컨트롤러
  final ScrollController _logScrollController = ScrollController();

  // 스트림 구독 관리
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<String>? _responseSub;

  @override
  void initState() {
    super.initState();
    _initStreams();

    // 시리얼 미지원 안내
    if (!_isSerialSupported) {
      _addLog('[오류] 이 환경에서는 USB Serial을 지원하지 않습니다');
    }
  }

  /// 스트림 구독 초기화
  void _initStreams() {
    // 연결 상태 변화 구독
    _connectionSub = _serialService.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
      });
    });

    // ESP32 응답 메시지 구독 → 로그에 추가
    _responseSub = _serialService.responseStream.listen((message) {
      _addLog(message);
    });
  }

  /// 시리얼 포트 연결
  Future<void> _connectToDevice() async {
    if (!_isSerialSupported) {
      _addLog('[오류] 이 환경에서는 USB Serial을 지원하지 않습니다');
      return;
    }
    await _serialService.connect();
  }

  /// 연결 해제
  Future<void> _disconnectDevice() async {
    await _serialService.disconnect();
  }

  /// 로그 메시지 추가 및 자동 스크롤
  void _addLog(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    setState(() {
      _logs.add('[$timeStr] $message');
      // 로그가 너무 많으면 오래된 것 삭제 (최대 200개)
      if (_logs.length > 200) {
        _logs.removeRange(0, _logs.length - 200);
      }
    });

    // 로그 영역 맨 아래로 자동 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _responseSub?.cancel();
    _serialService.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도어 릴레이 컨트롤러'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. 연결 영역 ──
            _buildConnectionSection(),
            const SizedBox(height: 20),

            // ── 2. 릴레이 제어 버튼 영역 ──
            _buildControlSection(),
            const SizedBox(height: 20),

            // ── 3. 로그 영역 ──
            _buildLogSection(),
          ],
        ),
      ),
    );
  }

  /// 연결/해제 버튼 위젯
  Widget _buildConnectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 연결 상태 표시
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.usb : Icons.usb_off,
                  color: _isConnected ? Colors.green : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'USB 연결됨' : 'USB 연결 안 됨',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isConnected
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 시리얼 미지원 경고
            if (!_isSerialSupported) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'USB Serial을 지원하지 않는 환경입니다',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 연결 / 해제 버튼
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isConnected || !_isSerialSupported)
                        ? null
                        : _connectToDevice,
                    icon: const Icon(Icons.link),
                    label: const Text('연결'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? _disconnectDevice : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('해제'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 릴레이 제어 버튼 위젯
  Widget _buildControlSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ── 메인 버튼: 문 열기 (OPEN) ──
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton.icon(
                onPressed:
                    _isConnected ? () => _serialService.doorOpen() : null,
                icon: const Icon(Icons.door_front_door, size: 36),
                label: const Text(
                  '문 열기 (OPEN)',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 릴레이 ON / OFF 버튼 ──
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isConnected
                          ? () => _serialService.relayOn()
                          : null,
                      icon: const Icon(Icons.power),
                      label: const Text(
                        '릴레이 ON',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isConnected
                          ? () => _serialService.relayOff()
                          : null,
                      icon: const Icon(Icons.power_off),
                      label: const Text(
                        '릴레이 OFF',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 통신 로그 영역 위젯
  Widget _buildLogSection() {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 로그 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '통신 로그',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  // 로그 초기화 버튼
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '로그 지우기',
                    onPressed: () {
                      setState(() {
                        _logs.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 로그 내용 (스크롤 가능)
            Expanded(
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'USB를 연결하고 명령을 전송하면\n로그가 여기에 표시됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        // 로그 종류에 따라 색상 구분
                        Color textColor = Colors.black87;
                        if (log.contains('[오류]')) {
                          textColor = Colors.red;
                        } else if (log.contains('[ESP32]')) {
                          textColor = Colors.blue.shade700;
                        } else if (log.contains('[전송]')) {
                          textColor = Colors.green.shade700;
                        } else if (log.contains('[연결]') ||
                            log.contains('[시스템]')) {
                          textColor = Colors.purple.shade600;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
