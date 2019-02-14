// Generator for a FIX timestamp, like
// YYYYMMDD-HH:MM:SS.sss
// which is GMT-relative(!)

module TimestampGenerator (
	input rst,  // Reset signal
	input clk,	// 1kHz clock signal to trigger the next millisecond
	inout [3:0] digits [16:0],  // 17 m_digits output or input to set the clock
	input wren  // Write enable to set the clock
);

reg [3:0] m_digits [16:0];  // the 17 registers to store the current m_digits
reg [16:1] carry;  // 16 carry input signals for m_digits 16 to 1
reg [4:0] daysInMonth [0:1][1:12];
reg leap_years [18:24];  // The leap years from 2018 to 2014

// Assign the stored digits to the output, if write enable is false.
assign digits = (wren == 0) ? m_digits : {17{4'bz}};

initial begin
	daysInMonth[0][1] <= 31;
	daysInMonth[0][2] <= 28;
	daysInMonth[0][3] <= 31;
	daysInMonth[0][4] <= 30;
	daysInMonth[0][5] <= 31;
	daysInMonth[0][6] <= 30;
	daysInMonth[0][7] <= 31;
	daysInMonth[0][8] <= 31;
	daysInMonth[0][9] <= 30;
	daysInMonth[0][10] <= 31;
	daysInMonth[0][11] <= 30;
	daysInMonth[0][12] <= 31;
	daysInMonth[1][1] <= 31;
	daysInMonth[1][2] <= 29;
	daysInMonth[1][3] <= 31;
	daysInMonth[1][4] <= 30;
	daysInMonth[1][5] <= 31;
	daysInMonth[1][6] <= 30;
	daysInMonth[1][7] <= 31;
	daysInMonth[1][8] <= 31;
	daysInMonth[1][9] <= 30;
	daysInMonth[1][10] <= 31;
	daysInMonth[1][11] <= 30;
	daysInMonth[1][12] <= 31;
	leap_years[18] <= 1'b0;
	leap_years[19] <= 1'b0;
	leap_years[20] <= 1'b1;
	leap_years[21] <= 1'b0;
	leap_years[22] <= 1'b0;
	leap_years[23] <= 1'b0;
	leap_years[24] <= 1'b1;
end

integer i;
always @(clk or carry or wren) begin
	if(wren) begin  // Set the clock from the outside
		for(i=0;i<=16;i=i+1) begin
			m_digits[i] <= digits[i];
		end
	end else begin
		if(~rst) begin
			carry <= 16'd0;
			for( i=16; i>=0; i=i-1) begin
				m_digits[i] <= 0;
			end
		end else begin
			if(clk) begin  // A new millisecond tick
				m_digits[0] <= m_digits[0] == 9 ? 0 : m_digits[0] + 1;
				carry[1] <= (m_digits[0] == 9);  // Set carry, if digit[0] is reset to 0.
			end
			for(i=1;i<=3;i=i+1) begin // YYYYMMDD-HH:MM:S=>S.ss<=s
				if( carry[i]) begin
					m_digits[i] <= m_digits[i] == 9 ? 0 : m_digits[i] + 1;
					carry[i+1] <= (m_digits[i] == 9);
					carry[i] <= 1'b0;
				end
			end
			if( carry[4]) begin  // YYYYMMDD-HH:MM:=>S<=S.sss
				m_digits[4] <= m_digits[4] == 5 ? 0 : m_digits[4] + 1;
				carry[5] <= (m_digits[4] == 5);
				carry[4] <= 1'b0;
			end
			if( carry[5]) begin  // YYYYMMDD-HH:M=>M<=:SS.sss
				m_digits[5] <= m_digits[5] == 9 ? 0 : m_digits[5] + 1;
				carry[6] <= (m_digits[5] == 9);
				carry[5] <= 1'b0;
			end
			if( carry[6]) begin  // YYYYMMDD-HH:=>M<=M<=:SS.sss
				m_digits[6] <= m_digits[6] == 5 ? 0 : m_digits[6] + 1;
				carry[7] <= (m_digits[6] == 5);
				carry[6] <= 1'b0;
			end
			if( carry[7]) begin  // YYYYMMDD-H=>H<=:MM<=:SS.sss
				if(m_digits[8]<2) begin
					m_digits[7] <= m_digits[7] == 9 ? 0 : m_digits[7] + 1;
					carry[8] <= (m_digits[7] == 9);
				end else begin
					m_digits[7] <= m_digits[7] == 3 ? 0 : m_digits[7] + 1;
					carry[8] <= (m_digits[7] == 3);
				end
				carry[7] <= 1'b0;
			end
			if( carry[8]) begin  // YYYYMMDD-=>H<=H:MM<=:SS.sss
				m_digits[8] <= m_digits[8] == 2 ? 0 : m_digits[8] + 1;
				carry[9] <= (m_digits[8] == 2);	
				carry[8] <= 1'b0;
			end
			if( carry[9]) begin  // YYYYMM=>DD<=-HH:MM<=:SS.sss
				if(10*m_digits[10]+m_digits[9]<daysInMonth[leap_years[10*m_digits[14]+m_digits[13]]][10*m_digits[12]+m_digits[11]]) begin
					// Just inc the day
					if( m_digits[9] == 9) begin
						m_digits[9] <= 0;
						m_digits[10] <= m_digits[10] + 1;
					end else begin
						m_digits[9] <= m_digits[9]+1;
					end
				end else begin // Overflow of the days of month
					m_digits[10] <= 0;  // It is the 1st of the
					m_digits[9] <= 1;   // next month.
					carry[11] <= 1'b1;  // Inc the month	
				end
				carry[9] <= 1'b0;
			end
			if(carry[11]) begin  // // YYYY=>MM<=DD-HH:MM<=:SS.sss
				if(m_digits[12]==0) begin
					if(m_digits[11]==9) begin
						m_digits[11] <= 0;
						m_digits[12] <= 1;
					end else begin
						m_digits[11] <= m_digits[11] + 1;
					end
				end else begin
					if(m_digits[11]==2) begin  // Overflow to next year 
						m_digits[11] <= 1;
						m_digits[12] <= 0;
						carry[13] <= 1'b1;
					end else begin
						m_digits[11] <= m_digits[11] + 1;
					end
				end
				carry[11] <= 1'b0;  // Reset carry
			end
			for(i=13; i<=16; i=i+1) begin  // Increment the 4 year digits
				if(carry[i]) begin
					m_digits[i] <= m_digits[i] == 9 ? 0 : m_digits[i]+1;
					carry[i+1] <= (m_digits[i] == 9);
					carry[i] <= 1'b0;
				end
			end
		end
	end
end

endmodule
