//
// Written by Andreas Rueckert <mail@andreas-rueckert.de>
//
// See the VGA example @: fpga4fun.com/PongGame.html
//

// VGA timings see
// http://www.epanorama.net/documents/pc/vga_timing.html

// ToDo-List:
//  - use one of the VGA text timings 720x400 or 640x400
//  - create a c64 compatible 8x16 font
//  - run simulations

module ex80fpga( 
	input reset,
	input clk,  // 50 MHz system clock
	input [31:0] mem_addr,
	input [31:0] data,
	input wren,	 	// Write signal to the vram
	input bus_available,
	output h_sync,
	output v_sync,
	output red,
	output green,
	output blue);
	
	// Define the resolution of the screen
	localparam xres = 640;
	localparam yres = 480;
	
	// The address of the video buffer in ram
	localparam videobuffer_addr = 16'hDC00;
	
	reg [9:0] x_count;  // counter for horizontal sync
	reg [8:0] y_count;	// counter for vertical sync
	
	// Define the length of the sync pulses and porches
	localparam hsynch_len = 96;
	localparam backporch_len = 40;
	localparam frontporch_len = 8;
	localparam topporch_len = 7;
	
	// Create inverted(!) VGA sync signals
	assign v_sync = (y_count == 0);
	assign h_sync = (x_count < hsynch_len);
	
	// Create a screen buffer for the character codes.
	reg [7:0] screenbuffer[0:2047];  // 2 kb buffer
	reg [10:0] screenadr;  // The address of the currently display character
	reg [7:0] charcode;  // The code for the next character to display
	
	// Create a reg, so I can check the address
	reg [15:0] video_addr;
	
	// Create a write buffer, that syncs the c64 and vga controller side
	// Both sides run on different clocks, so the might read and write
	// at the same time, which causes confusion on the busses.
	reg [7:0] writevalue;  // The value to write
	reg [10:0] writeaddress;  // The address to write to.
	reg writetrigger;			// A flag to trigger the next write
	reg bufferwritten;		// Signal a written buffer
	
	// A bitmap font 
	// Taken from https://www.cl.cam.ac.uk/~swm11/examples/bluespec/VGA/
	reg [7:0] font[0:2047]/* synthesis ram_init_file = "fontrom.mif" */;
	
	// A shift register for the currently written char bitmap line
	reg [7:0] cur_char_line;
	
	//
	// Some utility functions
	//
	
	// Check if the beam is currently within a given horizontal range
	// return true, if x1 <= x_count <= x2
	function beamInXrange;
	input x1,x2;
	begin
		beamInXrange = ((x_count >= x1) && (x_count <= x2));
	end
	endfunction
	
	// Check, if the beam is currently within a given vertical range
	// return true, if y1 <= y_count <= y2
	function beamInYrange;
	input y1,y2;
	begin
		beamInYrange = ((y_count >= y1) && (y_count <= y2));
	end
	endfunction
	
	// Check, if the beam is currently within a given area
	function beamInArea;
	input x1,y1,x2,y2;
	begin
		beamInArea = (beamInXrange(x1,x2) && beamInYrange(y1,y2));
	end
	endfunction
	
	// Check, if the beam is currently visible
	`define beamIsVisible (beamInArea(backporch_len,topporch_len,backporch_len+xres-1,topporch_len+yres-1))
				
	// Check, if the beam is at the given horizontal pixel of the font rendering
	function beamIsAtFontPixel;
	input pixnum;
	begin
		beamIsAtFontPixel = (((x_count - backporch_len - 8) % 8) == pixnum);
	end
	endfunction
	
	// End of utility functions
	
	// Assign all the colors to the upper bit of the shift register,
	//	if the beam is in the visible area. Output 0 (black) otherwise.
	assign red = `beamIsVisible ? cur_char_line[7] : 0;
	assign green = `beamIsVisible ? cur_char_line[7] : 0;
	assign blue =  `beamIsVisible ? cur_char_line[7] : 0;
					  
	initial begin
		x_count <= 0;
		y_count <= 0;
		writetrigger <= 0;
		bufferwritten <= 0;
	end
	
	
	// To create a 25 MHz VGA clock, just divide the 50 MHz by 2
	reg vgaclk;
	always @(posedge clk) begin
		vgaclk <= ~vgaclock;
	end
	
	always @(posedge vgaclk) begin
		x_count <= (x_count == 767) ? 0 : x_count + 1;
		y_count <= y_count + 1;
		
		// If there are data to write, copy them to the screen ram
		if( writetrigger == 1 && bufferwritten == 0) begin
			screenbuffer[writeaddress] <= writevalue;  // Write data to screen
			bufferwritten <= 1;  // and signal this write.
		end 
		
		// If the c64 side acknowledged the written buffer, reset flag.
		if( writetrigger == 0) begin 
			bufferwritten <= 0;
		end
		
		// If we are in the first visible line, set the screenadr to pre-0,
		if( y_count == topporch_len && x_count == 1) begin
			screenadr <= 11'b11111111111;
		end
		
		// If we are vertically in the visible area
		if( y_count >= topporch_len && y_count < (topporch_len + yres)) begin
			
			// If we are horizontally in the visible area
			if( beamInXrange(backporch_len - 8, backporch_len + xres - 1)) begin
			
				// Towards the end of a character prepare to display the
				// next character
				if( beamIsAtFontPixel(5)) begin
					screenadr <= screenadr + 1;
				end
				
				// Get the charcode of the next character to display
				if( beamIsAtFontPixel(6)) begin
					charcode <= screenbuffer[screenadr];
				end
				
				// Shift the current font byte or fetch the byte for the next char
				cur_char_line <= beamIsAtFontPixel(7) 
					? font[(charcode << 4) + ((y_count-topporch_len) % 16)]
					: {cur_char_line[6:0],1'b0};				
			end
			
			// At the end of a rasterline, jump 80 bytes back, if a new
			// text line is not started.
			if( x_count == (backporch_len + xres)
				 && ((y_count - topporch_len) % 16) != 4'b1111) begin
				 screenadr <= screenadr - 80;
			end
		end
	end
	
	integer i;
	always @(posedge clk or posedge wren) begin
	
		if( ~reset) begin
		
			// Clear the video mem 
			//for(i=0;i<16'h0800;i=i+1) screenbuffer[i] <= 8'd0;
			writetrigger <= 0;
		end else begin			
			if(wren) begin
				// The cpu writes to the video ram, so copy the data
				// in the write buffer to write them later to the screenram
				//screenbuffer[mem_addr - videobuffer_addr] <= data;
				writevalue <= data;
				writetrigger <= 1;
			end else if( bufferwritten==1 && writetrigger==1) begin	// If the write buffer was written, reset the write trigger.
				writetrigger <= 0;
			end
		end
	end
	
	endmodule
	