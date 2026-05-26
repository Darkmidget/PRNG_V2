/***************************************************
  UART Test — Feather M4 <-> CMOD A7 FPGA Loopback
  
  The FPGA is programmed to echo back any byte it
  receives. This sketch sends test patterns and
  verifies the FPGA returns them correctly.
  
  Wiring:
    Feather A1 <- CMOD DIP 22 (FPGA TX)
    Feather A4 -> CMOD DIP 23 (FPGA RX)
    Feather GND -- CMOD DIP 25 (GND)
 ****************************************************/

#include "wiring_private.h"

// Serial3 on SERCOM0: A1=RX, A4=TX — connects to FPGA
Uart Serial3(&sercom0, A1, A4, SERCOM_RX_PAD_1, UART_TX_PAD_0);

void SERCOM0_0_Handler() { Serial3.IrqHandler(); }
void SERCOM0_1_Handler() { Serial3.IrqHandler(); }
void SERCOM0_2_Handler() { Serial3.IrqHandler(); }
void SERCOM0_3_Handler() { Serial3.IrqHandler(); }

void setup() {
  Serial.begin(115200);
  unsigned long start = millis();
  while (!Serial && millis() - start < 3000) delay(10);

  Serial.println(F("============================================"));
  Serial.println(F("  Feather M4 <-> CMOD A7 UART Loopback Test"));
  Serial.println(F("============================================"));
  Serial.println();

  Serial3.begin(115200);
  pinPeripheral(A4, PIO_SERCOM_ALT);
  pinPeripheral(A1, PIO_SERCOM_ALT);

  Serial.println(F("UART initialized at 115200 baud"));
  Serial.println(F("Waiting 500ms for FPGA to stabilize..."));
  delay(500);

  // Flush any stale data
  while (Serial3.available()) Serial3.read();

  // Test pattern — mix of values to catch bit errors
  uint8_t patterns[] = {0x00, 0xFF, 0x55, 0xAA, 0x01, 0x80, 
                        0x42, 0xDE, 0xAD, 0xBE, 0xEF, 0x7E};
  int numPatterns = sizeof(patterns);
  int passed = 0;
  int failed = 0;

  Serial.println();
  Serial.println(F("Sending test patterns..."));
  Serial.println(F("--------------------------------------------"));

  for (int i = 0; i < numPatterns; i++) {
    uint8_t sent = patterns[i];
    
    // Clear receive buffer
    while (Serial3.available()) Serial3.read();

    // Send the byte
    Serial3.write(sent);
    Serial3.flush();

    // Wait for echo (with timeout)
    unsigned long timeout = millis() + 200;
    while (!Serial3.available() && millis() < timeout);

    Serial.print(F("  Sent: 0x"));
    if (sent < 0x10) Serial.print("0");
    Serial.print(sent, HEX);

    if (Serial3.available()) {
      uint8_t received = Serial3.read();
      Serial.print(F("  <-  Got: 0x"));
      if (received < 0x10) Serial.print("0");
      Serial.print(received, HEX);

      if (received == sent) {
        Serial.println(F("  [PASS]"));
        passed++;
      } else {
        Serial.println(F("  [FAIL - mismatch]"));
        failed++;
      }
    } else {
      Serial.println(F("        [FAIL - no response]"));
      failed++;
    }

    delay(20);
  }

  Serial.println(F("--------------------------------------------"));
  Serial.print(F("Results: "));
  Serial.print(passed);
  Serial.print(F(" passed, "));
  Serial.print(failed);
  Serial.println(F(" failed"));
  Serial.println();

  if (failed == 0) {
    Serial.println(F("SUCCESS — UART link is working!"));
  } else if (passed == 0) {
    Serial.println(F("FAIL — no communication with FPGA"));
    Serial.println(F("Check:"));
    Serial.println(F("  - FPGA is programmed with loopback bitstream"));
    Serial.println(F("  - A1 connected to CMOD DIP 23 (FPGA RX)"));
    Serial.println(F("  - A4 connected to CMOD DIP 22 (FPGA TX)"));
    Serial.println(F("  - Common ground between boards"));
    Serial.println(F("  - FPGA heartbeat LED (LD1) is blinking"));
  } else {
    Serial.println(F("PARTIAL — some bytes lost or corrupted"));
    Serial.println(F("Possibly a baud rate mismatch or timing issue"));
  }

  Serial.println();
  Serial.println(F("Entering interactive mode..."));
  Serial.println(F("Type in the serial monitor and press Enter."));
  Serial.println(F("Whatever you type will be echoed by the FPGA."));
  Serial.println();
}

void loop() {
  // Forward anything typed in the USB serial monitor to the FPGA
  if (Serial.available()) {
    uint8_t c = Serial.read();
    Serial3.write(c);
  }

  // Forward anything from the FPGA back to the USB serial monitor
  if (Serial3.available()) {
    uint8_t c = Serial3.read();
    Serial.write(c);
  }
}
