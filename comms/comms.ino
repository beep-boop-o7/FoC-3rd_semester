//THIS IS AN UART CODE FOR COMMUNICATION BETWEEN AN ARDUINO (MEGA) AND AN FPGA (CMOD A7-35T)
#define CMD_REF 0x01
#define CMD_KP 0x02
#define CMD_KI 0x03

const uint8_t HDR_CMD = 0xA5;  // Arduino -> FPGA
const uint8_t HDR_RPL = 0x5A;  // FPGA -> Arduino
const int16_t MAX_REF = 3000;  // PLACEHOLDER: set to your safe maximum

int16_t kpSet = 150;  // what you typed
int16_t kiSet = 20;
int16_t kpFpga = 0;  // what FPGA reports back
int16_t kiFpga = 0;
int16_t refSpeed = 0;
int16_t measSpeed = 0;
String line;
uint8_t rxBuf[4];
uint8_t rxIdx = 0;
unsigned long lastTx = 0, lastPrint = 0;

bool isNumber(const String &s) {
  if (s.length() == 0) return false;
  for (unsigned i = 0; i < s.length(); i++) {
    char c = s[i];
    if (!(isDigit(c) || (i == 0 && (c == '-' || c == '+')))) return false;
  }
  return s.length() > 1 || isDigit(s[0]);
}

void console() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (line.length() > 0) {
        if (line.startsWith("kp ")) {
          kpSet = line.substring(3).toInt();
          sendKp();

          Serial.print("Kp set to ");
          Serial.println(kpSet);
        } else if (line.startsWith("ki ")) {
          kiSet = line.substring(3).toInt();
          sendKi();

          Serial.print("Ki set to ");
          Serial.println(kiSet);
        } else if (line.startsWith("ref ")) {
          refSpeed = constrain(line.substring(4).toInt(), -MAX_REF, MAX_REF);

          Serial.print("Reference set to ");
          Serial.println(refSpeed);
        } else {
          Serial.println("Commands:");
          Serial.println("ref <value>");
          Serial.println("kp <value>");
          Serial.println("ki <value>");
        }
        line = "";
      }
    } else if (line.length() < 12) {
      line += c;
    }
  }
}

void sendRef() {
  uint8_t hi = ((uint16_t)refSpeed) >> 8;
  uint8_t lo = ((uint16_t)refSpeed) & 0xFF;
  Serial1.write(HDR_CMD);
  Serial1.write(hi);
  Serial1.write(lo);
  Serial1.write((uint8_t)(HDR_CMD ^ CMD_REF ^ hi ^ lo));
}

void sendKp() {
  uint8_t hi = kpSet >> 8;
  uint8_t lo = kpSet & 0xFF;
  Serial1.write(HDR_CMD);
  Serial1.write(CMD_KP);
  Serial1.write(hi);
  Serial1.write(lo);
  Serial1.write((uint8_t)(HDR_CMD ^ CMD_KP ^ hi ^ lo));
}

void sendKi() {
  uint8_t hi = kiSet >> 8;
  uint8_t lo = kiSet & 0xFF;
  Serial1.write(HDR_CMD);
  Serial1.write(CMD_KI);
  Serial1.write(hi);
  Serial1.write(lo);
  Serial1.write((uint8_t)(HDR_CMD ^ CMD_KI ^ hi ^ lo));
}

void fpga() {
  while (Serial1.available()) {
    uint8_t b = Serial1.read();
    if (rxIdx == 0 && b != HDR_RPL) continue;  // wait for header
    rxBuf[rxIdx++] = b;
    if (rxIdx == 4) {
      rxIdx = 0;
      if ((uint8_t)(rxBuf[0] ^ rxBuf[1] ^ rxBuf[2]) == rxBuf[3]) {
        measSpeed = (int16_t)(((uint16_t)rxBuf[1] << 8) | rxBuf[2]);
      }
    }
  }
}


void setup() {
  Serial.begin(115200);
  Serial1.begin(115200);
  Serial.print("Reference speed: ");
}

void loop() {
  console();
  fpga();
  if (millis() - lastPrint >= 500) {
    lastPrint = millis();
    Serial.print("ref=");
    Serial.print(refSpeed);
    Serial.print("  meas=");
    Serial.println(measSpeed);
    Serial.print("KP set=");
    Serial.print(kpSet);
    Serial.print(" FPGA=");
    Serial.println(kpFpga);
    Serial.print("KI set=");
    Serial.print(kiSet);
    Serial.print(" FPGA=");
    Serial.println(kiFpga);
  }
}
