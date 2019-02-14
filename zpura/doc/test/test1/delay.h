/**
 * zpura test software.
 *
 * (c) Andreas Rueckert <arueckert67@t-online.de>
 */

#ifndef _DELAY_H_
#define _DELAY_H_

// The address of the timer countdown register.
volatile unsigned int *countdown_adr = (unsigned int *)0x40000008;

/**
 * Delay method.
 *
 * @param ms The number of milliseconds to delay.
 */
void delay(unsigned int ms);

#endif
