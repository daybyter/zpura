/**
 * zpura test software.
 *
 * (c) Andreas Rueckert <arueckert67@t-online.de>
 */

#include "delay.h"

/**
 * Delay method.
 *
 * @param ms The number of milliseconds to delay.
 */
void delay(unsigned int ms) {

  // Write the delay to the countdown register.
  *countdown_adr = ms;

  // Wait until the timer counted down to 0.
  while( *countdown_adr > 0);
}
