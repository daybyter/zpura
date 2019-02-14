// SPI master 
module spi_master(
		input rst,	// Main reset signal
		input clk,	// 50 MHz FPGA clocking
		output spi_clk  // 390 kHz or 6.25 MHz SPI clock.
);


reg [3:0] spi_control;  // Control register for the SPI master
// bits for the control register
localparam spi_clk_on=1,	// bit 0 turns spi clk on
spi_clk_high=2;			// bit 1 switches from 390 kHz to 6.25 MHz
reg [7:0] spi_data;		// Data register for the SPI transfer
reg [7:0] clk_divider;  // Counter to divide the 50 MHz clock

assign spi_clk=spi_control[0] & clk_divider[ spi_control[1] ? 3: 7];

always @(clk) begin
	if(~rst) begin
		clk_divider <= 0;
		spi_control <= 0;
		spi_data <= 0;
	end else begin
		clk_divider <= clk_divider + 1;
	end
end

endmodule
