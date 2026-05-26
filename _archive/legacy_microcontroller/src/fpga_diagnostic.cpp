/***************************************************
  FPGA Diagnostic — UART Communication Test
  
  Tests binary communication with FPGA:
  1. Sends test frame: [0x42, 0x69, 0xFF]
  2. Waits for 2-byte response (random seed from LFSR_NL)
  3. Prints result to USB Serial
  
  Expected FPGA behavior:
  - RX: Variable-length bytes terminated by 0xFF
  - Uses first 2 bytes as seed for randomization
  - TX: 16-bit random output (little-endian)
  
  Wiring (Feather M4 A1/A4 to FPGA DIP 22/23):
    Feather A1 (RX) <- FPGA DIP 22 (TX)
    Feather A4 (TX) -> FPGA DIP 23 (RX)
    Feather GND     -- FPGA DIP 25 (GND)
 ****************************************************/

#include <Arduino.h>
#include "wiring_private.h"

// Serial3 on SERCOM0: A1=RX, A4=TX
Uart Serial3(&sercom0, A1, A4, SERCOM_RX_PAD_1, UART_TX_PAD_0);

void SERCOM0_0_Handler() { Serial3.IrqHandler(); }
void SERCOM0_1_Handler() { Serial3.IrqHandler(); }
void SERCOM0_2_Handler() { Serial3.IrqHandler(); }
void SERCOM0_3_Handler() { Serial3.IrqHandler(); }

void setup() {
  // USB Serial for debugging
  Serial.begin(115200);
  
  // Initialize Serial3 for FPGA communication first
  Serial3.begin(115200);
  pinPeripheral(A1, PIO_SERCOM_ALT);
  pinPeripheral(A4, PIO_SERCOM_ALT);
  
  // Give everything time to stabilize
  delay(1000);
  
  Serial.println(F("\n============================================"));
  Serial.println(F("   FPGA Diagnostic — UART Communication"));
  Serial.println(F("============================================\n"));
  Serial.flush();
  
  Serial.println(F("[DIAG] Serial3 initialized at 115200 baud"));
  Serial.println(F("[DIAG] FPGA stabilized, starting tests...\n"));
  Serial.flush();
  
  delay(500);

  // ========== Test 1: Simple test frame ==========
  Serial.println(F("========== TEST 1: Simple Test Frame =========="));
  Serial.println(F("Sending: [0x42, 0x69, 0xFF]"));
  
  // Clear RX buffer
  while (Serial3.available()) Serial3.read();
  
  // Send test frame
  Serial3.write(0x42);
  Serial3.write(0x69);
  Serial3.write(0xFF);
  Serial3.flush();
  
  Serial.println(F("Frame sent. Waiting for response..."));
  
  // Wait for 2-byte response with timeout
  unsigned long timeout = millis() + 1000;  // 1 second timeout
  uint8_t received[2];
  int bytesReceived = 0;
  
  while (bytesReceived < 2 && millis() < timeout) {
    if (Serial3.available()) {
      received[bytesReceived] = Serial3.read();
      Serial.print(F("  Received byte "));
      Serial.print(bytesReceived);
      Serial.print(F(": 0x"));
      if (received[bytesReceived] < 0x10) Serial.print("0");
      Serial.println(received[bytesReceived], HEX);
      bytesReceived++;
    }
    delay(10);
  }
  
  if (bytesReceived == 2) {
    uint16_t randomSeed = (received[1] << 8) | received[0];  // Little-endian
    Serial.print(F("✓ SUCCESS: Received 16-bit seed = 0x"));
    if (randomSeed < 0x1000) Serial.print("0");
    Serial.println(randomSeed, HEX);
  } else {
    Serial.print(F("✗ TIMEOUT: Only received "));
    Serial.print(bytesReceived);
    Serial.println(F(" bytes (expected 2)"));
  }
  
  delay(500);
  
  // ========== Test 2: Multiple frames ==========
  Serial.println(F("\n========== TEST 2: Multiple Frames =========="));
  
  uint8_t testFrames[][3] = {
    {0x00, 0x00, 0xFF},
    {0xFF, 0xFF, 0xFF},
    {0x55, 0xAA, 0xFF},
    {0xAA, 0x55, 0xFF},
    {0x12, 0x34, 0xFF}
  };
  
  int numFrames = sizeof(testFrames) / sizeof(testFrames[0]);
  int passCount = 0;
  
  for (int i = 0; i < numFrames; i++) {
    Serial.print(F("\nFrame "));
    Serial.print(i + 1);
    Serial.print(F(": [0x"));
    if (testFrames[i][0] < 0x10) Serial.print("0");
    Serial.print(testFrames[i][0], HEX);
    Serial.print(F(", 0x"));
    if (testFrames[i][1] < 0x10) Serial.print("0");
    Serial.print(testFrames[i][1], HEX);
    Serial.println(F(", 0xFF]"));
    
    // Clear RX buffer
    while (Serial3.available()) Serial3.read();
    
    // Send frame
    Serial3.write(testFrames[i][0]);
    Serial3.write(testFrames[i][1]);
    Serial3.write(testFrames[i][2]);
    Serial3.flush();
    
    // Wait for response
    timeout = millis() + 1000;
    bytesReceived = 0;
    memset(received, 0, 2);
    
    while (bytesReceived < 2 && millis() < timeout) {
      if (Serial3.available()) {
        received[bytesReceived] = Serial3.read();
        bytesReceived++;
      }
      delay(10);
    }
    
    if (bytesReceived == 2) {
      uint16_t seed = (received[1] << 8) | received[0];
      Serial.print(F("  Response: 0x"));
      if (seed < 0x1000) Serial.print("0");
      Serial.print(seed, HEX);
      Serial.println(F(" ✓"));
      passCount++;
    } else {
      Serial.println(F("  Response: TIMEOUT ✗"));
    }
    
    delay(100);
  }
  
  Serial.println(F("\n========== TEST RESULTS =========="));
  Serial.print(F("Passed: "));
  Serial.print(passCount);
  Serial.print(F(" / "));
  Serial.println(numFrames);
  
  if (passCount == numFrames) {
    Serial.println(F("✓ All tests PASSED. FPGA communication is working!"));
  } else if (passCount > 0) {
    Serial.println(F("⚠ PARTIAL: Some frames timed out. Check FPGA status."));
  } else {
    Serial.println(F("✗ All tests FAILED. No communication with FPGA."));
    Serial.println(F("\nDiagnostic checklist:"));
    Serial.println(F("  1. FPGA is programmed with LFSR_NL bitstream"));
    Serial.println(F("  2. Feather A4 connected to FPGA DIP 22 (TX)"));
    Serial.println(F("  3. Feather A1 connected to FPGA DIP 23 (RX)"));
    Serial.println(F("  4. Common ground (GND) connected"));
    Serial.println(F("  5. FPGA has power and is not in reset"));
  }
  
  Serial.println(F("\n============================================"));
  Serial.println(F("Diagnostic complete. Entering monitor mode."));
  Serial.println(F("Send bytes in Serial Monitor (0-255) and watch responses."));
  Serial.println(F("============================================\n"));
}

void loop() {
  // Repeat test every 3 seconds so monitor can see results
  static unsigned long lastTest = 0;
  
  if (millis() - lastTest > 3000) {
    lastTest = millis();
    
    Serial.println(F("\n========== AUTO TEST =========="));
    
    // Test pattern
    uint8_t testFrames[][3] = {
      {0x00, 0x00, 0xFF},
      {0xFF, 0xFF, 0xFF},
      {0x55, 0xAA, 0xFF}
    };
    
    int testIdx = (millis() / 3000) % 3;  // Cycle through 3 tests
    uint8_t b0 = testFrames[testIdx][0];
    uint8_t b1 = testFrames[testIdx][1];
    
    Serial.print(F("Sending [0x"));
    if (b0 < 0x10) Serial.print("0");
    Serial.print(b0, HEX);
    Serial.print(F(", 0x"));
    if (b1 < 0x10) Serial.print("0");
    Serial.print(b1, HEX);
    Serial.println(F(", 0xFF]"));
    Serial.flush();
    
    // Clear RX buffer
    while (Serial3.available()) Serial3.read();
    
    // Send frame
    Serial3.write(b0);
    Serial3.write(b1);
    Serial3.write(0xFF);
    Serial3.flush();
    
    // Wait for response
    unsigned long timeout = millis() + 1000;
    uint8_t received[2];
    int bytesReceived = 0;
    
    while (bytesReceived < 2 && millis() < timeout) {
      if (Serial3.available()) {
        received[bytesReceived] = Serial3.read();
        bytesReceived++;
      }
      delay(10);
    }
    
    if (bytesReceived == 2) {
      uint16_t seed = (received[1] << 8) | received[0];
      Serial.print(F("Response: 0x"));
      if (seed < 0x1000) Serial.print("0");
      Serial.println(seed, HEX);
    } else {
      Serial.println(F("Response: TIMEOUT"));
    }
    Serial.println(F("========== END TEST =========="));
    Serial.flush();
  }
  
  // Interactive mode: user can type 'T' to send test
  if (Serial.available()) {
    char c = Serial.read();
    
    if (c == 'T' || c == 't') {
      Serial.println(F("\n[MANUAL] Sending test frame [0x42, 0x69, 0xFF]..."));
      Serial.flush();
      
      while (Serial3.available()) Serial3.read();
      
      Serial3.write(0x42);
      Serial3.write(0x69);
      Serial3.write(0xFF);
      Serial3.flush();
      
      unsigned long timeout = millis() + 1000;
      uint8_t received[2];
      int bytesReceived = 0;
      
      while (bytesReceived < 2 && millis() < timeout) {
        if (Serial3.available()) {
          received[bytesReceived] = Serial3.read();
          bytesReceived++;
        }
        delay(10);
      }
      
      if (bytesReceived == 2) {
        uint16_t seed = (received[1] << 8) | received[0];
        Serial.print(F("Response: 0x"));
        if (seed < 0x1000) Serial.print("0");
        Serial.println(seed, HEX);
      } else {
        Serial.println(F("Response: TIMEOUT"));
      }
      Serial.flush();
    }
  }
  
  delay(100);  // Prevent tight loop
}
