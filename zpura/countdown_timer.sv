// Countdown timer counting milliseconds

module countdown_timer #(parameter TIMER_ADR=32'h80080008) ( 
	input rst,
	input clk,
	input wren,  // Write enable
	input rd,	 // Read enable
	input [31:0] address,   // The address to write to or read from
	inout [31:0] data);
	
localparam CLK_FQ = 50000;  // de0 runs at 50 MHz

reg [31:0] timer;  // The current timer value

assign data = wren || ~rd ? 32'bZ : timer;

reg [15:0] divider;  // Divide 50 MHz to 1 ms

always @(posedge clk) begin
	if(~rst) begin
		divider <= 0;
		timer <= 0;
	end else begin
		if(wren && address==TIMER_ADR) begin
			divider <= 0;
			timer <= data;
		end else begin
			if(divider < CLK_FQ) begin
				divider <= divider + 1;
			end else begin
				divider <= 0;
				if(timer > 0) begin
					timer <= timer - 1;
				end
			end
		end
	end
end
	
endmodule