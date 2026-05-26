#include <Arduino.h>

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println(\"\\n\\n================================================\");
  Serial.println(\"=== FEATHER M4 DIAGNOSTIC TEST ===\");
  Serial.println(\"================================================\");
  Serial.println(\"Board is running and serial is working!\");
  Serial.println(\"\");
  Serial.println(\"Testing LED blink...\");
  
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  static uint32_t lastTick = 0;
  uint32_t now = millis();
  
  // Blink every 1 second
  if (now - lastTick >= 1000) {
    lastTick = now;
    
    digitalWrite(LED_BUILTIN, HIGH);
    Serial.println(\"[*] LED ON\");
    delay(250);
    
    digitalWrite(LED_BUILTIN, LOW);
    Serial.println(\"[*] LED OFF\");
  }
  
  // Check for serial commands
  if (Serial.available()) {
    char c = Serial.read();
    Serial.print(\"You pressed: \");
    Serial.println(c);
  }
  
  delay(10);
}
