/**
 * SPI functions for a simple kernel.
 *
 * Andreas Rueckert <arueckert67@t-online.de>
 */

#ifndef _SPI_H_
#define _SPI_H_


/* Addresses of the SPI data and controlport */
#define SPI_DATA (1024*1024*1024) /* Memory mapped at 1GB for now */
#define SPI_CONTROL (SPI_DATA+1)  /* Control port for SPI */
#define SPI_CLK_SPEED (1)         /* Select clock speed. 0 means <400kHz. 1 is fullspeed.*/
#define SPI_CS_1 (1 << 4)         /* Chipselect for SPI device 1 of 4 */
#define SPI_CS_2 (1 << 5)         /*   "                       2      */
#define SPI_CS_3 (1 << 6)         /*                           3      */
#define SPI_CS_4 (1 << 7)         /*                           4      */

/* To not depend on a readable control port store the current SPI status in a var. */
extern uint8_t spi_status;

/**
 * Init the SPI master to access an optional LCD 
 * and especially the SD card to boot.
 */
void spi_init(void);

/**
 * Get the current SPI status.
 *
 * @return The current SPI status.
 */
uint8_t spi_get_status(void);

/**
 * Set a new SPI status in the control port 
 *
 * @param control_val the control val.
 */
void spi_set_status(uint8_t new_status);

#endif
