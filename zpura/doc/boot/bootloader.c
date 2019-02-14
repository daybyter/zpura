/**
 * This is an attempt to write a bootloader for the
 * zpura cpu running on an de0 nano fpga board.
 *
 * Andreas Rueckert <arueckert67@t-online.de>
 */

#define MEMSIZE (16*1024*1024)  /* Use 16 MB of the 32 MB for now */


/**
 * Main entry point of the kernel.
 */
int main(int argc, char *argv[]) {
  spi_init();  /* Init SPI controller, so we can output some debugging and log info */
}
