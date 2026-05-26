/***************************************************
  Feather M4 + Fingerprint Sensor Test
  
  Connect fingerprint sensor to:
  - D20 (SDA) = Sensor TX (white)
  - D21 (SCL) = Sensor RX (green)
  - GND = GND
  - 3V3 = Power
  
  Open Serial Monitor at 115200 baud and send commands.
 ****************************************************/

#include <Adafruit_Fingerprint.h>

// Use hardware Serial1 reconfigured to SDA/SCL pins (D20/D21)
// On Feather M4: PA12 (SDA) and PA13 (SCL)
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&Serial1);

void printHelp() {
  Serial.println("\n=== Feather M4 Fingerprint Sensor Test ===");
  Serial.println("Commands:");
  Serial.println("  SCAN     -> Try to scan finger and identify");
  Serial.println("  LIST_IDS -> List all enrolled fingerprints");
  Serial.println("  STATUS   -> Show sensor status");
  Serial.println("  HELP     -> Show this help");
}

void printHexByte(uint8_t b) {
  if (b < 16) {
    Serial.print('0');
  }
  Serial.print(b, HEX);
}

void listEnrolledIDs() {
  Serial.println("\n--- Listing Enrolled IDs ---");
  finger.getTemplateCount();
  Serial.print("Total Templates: ");
  Serial.println(finger.templateCount);

  uint16_t maxID = finger.capacity > 0 ? finger.capacity : 127;
  bool first = true;
  Serial.print("Enrolled IDs: ");
  
  int count = 0;
  for (uint16_t id = 1; id <= maxID; id++) {
    uint8_t p = finger.loadModel(id);
    if (p == FINGERPRINT_OK) {
      if (!first) {
        Serial.print(", ");
      }
      Serial.print(id);
      count++;
      first = false;
    }
  }
  
  if (count == 0) {
    Serial.print("None");
  }
  Serial.println();
  Serial.print("Total enrolled: ");
  Serial.println(count);
}

void showStatus() {
  Serial.println("\n--- Sensor Status ---");
  
  uint8_t p = finger.getParameters();
  if (p != FINGERPRINT_OK) {
    Serial.println("Failed to get parameters");
    return;
  }
  
  finger.getTemplateCount();
  Serial.print("Enrolled Templates: ");
  Serial.println(finger.templateCount);
  Serial.print("Sensor Capacity: ");
  Serial.println(finger.capacity);
  Serial.print("Security Level: ");
  Serial.println(finger.security_level);
  Serial.println("Status: OK ✓");
}

int getFingerprintID() {
  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) {
    Serial.println("Failed to capture image");
    return -1;
  }
  
  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) {
    Serial.println("Failed to convert image");
    return -1;
  }
  
  p = finger.fingerFastSearch();
  if (p != FINGERPRINT_OK) {
    Serial.println("No match found");
    return -1;
  }
  
  return finger.fingerID;
}

void testScan() {
  Serial.println("\n--- Scanning Fingerprint ---");
  Serial.println("Place your finger on the sensor...");
  
  uint8_t p = finger.getImage();
  if (p == FINGERPRINT_NOFINGER) {
    Serial.println("No finger detected");
    return;
  } else if (p != FINGERPRINT_OK) {
    Serial.println("Communication error");
    return;
  }
  
  Serial.println("Image captured");
  
  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) {
    Serial.println("Failed to process image");
    return;
  }
  
  p = finger.fingerFastSearch();
  if (p == FINGERPRINT_OK) {
    Serial.print("✓ MATCH FOUND - ID: ");
    Serial.println(finger.fingerID);
  } else {
    Serial.println("✗ No match - finger not recognized");
  }
}

void setup() {
  delay(1000);
  
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== Feather M4 Fingerprint Sensor Test ===");
  Serial.println("[INIT] Starting initialization...");
  Serial.println("[INIT] Using SDA (D20) and SCL (D21) for Serial1");
  Serial.println("[INIT] Serial1 speed: 57600 baud");
  
  Serial1.begin(57600);
  delay(1000);
  
  Serial.println("[INIT] Calling finger.begin()...");
  finger.begin(57600);
  delay(500);
  
  Serial.println("[INIT] Testing verifyPassword()...");
  if (finger.verifyPassword()) {
    Serial.println("[SUCCESS] ✓ Fingerprint sensor found!");
    
    Serial.println("[INIT] Getting sensor parameters...");
    uint8_t p = finger.getParameters();
    if (p == FINGERPRINT_OK) {
      finger.getTemplateCount();
      Serial.print("[SENSOR] Templates enrolled: ");
      Serial.println(finger.templateCount);
      Serial.print("[SENSOR] Capacity: ");
      Serial.println(finger.capacity);
      Serial.println("[READY] Sensor is ready for testing");
    } else {
      Serial.print("[ERROR] Failed to get parameters, code: ");
      Serial.println(p, HEX);
    }
  } else {
    Serial.println("[ERROR] ✗ Fingerprint sensor NOT detected");
    Serial.println("[CHECK] Verify connections:");
    Serial.println("        D20 (SDA/PA12) -> Sensor TX (white)");
    Serial.println("        D21 (SCL/PA13) -> Sensor RX (green)");
    Serial.println("        GND -> GND");
    Serial.println("        3V3 -> 3V3 Power");
    Serial.println("[CHECK] Try: LIST_IDS, SCAN, or STATUS");
  }
  
  printHelp();
}

void loop() {
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();
    
    if (cmd == "SCAN") {
      testScan();
    } else if (cmd == "LIST_IDS") {
      listEnrolledIDs();
    } else if (cmd == "STATUS") {
      showStatus();
    } else if (cmd == "HELP") {
      printHelp();
    } else if (cmd.length() > 0) {
      Serial.print("Unknown command: ");
      Serial.println(cmd);
      printHelp();
    }
  }
  
  delay(50);
}
