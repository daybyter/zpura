/**
 * SPI functions for a simple kernel.
 *
 * Andreas Rueckert <arueckert67@t-online.de>
 */

#include "spi.h"

/* To not depend on a readable control port store the current SPI status in a var. */
uint8_t spi_status;

/**
 * Init the SPI master to access an optional LCD 
 * and especially the SD card to boot.
 */
void spi_init(void) {
  spi_set_status(0);
}

/**
 * Get the current SPI status.
 *
 * @return The current SPI status.
 */
uint8_t spi_get_status(void) {
  return spi_status;  // Do not rely on the SPI control port being readable!
}

/**
 * Set a new SPI status in the control port 
 *
 * @param control_val the control val.
 */
void spi_set_status(uint8_t new_status) {
  spi_status = new_status;  
  *((char *)SPI_CONTROL) = spi_status;
}
