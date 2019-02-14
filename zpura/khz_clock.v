// Module to divide a 50 MHz input clock to 1 kHz output clock
module khz_clock(
	input rst,	     // /reset signal	
	input sys_clk,   // 50 MHz system clock input
	output khz_clk); // 1 kHz output clock

	
reg [15:0] div_counter;  // Counter to divide the 50 MHz by 50000

// Keep the output in the first half of the counter low, then high.
assign khz_clk = div_counter < 16'd25000 ? 0 : 1;

always @(sys_clk) begin
	if(~rst) begin  // Reset the divider.
		div_counter <= 16'd0;
	end else begin
		div_counter <= div_counter == 49999 ? 0 : div_counter + 1;
	end
end

endmodule
