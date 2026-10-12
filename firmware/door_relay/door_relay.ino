/*
 * ESP32 도어 릴레이 컨트롤러 펌웨어
 *
 * USB Serial(115200)로 명령 수신 → GPIO 16 릴레이 제어
 *
 * 명령어:
 *   "1"    → 릴레이 ON
 *   "0"    → 릴레이 OFF
 *   "open" → 릴레이 ON → 2초 후 자동 OFF
 */

#define RELAY_PIN 16
#define BAUD_RATE 115200
#define DOOR_OPEN_MS 2000

// open 명령 자동 OFF 타이머
unsigned long autoOffTime = 0;
bool autoOffPending = false;

void setup() {
  Serial.begin(BAUD_RATE);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);

  Serial.println("ESP32 Door Relay Ready");
  Serial.println("GPIO: 16 | Baud: 115200");
}

void loop() {
  // 시리얼 명령 수신
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();

    if (cmd == "1") {
      digitalWrite(RELAY_PIN, HIGH);
      autoOffPending = false;
      Serial.println("RELAY ON");

    } else if (cmd == "0") {
      digitalWrite(RELAY_PIN, LOW);
      autoOffPending = false;
      Serial.println("RELAY OFF");

    } else if (cmd == "open") {
      digitalWrite(RELAY_PIN, HIGH);
      autoOffTime = millis() + DOOR_OPEN_MS;
      autoOffPending = true;
      Serial.println("DOOR OPENING (2s)");

    } else {
      Serial.print("UNKNOWN: ");
      Serial.println(cmd);
    }
  }

  // open 명령 자동 OFF 처리
  if (autoOffPending && millis() >= autoOffTime) {
    digitalWrite(RELAY_PIN, LOW);
    autoOffPending = false;
    Serial.println("DOOR CLOSED (auto off)");
  }
}
