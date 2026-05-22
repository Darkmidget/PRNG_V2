/***************************************************
  Feather M4 + Fingerprint Sensor Test
  With Adafruit Library and Verbose Diagnostics
  
  ⚠️ IMPORTANT: Serial Baud Rate Configuration
  ============================================
  This Feather M4 has TWO independent UART interfaces:
  
  1. Serial (USB Debug):     
     - Hardware: USB via CP2104
     - Speed: 115200 baud
     - Use: Code uploads, Serial Monitor debugging
     
  2. Serial1 (Fingerprint Sensor on D0/D1):
     - Hardware: D0 (RX), D1 (TX) pins
     - Speed: 57600 baud ⚠️
     - Use: Fingerprint sensor communication
  
  🔧 CONNECTION:
  - Sensor TX (white) → D0 (RX)
  - Sensor RX (green) → D1 (TX)
  - GND → GND
  - 3V3 → 3V3
  
  📋 TO RUN THIS TEST:
  When opening Serial Monitor, MANUALLY SET BAUD RATE TO 57600
  (PlatformIO defaults to 115200, but sensor needs 57600)
  
  Command: .venv\Scripts\platformio.exe device monitor -p COM8 --baud 57600
  
 ****************************************************/

#include <Adafruit_Fingerprint.h>

// D0/D1 are the hardware UART pins (Serial1) for fingerprint sensor
// Serial1 communicates at 57600 baud with the fingerprint module
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&Serial1);

void printHelp() {
  Serial.println("\n=== Feather M4 Fingerprint Sensor Test ===");
  Serial.println("Commands:");
  Serial.println("  SCAN     -> Try to scan finger and identify");
  Serial.println("  LIST_IDS -> List all enrolled fingerprints");
  Serial.println("  STATUS   -> Show sensor status");
  Serial.println("  INIT     -> Re-initialize sensor");
  Serial.println("  HELP     -> Show this help");
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
    Serial.print("Failed to get parameters, error code: 0x");
    Serial.println(p, HEX);
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
  if (p == FINGERPRINT_NOFINGER) {
    Serial.println("No finger detected");
    return -1;
  } else if (p != FINGERPRINT_OK) {
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
    Serial.print("Communication error, code: 0x");
    Serial.println(p, HEX);
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

void initializeSensor() {
  Serial.println("\n[INIT] Reinitializing sensor...");
  
  Serial.println("[INIT] Starting Serial1 at 57600...");
  Serial1.begin(57600);
  delay(1000);
  
  Serial.println("[INIT] Calling finger.begin()...");
  finger.begin(57600);
  delay(500);
  
  Serial.println("[INIT] Verifying password...");
  if (!finger.verifyPassword()) {
    Serial.println("[ERROR] Did not find fingerprint sensor!");
    Serial.println("[CHECK] Verify connections:");
    Serial.println("        D0 (RX) -> Sensor TX (white)");
    Serial.println("        D1 (TX) -> Sensor RX (green)");
    Serial.println("        GND -> GND, 3V3 -> 3V3");
    return;
  }
  
  Serial.println("[SUCCESS] Sensor found!");
  finger.getTemplateCount();
  Serial.print("[SENSOR] Templates: ");
  Serial.print(finger.templateCount);
  Serial.print(" / Capacity: ");
  Serial.println(finger.capacity);
}

void setup() {
  delay(1000);
  
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n============================================");
  Serial.println("Feather M4 Fingerprint Sensor Test");
  Serial.println("============================================");
  Serial.println("\n⚠️  IMPORTANT BAUD RATE INFO:");
  Serial.println("   USB Serial (this messages): 115200 baud");
  Serial.println("   Sensor Serial1 (D0/D1):    57600 baud");
  Serial.println("\nIf monitor shows garbled text:");
  Serial.println("  Change monitor to 57600 baud");
  Serial.println("  Command: platformio.exe device monitor -p COM8 --baud 57600");
  Serial.println("============================================\n");
  
  initializeSensor();
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
    } else if (cmd == "INIT") {
      initializeSensor();
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
