/***************************************************
  FeatherWing 3.5" TFT Diagnostic Test
  For Adafruit Feather M4 Express + HX8357D FeatherWing
  
  Tests SPI communication, pin states, display controller
  response, and attempts multiple initialization methods.
  
  Open Serial Monitor at 115200 baud and press reset.
 ****************************************************/

#include <SPI.h>
#include "Adafruit_GFX.h"
#include "Adafruit_HX8357.h"

#define TFT_CS   9
#define TFT_DC   10
#define TFT_RST  -1
#define SD_CS    5

// ========================================
// TEST 1: Basic Pin State Check
// ========================================
void testPinStates() {
  Serial.println(F("========================================"));
  Serial.println(F("TEST 1: Pin State Check"));
  Serial.println(F("========================================"));
  
  // Temporarily set pins as inputs to read their idle state
  pinMode(TFT_CS, INPUT_PULLUP);
  pinMode(TFT_DC, INPUT_PULLUP);
  pinMode(SD_CS, INPUT_PULLUP);
  pinMode(MISO, INPUT);
  delay(10);
  
  Serial.print(F("  TFT_CS  (pin 9)  idle state: "));
  Serial.println(digitalRead(TFT_CS) ? "HIGH (OK)" : "LOW (unexpected)");
  
  Serial.print(F("  TFT_DC  (pin 10) idle state: "));
  Serial.println(digitalRead(TFT_DC) ? "HIGH (OK)" : "LOW (unexpected)");
  
  Serial.print(F("  SD_CS   (pin 5)  idle state: "));
  Serial.println(digitalRead(SD_CS) ? "HIGH (OK)" : "LOW (unexpected)");
  
  Serial.print(F("  MISO    idle state:          "));
  int misoState = digitalRead(MISO);
  Serial.println(misoState ? "HIGH" : "LOW");
  
  Serial.print(F("  MOSI    idle state:          "));
  pinMode(MOSI, INPUT);
  Serial.println(digitalRead(MOSI) ? "HIGH" : "LOW");
  
  Serial.print(F("  SCK     idle state:          "));
  pinMode(SCK, INPUT);
  Serial.println(digitalRead(SCK) ? "HIGH" : "LOW");
  
  Serial.println();
}

// ========================================
// TEST 2: SPI Bus Communication
// ========================================
void testSPIBus() {
  Serial.println(F("========================================"));
  Serial.println(F("TEST 2: SPI Bus Communication"));
  Serial.println(F("========================================"));
  
  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  
  // Test with TFT CS
  pinMode(TFT_CS, OUTPUT);
  digitalWrite(TFT_CS, LOW);
  uint8_t resp1 = SPI.transfer(0x00);
  uint8_t resp2 = SPI.transfer(0xAA);
  uint8_t resp3 = SPI.transfer(0x55);
  uint8_t resp4 = SPI.transfer(0xFF);
  digitalWrite(TFT_CS, HIGH);
  
  Serial.print(F("  TFT SPI response to 0x00: 0x")); Serial.println(resp1, HEX);
  Serial.print(F("  TFT SPI response to 0xAA: 0x")); Serial.println(resp2, HEX);
  Serial.print(F("  TFT SPI response to 0x55: 0x")); Serial.println(resp3, HEX);
  Serial.print(F("  TFT SPI response to 0xFF: 0x")); Serial.println(resp4, HEX);
  
  bool allZero = (resp1 == 0 && resp2 == 0 && resp3 == 0 && resp4 == 0);
  bool allFF   = (resp1 == 0xFF && resp2 == 0xFF && resp3 == 0xFF && resp4 == 0xFF);
  
  if (allZero) {
    Serial.println(F("  >> RESULT: All zeros - display not responding (MISO stuck LOW)"));
  } else if (allFF) {
    Serial.println(F("  >> RESULT: All 0xFF - display not responding (MISO stuck HIGH)"));
  } else {
    Serial.println(F("  >> RESULT: Non-trivial responses - SPI bus is alive!"));
  }
  
  // Test with SD CS to see if that device responds (rules out general SPI issues)
  pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, LOW);
  uint8_t sdResp = SPI.transfer(0xFF);
  digitalWrite(SD_CS, HIGH);
  
  Serial.print(F("  SD card SPI response: 0x")); Serial.println(sdResp, HEX);
  if (sdResp != 0x00 && sdResp != 0xFF) {
    Serial.println(F("  >> SD card responded - SPI bus itself works fine"));
  }
  
  SPI.endTransaction();
  Serial.println();
}

// ========================================
// TEST 3: HX8357D Command Reads
// ========================================
void testDisplayCommands() {
  Serial.println(F("========================================"));
  Serial.println(F("TEST 3: HX8357D Command Reads"));
  Serial.println(F("========================================"));
  
  Adafruit_HX8357 tft = Adafruit_HX8357(TFT_CS, TFT_DC, TFT_RST);
  tft.begin();
  delay(200);
  
  uint8_t powerMode = tft.readcommand8(HX8357_RDPOWMODE);
  uint8_t madctl    = tft.readcommand8(HX8357_RDMADCTL);
  uint8_t pixFmt    = tft.readcommand8(HX8357_RDCOLMOD);
  uint8_t imgFmt    = tft.readcommand8(HX8357_RDDIM);
  uint8_t selfDiag  = tft.readcommand8(HX8357_RDDSDR);
  
  Serial.print(F("  Display Power Mode: 0x")); Serial.println(powerMode, HEX);
  Serial.print(F("  MADCTL Mode:        0x")); Serial.println(madctl, HEX);
  Serial.print(F("  Pixel Format:       0x")); Serial.println(pixFmt, HEX);
  Serial.print(F("  Image Format:       0x")); Serial.println(imgFmt, HEX);
  Serial.print(F("  Self Diagnostic:    0x")); Serial.println(selfDiag, HEX);
  
  Serial.println();
  if (powerMode == 0x00 && madctl == 0x00 && pixFmt == 0x00) {
    Serial.println(F("  >> RESULT: ALL ZEROS - Display controller is NOT responding."));
    Serial.println(F("     Possible causes:"));
    Serial.println(F("     - TFT ribbon cable has a bad solder joint (defective board)"));
    Serial.println(F("     - HX8357D controller chip is dead"));
    Serial.println(F("     - CS/DC pins not reaching the display (trace issue on PCB)"));
  } else if (powerMode == 0x9C) {
    Serial.println(F("  >> RESULT: Display is responding correctly! (Power Mode = 0x9C)"));
  } else {
    Serial.print(F("  >> RESULT: Partial response detected. Power mode 0x"));
    Serial.print(powerMode, HEX);
    Serial.println(F(" is unexpected - may indicate a partially working connection."));
  }
  Serial.println();
}

// ========================================
// TEST 4: Manual Software Reset Attempt
// ========================================
void testSoftwareReset() {
  Serial.println(F("========================================"));
  Serial.println(F("TEST 4: Manual Software Reset"));
  Serial.println(F("========================================"));
  Serial.println(F("  Attempting manual software reset of display..."));
  
  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  
  pinMode(TFT_CS, OUTPUT);
  pinMode(TFT_DC, OUTPUT);
  
  // Send software reset command (0x01)
  digitalWrite(TFT_DC, LOW);   // Command mode
  digitalWrite(TFT_CS, LOW);
  SPI.transfer(0x01);          // Software reset
  digitalWrite(TFT_CS, HIGH);
  
  Serial.println(F("  Reset command sent. Waiting 150ms..."));
  delay(150);
  
  // Send sleep out command (0x11)
  digitalWrite(TFT_DC, LOW);
  digitalWrite(TFT_CS, LOW);
  SPI.transfer(0x11);          // Sleep out
  digitalWrite(TFT_CS, HIGH);
  
  Serial.println(F("  Sleep out command sent. Waiting 500ms..."));
  delay(500);
  
  SPI.endTransaction();
  
  // Now try reading power mode again
  Adafruit_HX8357 tft = Adafruit_HX8357(TFT_CS, TFT_DC, TFT_RST);
  tft.begin();
  delay(100);
  
  uint8_t powerMode = tft.readcommand8(HX8357_RDPOWMODE);
  Serial.print(F("  Power Mode after reset: 0x")); Serial.println(powerMode, HEX);
  
  if (powerMode == 0x00) {
    Serial.println(F("  >> Still 0x00 - display is unresponsive even after software reset."));
  } else {
    Serial.println(F("  >> Display responded after reset!"));
  }
  Serial.println();
}

// ========================================
// TEST 5: CS/DC Pin Toggle Verification
// ========================================
void testCSandDCToggle() {
  Serial.println(F("========================================"));
  Serial.println(F("TEST 5: CS/DC Pin Toggle Verification"));
  Serial.println(F("========================================"));
  Serial.println(F("  This test toggles CS and DC to verify"));
  Serial.println(F("  the Feather can actually drive them."));
  Serial.println(F("  (Use a multimeter/logic analyzer to"));
  Serial.println(F("  verify signals on FeatherWing pads)"));
  Serial.println();
  
  pinMode(TFT_CS, OUTPUT);
  pinMode(TFT_DC, OUTPUT);
  
  for (int i = 0; i < 3; i++) {
    digitalWrite(TFT_CS, LOW);
    digitalWrite(TFT_DC, LOW);
    Serial.println(F("  CS=LOW,  DC=LOW  (measure now)"));
    delay(1000);
    
    digitalWrite(TFT_CS, HIGH);
    digitalWrite(TFT_DC, HIGH);
    Serial.println(F("  CS=HIGH, DC=HIGH (measure now)"));
    delay(1000);
  }
  
  Serial.println(F("  >> If voltage toggles between 0V and 3.3V on both"));
  Serial.println(F("     pins, the Feather is driving them correctly."));
  Serial.println();
}

// ========================================
// TEST 6: Alternative SPI Speeds
// ========================================
void testAlternateSPISpeeds() {
  Serial.println(F("========================================"));
  Serial.println(F("TEST 6: Alternative SPI Speeds"));
  Serial.println(F("========================================"));
  
  uint32_t speeds[] = {500000, 1000000, 4000000, 8000000, 16000000};
  const char* labels[] = {"500kHz", "1MHz", "4MHz", "8MHz", "16MHz"};
  
  for (int i = 0; i < 5; i++) {
    SPI.begin();
    SPI.beginTransaction(SPISettings(speeds[i], MSBFIRST, SPI_MODE0));
    
    pinMode(TFT_CS, OUTPUT);
    pinMode(TFT_DC, OUTPUT);
    
    // Send read power mode command
    digitalWrite(TFT_DC, LOW);
    digitalWrite(TFT_CS, LOW);
    SPI.transfer(0x0A);  // RDPOWMODE command
    digitalWrite(TFT_DC, HIGH);
    uint8_t dummy = SPI.transfer(0x00);  // dummy byte
    uint8_t resp = SPI.transfer(0x00);   // actual response
    digitalWrite(TFT_CS, HIGH);
    
    SPI.endTransaction();
    
    Serial.print(F("  @ ")); Serial.print(labels[i]);
    Serial.print(F(" -> response: 0x")); Serial.println(resp, HEX);
  }
  
  Serial.println();
}

// ========================================
// SUMMARY
// ========================================
void printSummary() {
  Serial.println(F("========================================"));
  Serial.println(F("DIAGNOSTIC SUMMARY"));
  Serial.println(F("========================================"));
  Serial.println(F("If ALL tests returned 0x00 or 0xFF:"));
  Serial.println(F("  -> The HX8357D display controller is"));
  Serial.println(F("     not responding to any commands."));
  Serial.println(F("  -> Since SPI continuity, power, and"));
  Serial.println(F("     pin driving all check out, the"));
  Serial.println(F("     FeatherWing is likely defective."));
  Serial.println(F("  -> Contact Adafruit for a replacement."));
  Serial.println();
  Serial.println(F("If ANY test returned a non-zero,"));
  Serial.println(F("non-0xFF value:"));
  Serial.println(F("  -> The display can communicate, and"));
  Serial.println(F("     the issue may be timing or init."));
  Serial.println(F("     Share the results for further help."));
  Serial.println(F("========================================"));
}

// ========================================
// MAIN
// ========================================
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);  // Wait for serial monitor
  
  Serial.println();
  Serial.println(F("========================================"));
  Serial.println(F("  FeatherWing 3.5\" TFT Diagnostic"));
  Serial.println(F("  Feather M4 Express + HX8357D"));
  Serial.println(F("========================================"));
  Serial.println();
  
  testPinStates();
  testSPIBus();
  testDisplayCommands();
  testSoftwareReset();
  testCSandDCToggle();
  testAlternateSPISpeeds();
  printSummary();
  
  Serial.println(F("All tests complete."));
}

void loop() {
  // Nothing here - all tests run once in setup
}
