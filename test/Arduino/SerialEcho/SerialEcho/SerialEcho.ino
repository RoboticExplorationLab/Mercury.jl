int buf_len = 256;
char buf[256];
int led = 13;
bool led_state = LOW;

void setup() 
{
    Serial.begin(115200);
    Serial.println("serial test 0021"); // so I can keep track of what is loaded
    pinMode(led, OUTPUT);
}

void loop() 
{

//    delay(10);  
    int bytes = Serial.available();

    if (bytes > 0 && bytes < buf_len) 
    {
        Serial.readBytes(buf, bytes);
        delay(1);
        Serial.write(buf, bytes);
        led_state = !led_state; 
    }
}
