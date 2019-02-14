// Memory bus for the zpura project
module memory_controller(
	input rst,
	input clk,
	input [31:0] mem_adr,  // Address of the 32 bit mem dword in bytes(!)
	inout [31:0] data,
	input wren,	     // Write enable
	output rdy, // Memory transfer complete
	input cs,		 // Chip select for this chip
	output error	 // Needed to pass sigsev back to the CPU
	
	// These pins are connected to the sdram
	/*output [1:0]  sdram_ba_pad_o,
   output [12:0] sdram_a_pad_o,
   output        sdram_cs_n_pad_o,
   output        sdram_ras_pad_o,
   output        sdram_cas_pad_o,
   output        sdram_we_pad_o,
   inout  [15:0] sdram_dq_pad_io,
   output [1:0]  sdram_dqm_pad_o,
   output        sdram_cke_pad_o,
	output 		  sdram_clk_pad_o	 */
	); 
		
localparam CPURAMSIZE=8*1024*1024;  // 8 mio 32 bit words = 32 MB
localparam BOOTROMSIZE = 256;  // 1 KB bootrom
localparam BOOTROM_ADR = 256*1024*1024;  // 256 MB Quadwords = 1 GByte
localparam EMULATIONROMSIZE = 256;  // 256 DWords = 1 kb 
localparam EMULATIONROM_ADR = 0;
localparam EMULATION_ACTIVATE = 1;  // Activate the emulation ROM overlay.

// Flag to check, if an address in in the RAM area
wire isInCPURAM;
assign isInCPURAM = mem_adr < CPURAMSIZE;

// Flag to check, if an address is in the boot ROM
// I put the boot ROM at 1GB here.
wire isInBOOTROM;
assign isInBOOTROM = (mem_adr >= BOOTROM_ADR) && (mem_adr < (BOOTROM_ADR + BOOTROMSIZE));

// Create a small boot rom directly here for easier debugging
reg [31:0] rom [0:BOOTROMSIZE-1];

// Flag to check, if an address in the emulator ROM
wire isInEmulationROM;
assign isInEmulationROM = (EMULATION_ACTIVATE==1) && (mem_adr >= EMULATIONROM_ADR) && (mem_adr < EMULATIONROMSIZE);

// Create a small emulation ROM for the 32 optional opcodes
reg [31:0] emulation_rom[0:EMULATIONROMSIZE-1];

// If we are not in the RAM or ROM, we have an error
assign error = !isInBOOTROM && !isInCPURAM && !isInEmulationROM;

// Buffer for the rdy signal
reg rdy_out;
assign rdy = rdy_out ? rdy_out : 1'bz;

// The various memory types
//rom2 bootRom(mem_adr[7:0],clk,data);  // Boot ROM
reg hiword;  // Flag for high or lo-word, since sdram is 16-bit
wire sd_rd_ready;
wire sd_busy;
reg sd_wren,sd_rden;
reg [31:0] sd_data_buffer;  // Buffer for the 2x 16 bit sdram data.
wire [15:0] sd_data;
reg [15:0] sd_data_out;
assign sd_data = sd_wren ? sd_data_out : 16'bz;
sdram_controller sdram({mem_adr[22:0],hiword}
,sd_data
,sd_wren,
{mem_adr[22:0],hiword}
,sd_data
,sd_rd_ready
,sd_rden
,sd_busy
,rst
,clk);

reg [2:0] state;  // State of the memory controller
localparam state_avail=3'd0,
state_rd_rom=3'd1,
state_rd_sdram_lo=3'd2,
state_rd_sdram_hi=3'd3,
state_wr_sdram_lo=3'd4,
state_wr_sdram_hi=3'd5,
state_wr_sdram_complete=3'd6,
state_sdread_complete=3'd7;

// Output the data, when SD read is complete.
assign data = cs && rdy && ~wren ? sd_data_buffer : 32'bZ;

always @(posedge clk) begin
	if(~rst) begin
		rdy_out <= 1'b1;
		state <= state_avail;
	end else begin
		case(state)
			state_avail: begin
				if(cs && ~wren && isInBOOTROM) begin
					// ToDo: subtract the real offset of the boot rom here?
					sd_data_buffer <= rom[mem_adr[9:2]];  // Assign the data quickly to the output.
					state <= state_rd_rom;
				end
				if(cs && ~wren && isInEmulationROM) begin
					sd_data_buffer <= emulation_rom[mem_adr[9:2]];
					state <= state_rd_rom;
				end
				if(cs && ~wren && isInCPURAM) begin  // Read from sdram
					hiword <= 1'b0;
					state <= state_rd_sdram_hi;
				end
				if(cs && wren && isInCPURAM) begin
					hiword <= 1'b0;
					state <= state_wr_sdram_hi;
				end
			end
			state_rd_rom: begin
				state <= state_avail;
				rdy_out <= 1'b1;
			end
			state_rd_sdram_hi: begin  // Read upper dword
				if(~sd_busy && sd_rd_ready) begin // If the SDRam delivered the upper 16 bits...
					sd_data_buffer[31:16] <= sd_data;
					state <= state_rd_sdram_lo;
					hiword <= 1'b1;
					sd_rden <= 1'b1;
				end
			end
			state_rd_sdram_lo: begin  // Read the lower dword.
				if(~sd_busy && sd_rd_ready) begin  // If the SDRam delivered the lower 16 bits...
					sd_data_buffer[15:0] <= sd_data;
					rdy_out <= 1;
					state <= state_sdread_complete;
				end
			end
			state_sdread_complete: begin  // Just make the SD Ram available for the next read
					state <= state_avail;
					sd_rden <= 1'b0;  
			end
			state_wr_sdram_hi: begin // Write upper dword
				if(~sd_busy) begin // If the SDRam delivered the upper 16 bits...
					sd_data_out <= data[31:16];
					state <= state_wr_sdram_lo;
					hiword <= 1'b0;
					sd_wren <= 1'b1;
				end
			end
			state_wr_sdram_lo: begin // Write lower dword
				if(~sd_busy) begin // If the SDRam wrote the upper 16 bits...
					sd_data_out <= data[15:0];
					state <= state_wr_sdram_complete;
					hiword <= 1'b0;
					sd_wren <= 1'b1;
				end
			end
			state_wr_sdram_complete: begin
				if(~sd_busy) begin  // When the sdram write the 2nd dword
					state <= state_avail;  // Make the controller available again.
					sd_wren <= 1'b0;
				end
			end
		endcase
	end
end

endmodule