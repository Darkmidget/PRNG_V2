/***************************************************
  Feather M4 + Fingerprint Sensor Serial Diagnostic
  
  Tests raw serial communication with the fingerprint sensor.
  
  Connect fingerprint sensor to:
  - D0 (RX) = Sensor TX (white)
  - D1 (TX) = Sensor RX (green)
  
  Open Serial Monitor at 115200 baud.
 ****************************************************/

#include <Arduino.h>

// Function prototypes
void testBaudRate(int baud);
void printSerialResponse();

void setup() {
  delay(1000);
  
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== Fingerprint Sensor Serial Diagnostic ===");
  Serial.println("[TEST] Testing Serial1 at different baud rates...\n");
  
  // Test different baud rates
  int baudRates[] = {9600, 57600, 115200, 19200};
  
  for (int i = 0; i < 4; i++) {
    testBaudRate(baudRates[i]);
    delay(500);
  }
  
  Serial.println("\n[INFO] Done testing. Settling on 57600 baud.");
  Serial1.begin(57600);
  delay(500);
  Serial.println("[INFO] Serial1 initialized at 57600 baud");
  Serial.println("[INFO] Send 'PING', 'RESET', or 'SEND_COMMAND' to test");
}

void testBaudRate(int baud) {
  Serial.print("[TEST] Testing baud rate: ");
  Serial.println(baud);
  
  Serial1.begin(baud);
  delay(200);
  
  // Send a simple ping packet to the fingerprint sensor
  // Standard fingerprint sensor command format:
  // 0xEF 0x01 [length:2] [instruction] [checksum:2]
  
  byte pingPacket[] = {0xEF, 0x01, 0x00, 0x03, 0x01, 0x00, 0x05};
  
  // Clear any existing data
  while (Serial1.available()) {
    Serial1.read();
  }
  
  Serial.print("  Sending: ");
  for (int j = 0; j < 7; j++) {
    Serial.print(pingPacket[j], HEX);
    Serial.print(" ");
  }
  Serial.println();
  
  // Send ping
  Serial1.write(pingPacket, 7);
  Serial1.flush();
  
  // Wait for response
  delay(100);
  
  if (Serial1.available()) {
    Serial.print("  Response: ");
    int count = 0;
    while (Serial1.available() && count < 50) {
      byte b = Serial1.read();
      Serial.print(b, HEX);
      Serial.print(" ");
      count++;
    }
    Serial.println(" ✓");
  } else {
    Serial.println("  No response ✗");
  }
}

void loop() {
  // Check for commands from Serial
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();
    
    if (cmd == "PING") {
      Serial.println("[CMD] Sending PING...");
      byte pingPacket[] = {0xEF, 0x01, 0x00, 0x03, 0x01, 0x00, 0x05};
      Serial1.write(pingPacket, 7);
      Serial1.flush();
      
      delay(100);
      printSerialResponse();
      
    } else if (cmd == "RESET") {
      Serial.println("[CMD] Sending RESET...");
      byte resetPacket[] = {0xEF, 0x01, 0x00, 0x03, 0x0D, 0x00, 0x11};
      Serial1.write(resetPacket, 7);
      Serial1.flush();
      
      delay(100);
      printSerialResponse();
      
    } else if (cmd == "SEND_COMMAND") {
      Serial.println("[CMD] Sending GetParameters command...");
      byte getParamPacket[] = {0xEF, 0x01, 0x00, 0x03, 0x0F, 0x00, 0x13};
      Serial1.write(getParamPacket, 7);
      Serial1.flush();
      
      delay(100);
      printSerialResponse();
      
    } else {
      Serial.print("[ECHO] ");
      Serial.println(cmd);
    }
  }
  
  delay(50);
}

void printSerialResponse() {
  if (Serial1.available()) {
    Serial.print("[RESPONSE] ");
    while (Serial1.available()) {
      byte b = Serial1.read();
      Serial.print(b, HEX);
      Serial.print(" ");
    }
    Serial.println();
  } else {
    Serial.println("[RESPONSE] No data");
  }
}
