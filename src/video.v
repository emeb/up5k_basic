// video_2.v - 1k byte video buffer & drive logic - 2nd generation w/ better timing
// 03-19-19 E. Brombaugh

module VIDEO(
	input clk,
	input reset,
	input sel,
	input we,
	input [9:0] addr,
	input [7:0] din,
	output reg [7:0] dout,
	output reg luma,
	output reg sync
);
	// set up timing parameters for 16MHz clock rate
	localparam MAX_H = 1014;	// 1015 clocks/line
	localparam MAX_V = 261;		// 262 lines/frame
	localparam HS_WID = 75;		// 75 clocks/4.7us H sync pulse
	localparam BK_TOP = 16;		// Blanking top on line
	localparam BK_BOT = 240;	// Blanking bottom on line
	localparam VS_LIN = 248;	// Vsync on line
	localparam VS_WID = 942; 	// 948 clocks/59us V sync pulse
	localparam ASTART = 185;	// start of active area @ 11.6us
	
	// revised video timing - separate H and V counters
	reg [9:0] hcnt;
	reg [8:0] vcnt;
	reg hs, vs;
	always @(posedge clk)
	begin
		if(reset)
		begin
			hcnt <= 10'd0;
			vcnt <= 9'd0;
			hs <= 1'b0;
			vs <= 1'b1;
		end
		else
		begin
			// counters
			if(hcnt == MAX_H)
			begin
				hcnt <= 10'd0;
				if(vcnt == MAX_V)
					vcnt <= 8'd0;
				else
					vcnt <= vcnt + 18'd1;
			end
			else
				hcnt <= hcnt + 1;

			// sync pulses
			hs <= (hcnt < HS_WID) ? 1'b0 : 1'b1;
			vs <= ((hcnt < VS_WID)&&(vcnt == VS_LIN)) ? 1'b0 : 1'b1;
		end
	end
	
	// extract video character data address & ROM line
	reg active;			// active video 
	reg [1:0] dcnt;		// decimate counter (1/3)
	reg pixena;			// pixel rate enable
	reg [2:0] pcnt;		// pixel/char count
	reg vload;			// load video shift reg
	reg [4:0] haddr;	// horizontal component of vram addr
	reg [2:0] cline;	// character line index
	reg [4:0] vaddr;	// vertical component of vram addr
	always @(posedge clk)
	begin
		if(reset)
		begin
			active <= 1'b0;
			dcnt <= 2'b00;
			pixena <= 1'b0;
			pcnt <= 3'b000;
			vload <= 1'b0;
			haddr <= 5'd0;
			cline <= 3'b000;
			vaddr <= 5'd0;
		end
		else
		begin
			// wait for start of active
			if(active == 1'b0)
			begin
				if((hcnt == ASTART) && (vcnt >= BK_TOP) && (vcnt < BK_BOT))
				begin
					// reset horizontal stuff at hcnt == ASTART
					active <= 1'b1;		// active video
					dcnt <= 2'b00;
					pixena <= 1'b1;		// start with enable
					pcnt <= 3'b000;
					vload <= 1'b1;		// start with load
					haddr <= 5'd0;
					
					// reset vertical stuff at vcnt == 0;
					if(vcnt == BK_TOP)
					begin
						cline <= 3'b000;
						vaddr <= 5'd0;
					end
				end
			end
			else
			begin
				// divide clock by 3 to get pixel 
				if(dcnt == 2'b10)
				begin
					// generate pixel enable
					dcnt <= 2'b00;
					pixena <= 1'b1;
					if(pcnt == 3'b111)
					begin
						// generate vload
						vload <= 1'b1;
						
						// end of line?
						if(haddr == 5'd31)
						begin
							// shut off counting
							active <= 1'b0;
							
							// time to update vertical address?
							if(cline == 3'b111)
								vaddr <= vaddr + 5'd1;
							
							// update character line index
							cline <= cline + 3'b001;
						end
						
						// update horizontal address
						haddr <= haddr + 5'd1;
					end
					else
						vload <= 1'b0;
					
					// always increment pixel count
					pcnt <= pcnt + 3'b001;
				end
				else
				begin
					dcnt <= dcnt + 2'b01;
					pixena <= 1'b0;
				end
			end
		end
	end
	
	// pipeline control signals
	reg [3:0] active_pipe, pixena_pipe, vload_pipe, hs_pipe, vs_pipe;
	reg [2:0] cline_dly;
	always @(posedge clk)
	begin
		pixena_pipe <= {pixena_pipe[2:0],pixena};
		vload_pipe <= {vload_pipe[2:0],vload};
		active_pipe <= {active_pipe[2:0],active};
		hs_pipe <= {hs_pipe[2:0],hs};
		vs_pipe <= {vs_pipe[2:0],vs};
		cline_dly <= cline;
	end
	wire pixena_dly = pixena_pipe[1];
	wire vload_dly = vload_pipe[1];
	wire active_dly = active_pipe[2];
	wire hs_dly = hs_pipe[2];
	wire vs_dly = vs_pipe[2];
	
	// video memory
	reg [7:0] memory[0:1023];
	
	// memory write uses write-only port
	always @(posedge clk)
		if(sel & we)
			memory[addr] <= din;
	
	// concatenate horizontal and vertical addresses to make ram address
	wire [9:0] vid_addr = {vaddr,haddr};
	
	// read address mux selects video or CPU
	wire [9:0] mem_addr = sel ? addr : vid_addr;
		
	// memory read uses read-only port
	always @(posedge clk)
		dout <= memory[mem_addr];
	
	// one pipe delay
	
	// Character Generator ROM
	wire [10:0] cg_addr = {dout,cline_dly};
	wire [7:0] cg_dout;
	ROM_CG_2kB ucgr(
		.clk(clk),
		.addr(cg_addr),
		.dout(cg_dout)
	);
	
	// two pipes delay
		
	// Video Shift Register
	reg [7:0] vid_shf_reg;
	always @(posedge clk)
		if(vload_dly)
			vid_shf_reg <= cg_dout;
		else if(pixena_dly)
			vid_shf_reg <= {vid_shf_reg[6:0],1'b0};
	
	// three pipes delay
		
	// combine and reclock outputs
	always @(posedge clk)
	begin
		luma <= active_dly & vid_shf_reg[7];
		sync <= hs_dly & vs_dly;
	end
endmodule
