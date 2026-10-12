import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

/// 도어 릴레이 컨트롤러 앱 진입점
///
/// ESP32 기반 도어 릴레이를 Web Serial API로 제어하는 웹 앱.
/// Chrome 148+ (안드로이드/윈도우) 에서 USB 유선 제어 가능.
/// 향후 Wi-Fi 원격 제어를 추가해도 같은 RelayController 인터페이스 사용.
void main() {
  runApp(const DoorRelayApp());
}

class DoorRelayApp extends StatelessWidget {
  const DoorRelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '도어 릴레이 컨트롤러',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
        brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
