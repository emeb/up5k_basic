// tb_tst_6502.v - testbench for test 6502 core
// 02-11-19 E. Brombaugh

`timescale 1ns/1ps
`default_nettype none

module tb_tst_6502;
    reg clk;
    reg reset;
	wire luma, sync;
	wire [7:0] gpio_o;
	reg [7:0] gpio_i;
	reg RX;
    wire TX;
	wire pwm_audio;
    wire spi0_mosi, spi0_miso, spi0_sclk, spi0_cs0;
	wire ps2_clk, ps2_dat;
	wire rgb0, rgb1, rgb2;
	wire [3:0] tst;
	
    // clock source
    always
        #125 clk = ~clk;
    
    // reset
    initial
    begin
`ifdef icarus
  		$dumpfile("tb_tst_6502.vcd");
		$dumpvars;
`endif
        
        // init regs
        clk = 1'b0;
        reset = 1'b1;
        RX = 1'b1;
        
        // release reset
        #1000
        reset = 1'b0;
        
`ifdef icarus
        // stop after 1 sec
		#10000 $finish;
`endif
    end
    
    // Unit under test
    tst_6502 uut(
        .clk(clk),              // 4.028MHz dot clock
        .reset(reset),          // Low-true reset
		.luma(luma),			// video luminance
		.sync(sync),			// video sync
        .gpio_o(gpio_o),        // gpio output
        .gpio_i(gpio_i),        // gpio input
        .RX(RX),                // serial input
        .TX(TX),                // serial output
		.pwm_audio(pwm_audio),	// 1-bit audio
		.spi0_mosi(spi0_mosi),	// SPI core 0
		.spi0_miso(spi0_miso),
		.spi0_sclk(spi0_sclk),
		.spi0_cs0(spi0_cs0),
		.ps2_clk(ps2_clk),		// PS/2 port clock
		.ps2_dat(ps2_dat),		// PS/2 port data
		.rgb0(rgb0),			// LED driver
		.rgb1(rgb1),
		.rgb2(rgb2),
		.tst(tst)				// diagnostics
    );
endmodule
