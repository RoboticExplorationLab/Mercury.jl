#define ledPin 13

void setup() {
  // put your setup code here, to run once:
  pinMode(ledPin, OUTPUT);
  Serial.begin(57600);
}

void blink() {
  digitalWrite(ledPin, HIGH);
  delay(50);
  digitalWrite(ledPin, LOW);
  delay(50);
}

void numblink(int n) {
  for (int i = 0; i < n; ++i) {
    blink();
  }
}

void loop() {
  // put your main code here, to run repeatedly:
  uint8_t val = 0;
  while (Serial.available()) {
    val = Serial.read();
  }
  if (val) {
    Serial.print("Blinking ");
    Serial.print(val);
    Serial.println(" times");
    numblink(val);
  }
    
  

//  for (int i = 0; i < 5; ++i) {
//    Serial.print("Blinking ");
//    Serial.print(i);
//    Serial.println(" times");
//    numblink(i);
//    delay(5000);
//  }
}
