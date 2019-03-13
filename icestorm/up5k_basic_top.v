// u4k_basic_top.v - top level for tst_6502 in up5k
// 03-02-19 E. Brombaugh


module up5k_basic_top(
    // gpio
    output [7:0] gpio_o,	// output
    input [7:0] gpio_i,		// input
    
    // serial
    input RX,
    output TX,
	
    // diagnostics
    output tst_rst,
    output tst_clk,
    output tst_irq,
	
	// LED
	output RGB0, RGB1, RGB2 // RGB LED outs
);
	// clock generator
	wire clk_48;

	SB_HFOSC inthosc (
		.CLKHFPU(1'b1),
		.CLKHFEN(1'b1),
		.CLKHF(clk_48)
	);
	
//`define CLK_12MHZ
`ifdef CLK_12MHZ
	// clock divider generates 50% duty 12MHz clock
	reg [1:0] cnt;
	initial
        cnt <= 2'b00;
        
	always @(posedge clk_48)
	begin
        cnt <= cnt + 2'b01;
	end
    wire clk = cnt[1];
`else
//`define PLL_CLK
`ifdef PLL_CLK
	// PLL generates 16MHz clock
	wire clk;
	SB_PLL40_CORE pll_inst (
		.REFERENCECLK(clk_48),
		.PLLOUTCORE(clk),
		.PLLOUTGLOBAL(),
		.EXTFEEDBACK(),
		.DYNAMICDELAY(),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.LATCHINPUTVALUE(),
		.LOCK(),
		.SDI(),
		.SDO(),
		.SCLK()
	);  
	// Fin=48, Fout=16
	defparam pll_inst.DIVR = 4'b0010;
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
	// clock divider generates 33% duty 16MHz clock
	reg [1:0] cnt;
    reg clk;
	initial
    begin
		cnt <= 2'b00;
        clk <= 1'b0;
	end
	always @(posedge clk_48)
	begin
        if(cnt == 2'b10)
		begin
			cnt <= 2'b00;
			clk <= 1'b1;
		end
		else
		begin
			cnt <= cnt + 2'b01;
			clk <= 1'b0;
		end
	end
`endif
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
	tst_6502 uut(
		.clk(clk),
		.reset(reset),
		
		.gpio_o(gpio_o),
		.gpio_i(gpio_i),
    
        .RX(RX),
        .TX(TX),
    
        .CPU_IRQ(tst_irq)
	);
    
	// RGB LED Driver from top 3 bits of gpio
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000111"),
		.RGB1_CURRENT("0b000111"),
		.RGB2_CURRENT("0b000111")
	) RGBA_DRIVER (
		.CURREN(1'b1),
		.RGBLEDEN(1'b1),
		.RGB0PWM(~gpio_o[7]),
		.RGB1PWM(~gpio_o[6]),
		.RGB2PWM(~gpio_o[5]),
		.RGB0(RGB0),
		.RGB1(RGB1),
		.RGB2(RGB2)
	);
    
     // hook up diagnostics
    assign tst_rst = reset;
    assign tst_clk = clk;
endmodule
