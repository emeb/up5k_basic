// tb_tst_6502.v - testbench for test 6502 core
// 02-11-19 E. Brombaugh

`timescale 1ns/1ps

module tb_tst_6502;
    reg clk;
    reg reset;
	wire [7:0] gpio_o;
	reg [7:0] gpio_i;
	reg RX;
    wire TX;
    
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
		#1000000 $finish;
`endif
    end
    
    // Unit under test
    tst_6502 uut(
        .clk(clk),              // 4.028MHz dot clock
        .reset(reset),          // Low-true reset
        .gpio_o(gpio_o),        // gpio output
        .gpio_i(gpio_i),        // gpio input
        .RX(RX),                // serial input
        .TX(TX)                 // serial output
    );
endmodule
