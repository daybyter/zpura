// Simple Zylin CPU implementation
// by A. Rueckert <arueckert67@t-online.de>

module zpura #(parameter RAM_SIZE=4*1024*1024,ROM_SIZE=1024) ( 
	input rst,
	input clk,
	input cpu_pause,	// Pause the cpu by setting this to high
	
	// These pins are connected to the SDRam
	/* output [1:0]  sdram_ba_pad_o,
   output [12:0] sdram_a_pad_o,
   output        sdram_cs_n_pad_o,
   output        sdram_ras_pad_o,
   output        sdram_cas_pad_o,
   output        sdram_we_pad_o,
   inout  [15:0] sdram_dq_pad_io,
   output [1:0]  sdram_dqm_pad_o,
   output        sdram_cke_pad_o,
	output 		  sdram_clk_pad_o, */
	
	output reg [3:0] error_status,
	output reg led1);
	
wire [31:0] memory_adr;
wire [31:0] databus;  // The data bus from CPU to RAM.
reg mem_write;  // Write to memory
reg mem_cs;	    // Memory chip select
reg mem_ready;
wire mem_error;

// To write to the memory, we just assign the output,
// when the write signal is active.
reg [31:0] databus_out;
assign databus = mem_write ? databus_out : 32'bz;

memory_controller mem_controller(
	rst,
	clk,
	memory_adr,  // Address of the 32 bit mem dword
	databus,
	mem_write,	// Write enable
	mem_ready, 	// Memory transfer complete
	mem_cs,
	mem_error);	// Signal segment violation.
		
localparam error_no_error            = 4'd0;                // No error occured
localparam error_stack_too_empty     = error_no_error + 4'd1;  // Not enough elements on the stack.
localparam error_illegal_instruction = error_stack_too_empty + 4'd1;
	
reg [31:0] sp;  // stackpointer
reg [27:0] n_stack_elems;  // The number of elements on the stack
reg [31:0] pc;    // program counter

//wire rom_oe;
//assign rom_oe = pc >= 32'h100000 && pc < 32'd100100;
//rom #(.mem_width(32),.adr_bits(8)) bootRom(clk,pc[7:0],databus,rom_oe);
//rom2 bootRom(pc[7:0],clk,databus);

reg [31:0] blk_ram [0:ROM_SIZE-1] /* synthesis syn_ramstyle = "M9K,no_rw_check" */;  // Some pre-initialized ram to start the CPU.

// The states for the CPU execution
reg [2:0] state;  // The main state of the cpu
localparam state_error       = 3'd0; // The CPU is halted
localparam state_fetch_code  = 3'd1; // CPU fetches code
localparam state_exec        = 3'd2; // Exec the instruction
localparam state_fetch_ucode = 3'd3; // Fetch the next ucode opcode
localparam state_run_ucode   = 3'd4; // Run the ucode for an instruction

reg [7:0] opcode;  // The currently executed instruction
reg idim_flag;  // Flag to signal, that the last instruction was a IM.

// Function to check, if the stack contains enough data
/*
function checkStackData;
	input requiredParam;  // Number of required parameters.
	
	if(n_stack_elems < requiredParam) begin 
		error_status <= error_stack_too_empty;
		state <= state_error;
		checkStackData = 0;
	end else begin
		checkStackData = 1;
	end
endfunction
*/

reg [5:0] upc;          // Microcode program counter
integer curUCbit;       // Current ucode bit in instruction
(* ramstyle="M9K" *) reg [11:0] ucode[0:47]; // Define a microcode program
reg [11:0] uopcode;     // The current ucode opcode.
integer curUCode;       // Current ucode operation in ucode ROM


// The start addresses of the ucodes for each assembler instruction
reg [5:0] uc_adr[0:16];  // 17 basic ZPU instructions

// Init the test code
initial begin   

// Definitions for a proper microcode
curUCbit=0;

// Flag to indicate end of ucode task
`define uc_xtask (1 << curUCbit)  

// Bits to modify the stack pointer
`define SP_OP_NOP    0        // Leave stackpointer untouched
`define SP_OP_INC    1        // Increment stackpointer by 4 byte
`define SP_OP_DEC    2        // Decrement stackpointer by 4 byte
`define SP_OP_DEC_NOT_IDIM 3  // DEC stackpointer, if idim_flag not set

curUCbit=curUCbit+2;
`define uc_modSP(spOp) ((1<<curUCbit)|(spOp << (curUCbit-1)))

// A list of of memory access states
`define uc_MEM_CYC_COMPLETE 0  // Memory access complete
`define uc_MEM_CYC_CHECK    1  // Check, if the mem cycle is complete
`define uc_MEM_CYC_START	 2  // Start a new mem cycle

// A list of ALU related move operations
`define uc_ALU_MV_NOP       0   // Do not move anything
`define uc_ALU_MV_POP_A     (1+(`uc_MEM_CYC_START<<4))   // Pop ALU input a from stack
`define uc_ALU_MV_POP_B     (2+(`uc_MEM_CYC_START<<4))   // Pop ALU input b from stack
`define uc_ALU_MV_PUSH_OUT  (3+(`uc_MEM_CYC_START<<4))   // Push ALU out to stack
`define uc_ALU_MV_OUT_A     4   // mov ALU out to input a
`define uc_ALU_MV_MEM_OUT_A (5+(`uc_MEM_CYC_START<<4))   // Mov alu_a=mem[alu_out]
`define uc_ALU_MV_A_MEM_OUT (6+(`uc_MEM_CYC_START<<4))   // Mov mem[out]=a
`define uc_ALU_MV_IM		    7   // Mov an immediate to input a and the potential extension to b
`define uc_ALU_MV_SP_A		 8   // alu_a = sp 
`define uc_ALU_MV_OUT_SP    9   // sp = alu_out
`define uc_ALU_MV_OUT_PC   10   // pc = alu_out
`define uc_ALU_MV_PC_A		11   // Mov alu_a=PC  
`define uc_ALU_MV_OPC_A		11   // Mov the lower 5 bits of the opcode to a with the msb inverted.
`define uc_ALU_MV_EMU_A	   12   // Mov the lower 5 bits to a _without_ MSB inverted

curUCbit=curUCbit+6;
`define uc_setALU_MV(op) ((op) << curUCbit)

// Set an ALU operation
curUCbit=curUCbit+3;
`define uc_setALUop(op) (op<<curUCbit)
`define uc_ALU_OP_NOP  0  // Leave out untouched
`define uc_ALU_OP_COPY 1  // Copy operation : out = a
`define uc_ALU_OP_ADD  2  // Add : out = a + b
`define uc_ALU_OP_AND  3  // And : out = a & b
`define uc_ALU_OP_OR   4  // Or  : out = a | b
`define uc_ALU_OP_NOT  5  // Not : out = ~a;
`define uc_ALU_OP_FLIP 6  // Flip : out = flip(a);

// Now write the ucodes to the ucode rom
curUCode=0;
`define startCPUInstruction(num) uc_adr[num]=6'(curUCode)

// Macro to add a new ucode instruction to the ucode ROM
`define ucodeInstr(instr) ucode[curUCode]<=12'(instr);\
curUCode=curUCode+1

`startCPUInstruction(0);  // Breakpoint
// Call IRQ handler at address 0 in this case for now.
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PC_A) | `uc_setALUop(`uc_ALU_OP_COPY) | `uc_modSP(`SP_OP_DEC));  // Mov alu_a=pc und dec(sp) for following stackpush of PC
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT));  // Push PC to stack
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_EMU_A) | `uc_setALUop(`uc_ALU_OP_COPY));  // Fetch the lower 5 bits (all 0 here) of the opcode and copy them to alu_out.
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_OUT_PC) | `uc_xtask); // Set PC=alu_out and end task.

`startCPUInstruction(1);  // uCode for the IM x instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_IM) | `uc_setALUop(`uc_ALU_OP_OR) | `uc_modSP(`SP_OP_DEC_NOT_IDIM)); // Get the immediate from the opcode, the extension from the stack and or them
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);  // Push the result to the stack and end the task.

`startCPUInstruction(2);  // STORESP x
// mem[sp + x << 2] = mem[sp]; sp = sp + 1;
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_OPC_A) | `uc_setALUop(`uc_ALU_OP_ADD));  // Add offset + sp
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_NOP) | `uc_modSP(`SP_OP_INC));  // leave the result in alu_out, mv TOS to alu_a and inc(sp)
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_A_MEM_OUT) | `uc_xtask);

`startCPUInstruction(3);  // LOADSP x
// mem[sp-1]=mem[sp + x << 2]; sp = sp-1;
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_OPC_A) | `uc_setALUop(`uc_ALU_OP_ADD));  // Add offset + sp
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_MEM_OUT_A) | `uc_setALUop(`uc_ALU_OP_COPY) | `uc_modSP(`SP_OP_DEC));  // mv the result to alu_a, dec(sp) and copy the result to alu_out
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);  // Push the result to the stack and end the task.

`startCPUInstruction(4);  // ADDSP x
// mem[sp] = mem[sp] + mem[sp + x << 2];
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_OPC_A) | `uc_setALUop(`uc_ALU_OP_ADD));  // Add offset + sp
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_MEM_OUT_A));  // mv alu_a=mem[alu_out]
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_B) | `uc_setALUop(`uc_ALU_OP_ADD));  // Add TOS to the result.
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);  // Push result to stack and end task.

`startCPUInstruction(5);  // EMULATE x
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PC_A) | `uc_setALUop(`uc_ALU_OP_COPY) | `uc_modSP(`SP_OP_DEC));  // Mov alu_a=pc und dec(sp) for following stackpush of PC
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT));  // Push PC to stack
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_EMU_A) | `uc_setALUop(`uc_ALU_OP_COPY));  // Fetch the lower 5 bits of the opcode and copy them to alu_out.
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_OUT_PC) | `uc_xtask); // Set PC=alu_out and end task.

`startCPUInstruction(6);  // uCode for POPPC instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_COPY) | `uc_modSP(`SP_OP_INC));  // Pop the pc to alu input a, set alu operation copy and inc stackpointer
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_OUT_PC) | `uc_xtask);  // Copy alu out to pc and end task

`startCPUInstruction(7);  // uCode for LOAD instruction
// mem[sp]=mem[mem[sp]];
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_COPY));  // alu_a=TOS. Copy to alu_out.
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_MEM_OUT_A) | `uc_setALUop(`uc_ALU_OP_COPY));  // alu_a=mem[alu_out] and copy this to alu_out again.
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);  // push alu_out to stack and end task.

`startCPUInstruction(8);  // uCode for STORE instruction
// mem[mem[spo]]=mem[sp+1];sp=sp+2;
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_COPY) | `uc_modSP(`SP_OP_INC));  // alu_a=TOS, inc(SP) and copy alu_a to alu_out.
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_NOP) | `uc_modSP(`SP_OP_INC));  // alu_a=TOS, inc(SP). Keep alu_out untouched
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_A_MEM_OUT) | `uc_xtask);  // mem[alu_out]=a and end task.

`startCPUInstruction(9);  // uCode for PUSHSP operation
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_SP_A) | `uc_setALUop(`uc_ALU_OP_COPY) | `uc_modSP(`SP_OP_DEC)); // Copy the stackpointer to alu input a, set copy operation a=>out and decrease stackpointer by 4 bytes
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask); // Write alu_out to the current stack position and end task.

`startCPUInstruction(10); // uCode for POPSP instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_COPY) | `uc_modSP(`SP_OP_INC));  // Pop the pc to alu input a, set alu operation copy and inc stackpointer
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_OUT_SP) | `uc_xtask);  // Copy alu out to sp and end task

`startCPUInstruction(11); // uCode for ADD instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_modSP(`SP_OP_INC));
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_B) | `uc_setALUop(`uc_ALU_OP_ADD));
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);

`startCPUInstruction(12); // uCode for AND instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_modSP(`SP_OP_INC));
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_B) | `uc_setALUop(`uc_ALU_OP_AND));
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);

`startCPUInstruction(13); // uCode for OR instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_modSP(`SP_OP_INC));
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_B) | `uc_setALUop(`uc_ALU_OP_OR));
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);

`startCPUInstruction(14); // uCode for NOT instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_NOT));  // Pop TOS to ALU input a and set ALU not operation
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);  // Push the result back to the stack.

`startCPUInstruction(15); // uCode for FLIP instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_POP_A) | `uc_setALUop(`uc_ALU_OP_FLIP));  // Pop TOS to ALU input a and set ALU flip operation
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_PUSH_OUT) | `uc_xtask);  // Push the result back to the stack.

`startCPUInstruction(16); // uCode for NOP instruction
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_NOP)); 
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_NOP)); 
`ucodeInstr(`uc_setALU_MV(`uc_ALU_MV_NOP) | `uc_xtask); 

$display("Microcode instructions in ucode ROM: %d",curUCode);

	// synthesis translate_off
   file = $fopen("/home/andreas/fpga/zpura/blink.rom","rb");
   if(!file) begin
		$display("Could not open blink.rom file\n");
	end else begin
		i = 1;//$fread(blk_ram[0],file);
		$display("Loaded test program of length %0d characters\n",i);
		$fclose(file);
	end
	// synthesis translate_on
end

// A simple ALU
// ALU input a,b and ALU output
reg [31:0] alu_a,alu_b,alu_out;
reg [2:0] alu_op;  // The current ALU operation

always @(alu_a or alu_b or alu_op) begin
	case(alu_op)
	   //`uc_ALU_OP_NOP:  begin end // Do not touch ALU out.
		`uc_ALU_OP_COPY: alu_out <= alu_a;
		`uc_ALU_OP_ADD:  alu_out <= alu_a + alu_b;
		`uc_ALU_OP_AND:  alu_out <= alu_a & alu_b;
		`uc_ALU_OP_OR:   alu_out <= alu_a | alu_b;
		`uc_ALU_OP_NOT:  alu_out <= ~alu_a;
		`uc_ALU_OP_FLIP: alu_out <= {alu_a[0], alu_a[1], alu_a[2],alu_a[3],
							 			    alu_a[4], alu_a[5], alu_a[6],alu_a[7],
										    alu_a[8], alu_a[9], alu_a[10],alu_a[11],
										    alu_a[12], alu_a[13], alu_a[14],alu_a[15],
										    alu_a[16], alu_a[17], alu_a[18],alu_a[19],
										    alu_a[20], alu_a[21], alu_a[22],alu_a[23],
											 alu_a[24], alu_a[25], alu_a[26],alu_a[27],
										    alu_a[28], alu_a[29], alu_a[30],alu_a[31]};
		default: alu_out <= alu_a;
	endcase
end

integer i;

// Pull the clk to 0 with the cpu pause signal
always @(posedge (clk & !cpu_pause)) begin
	if(~rst) begin 
		pc <= 256*1024*1024;  // Start code from 1GB (256m qwords)
		upc <= 6'd0;  // Microcode 0, too
		sp <= RAM_SIZE;
		state <= state_fetch_code;
		//substate <= 0;
		idim_flag <= 0;
		opcode <= 8'd0;
		led1 <= 0;
	end else begin
		casex(state)
			state_error: begin
				// ToDo: signal error code on display?
				// And just halt cpu
			end
			state_exec: begin
				casex(opcode)
					8'b00000000: upc <= uc_adr[0];  // BREAKPOINT
					8'b1xxxxxxx: upc <= uc_adr[1];  // IM x
					8'b010xxxxx: upc <= uc_adr[2];  // STORESP x
					8'b011xxxxx: upc <= uc_adr[3];  // LOADSP x
					8'b0001xxxx: upc <= uc_adr[4];  // ADDSP x
					8'b001xxxxx: upc <= uc_adr[5];  // EMULATE x
					8'b00000100: upc <= uc_adr[6];  // POPPC
					8'b00001000: upc <= uc_adr[7];  // LOAD
					8'b00001100: upc <= uc_adr[8];  // STORE
					8'b00000010: upc <= uc_adr[9];  // PUSHSP
					8'b00001101: upc <= uc_adr[10]; // POPSP
					8'b00000101: upc <= uc_adr[11]; // ADD 
					8'b00000101: upc <= uc_adr[12]; // AND
					8'b00000111: upc <= uc_adr[13]; // OR
					8'b00001001: upc <= uc_adr[14]; // NOT
					8'b00001010: upc <= uc_adr[15]; // FLIP
					8'b00001011: upc <= uc_adr[16]; // NOP	
					default: begin
						state <= state_error;
						error_status <= error_illegal_instruction;
					end
				endcase
				state <= state_fetch_ucode;  // Run the ucode task
			end
			state_fetch_ucode: begin   // Fetch the next opcode from  
				uopcode <= ucode[upc];  // the microcode
				state <= state_run_ucode;
			end
			state_run_ucode: begin
				// Execute a ucode instruction
				case(uopcode[2:1]) // The SP mod operation
					2'd`SP_OP_INC:          sp <= sp + 4;  // Increment stackpointer by 4 byte
					2'd`SP_OP_DEC:          sp <= sp - 4;  // Decrement stackpointer by 4 byte
					2'd`SP_OP_DEC_NOT_IDIM: if(!idim_flag) sp <= sp -4;  // Dec SP, if idom flag not set
				endcase
				alu_op <= uopcode[11:9];  // Copy the ALU operation to the ALU
				case(uopcode[8:7])  // The mem cyc state
				`uc_MEM_CYC_START: uopcode[8:7] <= `uc_MEM_CYC_CHECK;
				`uc_MEM_CYC_CHECK: begin
					if(mem_ready) uopcode[8:7] <= `uc_MEM_CYC_COMPLETE;
				end
				endcase
				case(uopcode[6:3])  // The current ALU move instruction in the ucode
				//`uc_ALU_MV_NOP:      // Do not move anything
	         `uc_ALU_MV_POP_A & 15: begin
					// alu_a <= mem[sp];      // Pop alu_a from stack
					if(uopcode[8:7]==`uc_MEM_CYC_START) begin
						$display("Read alu a from stack %d\n",sp);
						memory_adr <= sp;
						mem_write <= 0;
						mem_cs <= 1;
					end
					if(uopcode[8:7]==`uc_MEM_CYC_COMPLETE) begin
						alu_a <= databus;
						mem_cs <= 0;  // Turn off RAM.
					end
				end
			   `uc_ALU_MV_POP_B & 15: begin
					// alu_b <= mem[sp];      // Pop alu_b from stack
					if(uopcode[8:7]==`uc_MEM_CYC_START) begin
						$display("Read alu b from stack %d\n", sp);
						memory_adr <= sp;
						mem_write <= 0;
						mem_cs <= 1;
					end
					if(uopcode[8:7]==`uc_MEM_CYC_COMPLETE) begin 
						alu_b <= databus;
						mem_cs <= 0;
					end
				end
				`uc_ALU_MV_PUSH_OUT & 15: begin
					//	mem[sp] <= alu_out;    // Push ALU out to stack
					if(uopcode[8:7]==`uc_MEM_CYC_START) begin
						$display("Write alu out to stack pos %d\n",sp);
						memory_adr <= sp;
						databus_out <= alu_out;
						mem_write <= 1;
						mem_cs <= 1;
					end
					if(uopcode[8:7]==`uc_MEM_CYC_COMPLETE) begin 
						mem_cs <= 0;
					end
				end
			   `uc_ALU_MV_OUT_A:     alu_a <= alu_out;      // mov ALU out to input a
				`uc_ALU_MV_MEM_OUT_A & 15: begin
					// alu_a <= mem[alu_out]; // alu_a = mem[alu_out]
					if(uopcode[8:7]==`uc_MEM_CYC_START) begin
						$display("Read adr <alu out> ( %d )from memory and copy it to alu a\n",alu_out);
						memory_adr <= alu_out;
						mem_write <= 0;
						mem_cs <= 1;
					end
					if(uopcode[8:7]==`uc_MEM_CYC_COMPLETE) begin 
						mem_cs <= 0;
					end
				end
				`uc_ALU_MV_A_MEM_OUT & 15: begin // Mov mem[alu_out]=alu_a
					if(uopcode[8:7]==`uc_MEM_CYC_START) begin
						$display("Write alu_a to adr <alu out> ( %d )\n",alu_out);
						memory_adr <= alu_out;
						databus_out <= alu_a;
						mem_write <= 1;
						mem_cs <= 1;
					end
					if(uopcode[8:7]==`uc_MEM_CYC_COMPLETE) begin 
						mem_cs <= 0;
					end
				end
				`uc_ALU_MV_IM:  begin
					alu_a <= {{25{opcode[6]}},opcode[6:0]};   // Mov an immediate from the opcode to input a
					//alu_b <= idim_flag ? mem[sp] << 7 : 0;    // If idim_flag get the previous immediate from the stack
					if(~idim_flag) begin
						alu_b <= 0;
						uopcode[8:7]<= `uc_MEM_CYC_COMPLETE;  // Abort this memory cycle.
					end else begin
						if(uopcode[8:7]==`uc_MEM_CYC_START) begin
							$display("Read sp ( %d )from memory and copy it to alu b shifted by 7\n",sp);
							memory_adr <= sp;
							mem_write <= 0;
							mem_cs <= 1;
						end
						if(uopcode[8:7]==`uc_MEM_CYC_COMPLETE) begin
							alu_b <= databus << 7;
							mem_cs <= 0;
						end
					end
				end
				`uc_ALU_MV_SP_A:       alu_a <= sp;          // Mov the stackpointer to a
            `uc_ALU_MV_OUT_SP:     sp <= alu_out;        // Set the stackpointer to <out
				`uc_ALU_MV_OUT_PC:     pc <= alu_out;        // Set the program counter to <out>
				`uc_ALU_MV_OPC_A: begin
					alu_a <= {25'd0,~opcode[4],opcode[3:0],2'b00}; // Mov the lower 5 bits of the opcode to a with the msb inverted and shifted by 2.
					alu_b <= sp;  // To make a SP relative access, already copy the SP to the other ALU input.
				end
				`uc_ALU_MV_EMU_A:      alu_a <= {22'd0,opcode[4:0],5'd0};  // Get the lower 5 bits from the opcode and shift them by 5 bits.
				endcase
				 // This is the end of this task? 
				 // Wait for an running mem cycle to complete!
				if(uopcode[0] == 1 && uopcode[8:7]==`uc_MEM_CYC_COMPLETE) 
					state <= state_fetch_code;  // Get next opcode
				else begin
					// Only move on to the next ucode operation, if a 
					// currently running mem cycle is completed!
					if(uopcode[8:7]==`uc_MEM_CYC_COMPLETE) begin
						upc <= upc + 6'd1;  // Fetch the next ucode instruction
						state <= state_fetch_ucode;
					end
				end
			end
			state_fetch_code: begin
				led1 <= 0;  // Signal fetched
				idim_flag <= opcode[7];  // IM opcode is the only instruction with bit 7 = 1
			   case(pc[1:0])
					2'b00: opcode <= databus[7:0];
					2'b01: opcode <= databus[15:8];
					2'b10: opcode <= databus[23:16];
					2'b11: begin 
						opcode <= databus[31:24];
						pc <= pc + 32'd4;
					end
				endcase
				$display("Fetched instruction %d from %d",opcode,pc);
				state <= state_exec;
			end
		endcase
	end
end
endmodule
