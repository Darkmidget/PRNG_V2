#include <Adafruit_Fingerprint.h>

// RX2 -> sensor TX, TX2 -> sensor RX
#define FINGER_RX_PIN 16
#define FINGER_TX_PIN 17

HardwareSerial FingerSerial(2);
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&FingerSerial);

void printHelp() {
  Serial.println("Commands over USB Serial:");
  Serial.println("  ENROLL              -> start enroll for next free ID");
  Serial.println("  SCAN                -> try to scan once and report ID");
  Serial.println("  LIST_IDS            -> list currently enrolled IDs");
  Serial.println("  TEMPLATE_EXPORT:<id> -> export one template as hex chunks");
  Serial.println("  TEMPLATE_EXPORT_ALL -> export all templates");
}

void printHexByte(uint8_t b) {
  if (b < 16) {
    Serial.print('0');
  }
  Serial.print(b, HEX);
}

void listEnrolledIDs() {
  finger.getTemplateCount();
  Serial.print("IDS_COUNT:");
  Serial.println(finger.templateCount);

  uint16_t maxID = finger.capacity > 0 ? finger.capacity : 127;
  bool first = true;
  Serial.print("IDS:");
  for (uint16_t id = 1; id <= maxID; id++) {
    uint8_t p = finger.loadModel(id);
    if (p == FINGERPRINT_OK) {
      if (!first) {
        Serial.print(",");
      }
      Serial.print(id);
      first = false;
    }
  }
  Serial.println();
}

void exportTemplateByID(int id) {
  if (id <= 0) {
    Serial.print("TEMPLATE_ERROR:");
    Serial.print(id);
    Serial.println(":INVALID_ID");
    return;
  }

  uint8_t p = finger.loadModel(id);
  if (p != FINGERPRINT_OK) {
    Serial.print("TEMPLATE_ERROR:");
    Serial.print(id);
    Serial.println(":LOAD_MODEL_FAIL");
    return;
  }

  p = finger.getModel();
  if (p != FINGERPRINT_OK) {
    Serial.print("TEMPLATE_ERROR:");
    Serial.print(id);
    Serial.println(":GET_MODEL_FAIL");
    return;
  }

  Serial.print("TEMPLATE_BEGIN:");
  Serial.println(id);

  uint8_t packetData[64] = {0};
  Adafruit_Fingerprint_Packet packet(FINGERPRINT_DATAPACKET, sizeof(packetData), packetData);
  uint16_t seq = 0;
  uint32_t totalBytes = 0;
  while (true) {
    p = finger.getStructuredPacket(&packet, 1000);
    if (p != FINGERPRINT_OK) {
      Serial.print("TEMPLATE_ERROR:");
      Serial.print(id);
      Serial.println(":PACKET_READ_FAIL");
      return;
    }

    uint16_t payloadLen = 0;
    if (packet.length >= 2) {
      payloadLen = packet.length - 2;
    }

    Serial.print("TEMPLATE_CHUNK:");
    Serial.print(id);
    Serial.print(":");
    Serial.print(seq);
    Serial.print(":");
    for (uint16_t i = 0; i < payloadLen; i++) {
      printHexByte(packet.data[i]);
    }
    Serial.println();

    totalBytes += payloadLen;
    seq++;

    if (packet.type == FINGERPRINT_ENDDATAPACKET) {
      break;
    }
  }

  Serial.print("TEMPLATE_END:");
  Serial.print(id);
  Serial.print(":");
  Serial.println(totalBytes);
}

void exportAllTemplates() {
  uint16_t maxID = finger.capacity > 0 ? finger.capacity : 127;
  uint16_t exported = 0;

  Serial.println("TEMPLATE_EXPORT_ALL_BEGIN");
  for (uint16_t id = 1; id <= maxID; id++) {
    uint8_t p = finger.loadModel(id);
    if (p == FINGERPRINT_OK) {
      exportTemplateByID(id);
      exported++;
      delay(20);
    }
  }
  Serial.print("TEMPLATE_EXPORT_ALL_END:");
  Serial.println(exported);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  FingerSerial.begin(57600, SERIAL_8N1, FINGER_RX_PIN, FINGER_TX_PIN);
  delay(1000);

  Serial.println("ESP32 fingerprint bridge starting...");

  finger.begin(57600);
  if (finger.verifyPassword()) {
    Serial.println("Found fingerprint sensor");
  } else {
    Serial.println("Did not find fingerprint sensor :(");
  }

  finger.getParameters();
  finger.getTemplateCount();
  Serial.print("Templates: ");
  Serial.println(finger.templateCount);
  Serial.print("Capacity: ");
  Serial.println(finger.capacity);
  printHelp();
}

int getFingerprintIDez() {
  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) return -1;
  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) return -1;
  p = finger.fingerFastSearch();
  if (p != FINGERPRINT_OK) return -1;
  return finger.fingerID;
}

void enrollFingerprint(int id) {
  Serial.print("Enrolling ID "); Serial.println(id);
  int p = -1;
  while (p != FINGERPRINT_OK) {
    Serial.println("Place finger for first scan...");
    p = finger.getImage();
    if (p == FINGERPRINT_OK) break;
    delay(500);
  }
  p = finger.image2Tz(1);
  if (p != FINGERPRINT_OK) { Serial.println("Failed to convert image 1"); return; }
  delay(1000);
  Serial.println("Remove finger");
  delay(1500);

  p = -1;
  while (p != FINGERPRINT_OK) {
    Serial.println("Place same finger for second scan...");
    p = finger.getImage();
    if (p == FINGERPRINT_OK) break;
    delay(500);
  }
  p = finger.image2Tz(2);
  if (p != FINGERPRINT_OK) { Serial.println("Failed to convert image 2"); return; }

  p = finger.createModel();
  if (p != FINGERPRINT_OK) { Serial.println("Did not create model"); return; }

  p = finger.storeModel(id);
  if (p == FINGERPRINT_OK) {
    Serial.print("ENROLL:");
    Serial.print(id);
    Serial.println(":OK");
  } else {
    Serial.print("ENROLL:");
    Serial.print(id);
    Serial.println(":FAIL");
  }
}

void loop() {
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.equalsIgnoreCase("ENROLL")) {
      int nextID = finger.templateCount + 1;
      enrollFingerprint(nextID);
      finger.getTemplateCount();
    } else if (cmd.equalsIgnoreCase("SCAN")) {
      int id = getFingerprintIDez();
      if (id >= 0) {
        Serial.print("SCAN:");
        Serial.print(id);
        Serial.println(":MATCH");
      } else {
        Serial.println("SCAN:-1:NO_MATCH");
      }
    } else if (cmd.equalsIgnoreCase("LIST_IDS")) {
      listEnrolledIDs();
    } else if (cmd.startsWith("TEMPLATE_EXPORT:")) {
      String idText = cmd.substring(String("TEMPLATE_EXPORT:").length());
      int id = idText.toInt();
      exportTemplateByID(id);
    } else if (cmd.equalsIgnoreCase("TEMPLATE_EXPORT_ALL")) {
      exportAllTemplates();
    } else if (cmd.equalsIgnoreCase("HELP")) {
      printHelp();
    } else {
      Serial.print("ERROR:UNKNOWN_COMMAND:");
      Serial.println(cmd);
    }
  }

  // small delay
  delay(50);
}
