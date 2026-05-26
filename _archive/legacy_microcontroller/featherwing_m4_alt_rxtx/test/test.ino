#include <Arduino.h>
#include "wiring_private.h" // Required for pinPeripheral()

// =============================================================================
// CORRECTED FOR ADAFRUIT FEATHER M4 EXPRESS
// Using SERCOM4 on Pins A2 (TX) and A3 (RX)
// =============================================================================
// For the Feather M4 Express, pins A2 and A3 use SERCOM4
Uart loopbackSerial(&sercom4, A3, A2, SERCOM_RX_PAD_1, UART_TX_PAD_0);

// SERCOM 4 interrupt handlers
void SERCOM4_0_Handler() { loopbackSerial.IrqHandler(); }
void SERCOM4_1_Handler() { loopbackSerial.IrqHandler(); }
void SERCOM4_2_Handler() { loopbackSerial.IrqHandler(); }
void SERCOM4_3_Handler() { loopbackSerial.IrqHandler(); }

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);
  
  Serial.println("--- FEATHER M4 EXPRESS: SERCOM4 LOOPBACK ---");
  Serial.println("Testing Pins: A2 (TX) -> A3 (RX)");
  Serial.println("Make sure A2 and A3 are connected with a jumper wire!");
  
  loopbackSerial.begin(9600);
  
  // For SERCOM4 on A2/A3, use PIO_SERCOM_ALT (column D in the datasheet) [citation:2][citation:3]
  pinPeripheral(A2, PIO_SERCOM_ALT);  // A2 as TX
  pinPeripheral(A3, PIO_SERCOM_ALT);  // A3 as RX
}

void loop() {
  static uint8_t testByte = 0xAA;
  
  Serial.print("Sending: 0x");
  Serial.println(testByte, HEX);
  
  // Clear any pending data in the receive buffer before sending
  while (loopbackSerial.available()) {
    loopbackSerial.read();
  }
  
  loopbackSerial.write(testByte);
  loopbackSerial.flush();  // Wait for transmission to complete
  
  delay(50);  // Small delay for the signal to travel through the jumper
  
  if (loopbackSerial.available()) {
    uint8_t received = loopbackSerial.read();
    Serial.print("SUCCESS! Received: 0x");
    Serial.println(received, HEX);
    
    if (received == testByte) {
      Serial.println("MATCH: Loopback working correctly!");
      testByte++;  // Increment to test different values
    } else {
      Serial.println("ERROR: Data mismatch - check baud rate");
    }
  } else {
    Serial.println("FAILURE: No response - check:");
    Serial.println("  1. Jumper wire between A2 and A3");
    Serial.println("  2. Physical connection is secure");
  }
  
  Serial.println("---------------------------------------");
  delay(1000);
}
