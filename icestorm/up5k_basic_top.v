// u4k_basic_top.v - top level for tst_6502 in up5k
// 03-02-19 E. Brombaugh

`default_nettype none

module up5k_basic_top(
	// 16MHz clock osc
	input clk_16,
    
    // video - open drain
    output luma,
    output sync,
	
    // gpio
    output [7:0] gpio_o,
    input [7:0] gpio_i,
    
    // serial
    input RX,
    output TX,
	
	// SPI0 port
	inout	spi0_mosi,
			spi0_miso,
			spi0_sclk,
			spi0_cs0,
	
    // diagnostics
    output tst_rst,
    output tst_clk,
    output tst_irq,
	output tst_rdy,
	
	// LED - via drivers
	output RGB0, RGB1, RGB2
);
`define USE_PLL
`ifdef USE_PLL
	// internal 16MHz -> 16MHz w/ PLL
	
	// tried w/ on-chip reference but it's very noisy
	// and results in wiggly video
	//wire clk_48;

	//SB_HFOSC inthosc (
	//	.CLKHFPU(1'b1),
	//	.CLKHFEN(1'b1),
	//	.CLKHF(clk_48)
	//);
	
	wire clk;
	SB_PLL40_CORE pll_inst (
		.REFERENCECLK(clk_16),
		.PLLOUTCORE(clk),
		.PLLOUTGLOBAL(),
		.EXTFEEDBACK(),
		.DYNAMICDELAY(8'h00),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.LATCHINPUTVALUE(),
		.LOCK(),
		.SDI(),
		.SDO(),
		.SCLK()
	);  
	// Fin=16, Fout=16
	defparam pll_inst.DIVR = 4'b0000;
	defparam pll_inst.DIVF = 7'b0111111;
	defparam pll_inst.DIVQ = 3'b110;
	defparam pll_inst.FILTER_RANGE = 3'b001;
	defparam pll_inst.FEEDBACK_PATH = "SIMPLE";
	defparam pll_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
	defparam pll_inst.FDA_FEEDBACK = 4'b0000;
	defparam pll_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
	defparam pll_inst.FDA_RELATIVE = 4'b0000;
	defparam pll_inst.SHIFTREG_DIV_MODE = 2'b00;
	defparam pll_inst.PLLOUT_SELECT = "GENCLK";
	defparam pll_inst.ENABLE_ICEGATE = 1'b0;
`else
	// external 16MHz clock generator
	wire clk = clk_16;
`endif

	// reset generator waits > 10us
	reg [7:0] reset_cnt;
	reg reset;
	initial
        reset_cnt <= 8'h00;
    
	always @(posedge clk)
	begin
		if(reset_cnt != 8'hff)
        begin
            reset_cnt <= reset_cnt + 8'h01;
            reset <= 1'b1;
        end
        else
            reset <= 1'b0;
	end
    
	// test unit
    wire raw_luma, raw_sync;
	tst_6502 uut(
		.clk(clk),
		.reset(reset),
    
        .luma(raw_luma),
        .sync(raw_sync),
		
		.gpio_o(gpio_o),
		.gpio_i(gpio_i),
    
        .RX(RX),
        .TX(TX),
	
		.spi0_mosi(spi0_mosi),
		.spi0_miso(spi0_miso),
		.spi0_sclk(spi0_sclk),
		.spi0_cs0(spi0_cs0),
    
        .CPU_IRQ(tst_irq),
		.CPU_RDY(tst_rdy)
	);
    
	// RGB LED Driver from top 3 bits of gpio
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) RGBA_DRIVER (
		.CURREN(1'b1),
		.RGBLEDEN(1'b1),
		.RGB0PWM(gpio_o[7]),
		.RGB1PWM(gpio_o[6]),
		.RGB2PWM(gpio_o[5]),
		.RGB0(RGB0),
		.RGB1(RGB1),
		.RGB2(RGB2)
	);
    
	// push/pull video outputs
	assign luma = raw_luma;
	assign sync = raw_sync;

     // hook up diagnostics
    assign tst_rst = reset;
    assign tst_clk = clk;
endmodule
