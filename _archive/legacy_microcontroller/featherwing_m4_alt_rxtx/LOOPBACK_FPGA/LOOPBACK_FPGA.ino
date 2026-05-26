void setup() {
  Serial.begin(115200);   // USB Debugging
  while (!Serial);

  // Serial1 uses the physical RX/TX pins on the Feather M4
  Serial1.begin(300);     
  
  Serial.println("--- Using Hardware RX/TX Pins (Serial1) ---");
}

void loop() {
  // Trigger FPGA
  if (Serial.available() && Serial.read() == 't') {
    Serial.println("Sending 0xAA to FPGA...");
    Serial1.write(0xAA); 
  }

  // Read from FPGA
  if (Serial1.available()) {
    uint8_t in = Serial1.read();
    Serial.print("Received: 0x");
    Serial.println(in, HEX);
  }
}
