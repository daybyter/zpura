/**
 * Blink test for zpura implementation
 * 
 * Andreas Rueckert <arueckert67@t-online.de>
 */

// Pointer to the address, where the LEDs are controlled
volatile unsigned int *led_adr = (unsigned int *)0x40000000;

int main( int argc, char *argv[]) {
  unsigned int led_status = 0;

  while(1) {
    *led_adr = led_status;     // Set new LED status.
    led_status = ~led_status;  // Switch LED status.
    delay(500);                // Wait 0.5 s
  }
}
