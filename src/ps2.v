// ps2.v - PS/2 synchronous serial I/O port
// 04-01-19 E. Brombaugh

`default_nettype none

module ps2(
	input clk,				// system clock
	input rst,				// system reset
	input cs,				// chip select
	input we,				// write enable
	input addr,				// register select
	input [7:0] din,		// data bus input
	output reg [7:0] dout,	// data bus output
	output [3:0] diag,		// diagnostic output
	inout ps2_clk,			// ps2 clock pin
	inout ps2_dat			// ps2 data pin
);
	wire ps2_clk_in, ps2_dat_in, clrerr;
	
	// synchronize to local clock
	reg [2:0] clk_pipe, dat_pipe;
	reg ps2_clk_ena, ps2_dat_sync;
	always @(posedge clk)
	begin
		clk_pipe <= {clk_pipe[1:0], ps2_clk_in};
		dat_pipe <= {dat_pipe[1:0], ps2_dat_in};
		ps2_clk_ena <= clk_pipe[2] & !clk_pipe[1]; // falling edge
		ps2_dat_sync <= dat_pipe[2]; // prior to rising edge.
	end
	
	// rx state machine deserializes data
	localparam ST_WAIT = 4'h0;
	localparam ST_DAT0 = 4'hA;
	localparam ST_STOP = 4'h1;	
	reg [3:0] rx_state;
	reg [8:0] rx_sreg;
	reg [7:0] rx_code;
	reg rx_done, rx_frmerr, rx_parerr;
	always @(posedge clk)
		if(rst | clrerr)
		begin
			rx_state <= ST_WAIT;
			rx_done <= 1'b0;
			rx_frmerr <= 1'b0;
			rx_parerr <= 1'b0;
		end
		else
		begin
			if(ps2_clk_ena)
			begin
				// Start or count or wait
				if(|rx_state)
					rx_state <= rx_state - 4'h1;
				else if(ps2_dat_sync == 1'b0)
					rx_state <= ST_DAT0;
				
				// shift in data lsb first
				if(|rx_state)
					rx_sreg <= {ps2_dat_sync,rx_sreg[8:1]};
				
				// final processing
				if(rx_state == ST_STOP)
				begin
					rx_done <= 1'b1;	// flag end of cycle
					if(ps2_dat_sync == 1'b0)
						rx_frmerr <= 1'b1;	// frame error if stop = 0
					if(^rx_sreg == 1'b0)
						rx_parerr <= 1'b1;	// parity error
					rx_code <= rx_sreg[7:0]; // grab data
				end
			end
			else
				rx_done <= 1'b0;	// rx_done only lasts one cycle
		end
	
	// Decode from scan codes to ASCII
	wire [7:0] ascii;
	wire valid, caps_lock;
	ps2_decode udecode(
		.clk(clk),
		.rst(rst | clrerr),
		.ena(rx_done),
		.code(rx_code),
		.ascii(ascii),
		.valid(valid),
		.caps_lock(caps_lock)
	);
		
	// RX ready and overflow bits
	reg rx_rdy, rx_ovfl;
	always @(posedge clk)
		if(rst | clrerr)
		begin
			rx_rdy <= 1'b0;
			rx_ovfl <= 1'b0;
		end
		else if(valid)
		begin
			// data received - set ready
			rx_rdy <= 1'b1;
			//overflow if previous ready not cleared
			rx_ovfl <= rx_rdy;
		end
		else if(cs & !we & addr)
		begin
			// clear ready when reading data
			rx_rdy <= 1'b0;
		end
	
	// control register - just the clear bit for now
	reg cr;
	always @(posedge clk)
		if(rst)
			cr <= 1'b0;
		else if(cs & we & !addr)
			cr <= din[0];
	assign clrerr = cr;
		
	// data output
	always @(posedge clk)
		if(cs & !we)
		begin
			if(!addr)
				dout <= {3'h0,caps_lock,rx_parerr,rx_frmerr,rx_ovfl,rx_rdy};	// read status
			else
				dout <= ascii;	// read data
		end
	
	// Clock driver
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) uclk (
		.PACKAGE_PIN(ps2_clk),
		.LATCH_INPUT_VALUE(1'b0),
		.CLOCK_ENABLE(1'b0),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(1'b0),
		.OUTPUT_ENABLE(1'b0),	// output not used yet
		.D_OUT_0(1'b0),
		.D_OUT_1(1'b0),
		.D_IN_0(ps2_clk_in),
		.D_IN_1()
	);

	// Data driver
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) udat (
		.PACKAGE_PIN(ps2_dat),
		.LATCH_INPUT_VALUE(1'b0),
		.CLOCK_ENABLE(1'b0),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(1'b0),
		.OUTPUT_ENABLE(1'b0),	// output not used yet
		.D_OUT_0(1'b0),
		.D_OUT_1(1'b0),
		.D_IN_0(ps2_dat_in),
		.D_IN_1()
	);

	// hook up diagnostics
	assign diag = {ps2_clk_ena,ps2_dat_sync,rx_done,valid};
endmodule

//
// ps2 decoder submodule
// modified from ps2_keyboard_to_ascii.vhd
// https://www.digikey.com/eewiki/pages/viewpage.action?pageId=28279002
//
module ps2_decode(
	input clk,				// system clock
	input rst,				// system reset
	input ena,				// input valid
	input [7:0] code,		// code input
	output reg [7:0] ascii,	// decoded output
	output reg valid,		// output valid
	output reg caps_lock	// state of caps_lock
);
	// states
	localparam ST_READY = 2'b00;
	localparam ST_NEW_CODE = 2'b01;
	localparam ST_TRANSLATE = 2'b10;
	localparam ST_OUTPUT = 2'b11;
	
	// regs
	reg [1:0] state;
	reg brk_flag, e0_code, control, shift;
	
	// state machine
	always @(posedge clk)
		if(rst)
		begin
			state <= ST_READY;
			brk_flag <= 1'b0;
			e0_code <= 1'b0;
			caps_lock <= 1'b0;
			control <= 1'b0;
			shift <= 1'b0;
			ascii <= 8'h00;
		end
		else
		begin
			// valid defaults to inactive
			valid <= 1'b0;
			
			// handle state transitions and processing
			case(state)
				ST_READY:
					// Waiting for scan code
					if(ena)
						state <= ST_NEW_CODE;
				
				ST_NEW_CODE:
					// process new scancode
					if(code == 8'hf0)
					begin
						brk_flag <=1'b1;
						state <= ST_READY;
					end
					else if(code == 8'he0)
					begin
						e0_code <= 1'b1;
						state <= ST_READY;
					end
					else
					begin
						ascii[7] <= 1'b1;
						state <= ST_TRANSLATE;
					end
								
				ST_TRANSLATE:
				begin
					// reset flags
					brk_flag <= 1'b0;
					e0_code <= 1'b0;
					
					// handle modifier keys
					case(code)
						8'h58: caps_lock <= brk_flag ? caps_lock : !caps_lock;	// caps lock code
						8'h14: control <= !brk_flag;	// control (l or r w/ e0)
						8'h12: shift <= !brk_flag;	// left shift
						8'h59: shift <= !brk_flag;	// right shift
					endcase
					
					// control keys
					if(control)
						case(code)
							8'h1E: ascii <= 8'h00; //^@  NUL
							8'h1C: ascii <= 8'h01; //^A  SOH
							8'h32: ascii <= 8'h02; //^B  STX
							8'h21: ascii <= 8'h03; //^C  ETX
							8'h23: ascii <= 8'h04; //^D  EOT
							8'h24: ascii <= 8'h05; //^E  ENQ
							8'h2B: ascii <= 8'h06; //^F  ACK
							8'h34: ascii <= 8'h07; //^G  BEL
							8'h33: ascii <= 8'h08; //^H  BS
							8'h43: ascii <= 8'h09; //^I  HT
							8'h3B: ascii <= 8'h0A; //^J  LF
							8'h42: ascii <= 8'h0B; //^K  VT
							8'h4B: ascii <= 8'h0C; //^L  FF
							8'h3A: ascii <= 8'h0D; //^M  CR
							8'h31: ascii <= 8'h0E; //^N  SO
							8'h44: ascii <= 8'h0F; //^O  SI
							8'h4D: ascii <= 8'h10; //^P  DLE
							8'h15: ascii <= 8'h11; //^Q  DC1
							8'h2D: ascii <= 8'h12; //^R  DC2
							8'h1B: ascii <= 8'h13; //^S  DC3
							8'h2C: ascii <= 8'h14; //^T  DC4
							8'h3C: ascii <= 8'h15; //^U  NAK
							8'h2A: ascii <= 8'h16; //^V  SYN
							8'h1D: ascii <= 8'h17; //^W  ETB
							8'h22: ascii <= 8'h18; //^X  CAN
							8'h35: ascii <= 8'h19; //^Y  EM
							8'h1A: ascii <= 8'h1A; //^Z  SUB
							8'h54: ascii <= 8'h1B; //^[  ESC
							8'h5D: ascii <= 8'h1C; //^\  FS
							8'h5B: ascii <= 8'h1D; //^]  GS
							8'h36: ascii <= 8'h1E; //^^  RS
							8'h4E: ascii <= 8'h1F; //^_  US
							8'h4A: ascii <= 8'h7F; //^?  DEL
						endcase
					else
					begin
						// keys that don't depend on shift state
						case(code)
							8'h29: ascii <= 8'h20; //space
							8'h66: ascii <= 8'h08; //backspace (BS control code)
							8'h0D: ascii <= 8'h09; //tab (HT control code)
							8'h5A: ascii <= 8'h0D; //enter (CR control code)
							8'h76: ascii <= 8'h1B; //escape (ESC control code)
							8'h71: ascii <= e0_code ? 8'h7f : ascii; //delete							
						endcase
						
						// keys that depend on shift and caps_lock
						if(shift ^ caps_lock == 1'b0)
							case(code)
								8'h1C: ascii <= 8'h61; //a
								8'h32: ascii <= 8'h62; //b
								8'h21: ascii <= 8'h63; //c
								8'h23: ascii <= 8'h64; //d
								8'h24: ascii <= 8'h65; //e
								8'h2B: ascii <= 8'h66; //f
								8'h34: ascii <= 8'h67; //g
								8'h33: ascii <= 8'h68; //h
								8'h43: ascii <= 8'h69; //i
								8'h3B: ascii <= 8'h6A; //j
								8'h42: ascii <= 8'h6B; //k
								8'h4B: ascii <= 8'h6C; //l
								8'h3A: ascii <= 8'h6D; //m
								8'h31: ascii <= 8'h6E; //n
								8'h44: ascii <= 8'h6F; //o
								8'h4D: ascii <= 8'h70; //p
								8'h15: ascii <= 8'h71; //q
								8'h2D: ascii <= 8'h72; //r
								8'h1B: ascii <= 8'h73; //s
								8'h2C: ascii <= 8'h74; //t
								8'h3C: ascii <= 8'h75; //u
								8'h2A: ascii <= 8'h76; //v
								8'h1D: ascii <= 8'h77; //w
								8'h22: ascii <= 8'h78; //x
								8'h35: ascii <= 8'h79; //y
								8'h1A: ascii <= 8'h7A; //z
							endcase
						else
							case(code)
								8'h1C: ascii <= 8'h41; //A
								8'h32: ascii <= 8'h42; //B
								8'h21: ascii <= 8'h43; //C
								8'h23: ascii <= 8'h44; //D
								8'h24: ascii <= 8'h45; //E
								8'h2B: ascii <= 8'h46; //F
								8'h34: ascii <= 8'h47; //G
								8'h33: ascii <= 8'h48; //H
								8'h43: ascii <= 8'h49; //I
								8'h3B: ascii <= 8'h4A; //J
								8'h42: ascii <= 8'h4B; //K
								8'h4B: ascii <= 8'h4C; //L
								8'h3A: ascii <= 8'h4D; //M
								8'h31: ascii <= 8'h4E; //N
								8'h44: ascii <= 8'h4F; //O
								8'h4D: ascii <= 8'h50; //P
								8'h15: ascii <= 8'h51; //Q
								8'h2D: ascii <= 8'h52; //R
								8'h1B: ascii <= 8'h53; //S
								8'h2C: ascii <= 8'h54; //T
								8'h3C: ascii <= 8'h55; //U
								8'h2A: ascii <= 8'h56; //V
								8'h1D: ascii <= 8'h57; //W
								8'h22: ascii <= 8'h58; //X
								8'h35: ascii <= 8'h59; //Y
								8'h1A: ascii <= 8'h5A; //Z
							endcase
							
						// numbers and symbols only depend on shift
						if(shift)
							case(code)
								8'h16: ascii <= 8'h21; //!
								8'h52: ascii <= 8'h22; //"
								8'h26: ascii <= 8'h23; //#
								8'h25: ascii <= 8'h24; //$
								8'h2E: ascii <= 8'h25; //%
								8'h3D: ascii <= 8'h26; //&              
								8'h46: ascii <= 8'h28; //(
								8'h45: ascii <= 8'h29; //)
								8'h3E: ascii <= 8'h2A; //*
								8'h55: ascii <= 8'h2B; //+
								8'h4C: ascii <= 8'h3A; //:
								8'h41: ascii <= 8'h3C; //<
								8'h49: ascii <= 8'h3E; //>
								8'h4A: ascii <= 8'h3F; //?
								8'h1E: ascii <= 8'h40; //@
								8'h36: ascii <= 8'h5E; //^
								8'h4E: ascii <= 8'h5F; //_
								8'h54: ascii <= 8'h7B; //{
								8'h5D: ascii <= 8'h7C; //|
								8'h5B: ascii <= 8'h7D; //}
								8'h0E: ascii <= 8'h7E; //~								
							endcase
						else
							case(code)
								8'h45: ascii <= 8'h30; //0
								8'h16: ascii <= 8'h31; //1
								8'h1E: ascii <= 8'h32; //2
								8'h26: ascii <= 8'h33; //3
								8'h25: ascii <= 8'h34; //4
								8'h2E: ascii <= 8'h35; //5
								8'h36: ascii <= 8'h36; //6
								8'h3D: ascii <= 8'h37; //7
								8'h3E: ascii <= 8'h38; //8
								8'h46: ascii <= 8'h39; //9
								8'h52: ascii <= 8'h27; //'
								8'h41: ascii <= 8'h2C; //,
								8'h4E: ascii <= 8'h2D; //-
								8'h49: ascii <= 8'h2E; //.
								8'h4A: ascii <= 8'h2F; ///
								8'h4C: ascii <= 8'h3B; //;
								8'h55: ascii <= 8'h3D; //=
								8'h54: ascii <= 8'h5B; //[
								8'h5D: ascii <= 8'h5C; //\
								8'h5B: ascii <= 8'h5D; //]
								8'h0E: ascii <= 8'h60; //`
							endcase
					end
					
					// if brk_flag then return to ready, else output
					state <= brk_flag ? ST_READY : ST_OUTPUT;
				end
				
				ST_OUTPUT:
				begin
					// msbit flags 
					if(!ascii[7])
						valid <= 1'b1;
					state <= ST_READY;
				end
				
				default:
				begin
					// self-correction
					state <= ST_READY;
					brk_flag <= 1'b0;
					e0_code <= 1'b0;
					caps_lock <= 1'b0;
					control <= 1'b0;
					shift <= 1'b0;
				end
			endcase
		end
endmodule
