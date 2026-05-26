#include <Arduino.h>

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("\n\n=== DIAGNOSTIC TEST ===");
  Serial.println("Board is running!");
  Serial.println("If you see this, serial is working.");
  
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(500);
  Serial.println("Tick");
  
  digitalWrite(LED_BUILTIN, LOW);
  delay(500);
  Serial.println("Tock");
}
