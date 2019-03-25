// tst_6502.v - test 6502 core
// 02-11-19 E. Brombaugh

`default_nettype none

module tst_6502(
	input	clk,			// 16MHz CPU clock
	input	reset,			// high-true reset
	
	output  luma,			// B/W video outputs
			sync,
	
	output reg [7:0] gpio_o,	// GPIO port
	input [7:0] gpio_i,
	
	input	RX,				// serial RX
	output	TX,				// serial TX
	
	inout	spi0_mosi,		// SPI core 0
			spi0_miso,
			spi0_sclk,
			spi0_cs0,
	
	output	rgb0,			// LED drivers
			rgb1,
			rgb2,
			
	output	CPU_IRQ,		// diagnostic
	output	CPU_RDY			// diagnostic
);
	// The 6502
	wire [15:0] CPU_AB;
	reg [7:0] CPU_DI;
	wire [7:0] CPU_DO;
	wire CPU_WE, CPU_IRQ, CPU_RDY;
	cpu ucpu(
		.clk(clk),
		.reset(reset),
		.AB(CPU_AB),
		.DI(CPU_DI),
		.DO(CPU_DO),
		.WE(CPU_WE),
		.IRQ(CPU_IRQ),
		.NMI(1'b0),
		.RDY(CPU_RDY)
	);
	
	// address decode
	wire ram_sel = (CPU_AB[15] == 1'b0) ? 1 : 0;
	wire basic_sel = ((CPU_AB[15:12] == 4'ha)||(CPU_AB[15:12] == 4'hb)) ? 1 : 0;
	wire video_sel = (CPU_AB[15:10] == 6'h34) ? 1 : 0;
	wire acia_sel = (CPU_AB[15:8] == 8'hf0) ? 1 : 0;
	wire wb_sel = (CPU_AB[15:8] == 8'hf1) ? 1 : 0;
	wire gpio_sel = (CPU_AB[15:8] == 8'hf2) ? 1 : 0;
	wire led_sel = (CPU_AB[15:8] == 8'hf3) ? 1 : 0;
	wire rom_sel = (CPU_AB[15:11] == 5'h1f) ? 1 : 0;
	
	// 32kB RAM @ 0000-7FFF
	wire [7:0] ram_do;
	RAM_32kB uram(
		.clk(clk),
		.sel(ram_sel),
		.we(CPU_WE),
		.addr(CPU_AB[14:0]),
		.din(CPU_DO),
		.dout(ram_do)
	);
	
	// 8kB BASIC ROM @ A000-BFFF
	wire [7:0] basic_do;
	ROM_BASIC_8kB ubrom(
		.clk(clk),
		.addr(CPU_AB[12:0]),
		.dout(basic_do)
	);
	
	// 1kB Video RAM @ D000-D3FF
	wire [7:0] video_do;
	wire vid_rdy;
	VIDEO uvid(
		.clk(clk),				// system clock
		.reset(reset),			// system reset
		.sel(video_sel),		// chip select
		.we(CPU_WE),			// write enable
		.addr(CPU_AB[9:0]),		// address
		.din(CPU_DO),			// data bus input
		.dout(video_do),		// data bus output
		.luma(luma),			// video luminance
		.sync(sync),			// video sync
		.rdy(vid_rdy)			// processor stall
	);
		
	// 256B ACIA @ F000-F0FF
	wire [7:0] acia_do;
	wire acia_irq;
	acia uacia(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(acia_sel),			// chip select
		.we(CPU_WE),			// write enable
		.rs(CPU_AB[0]),			// address
		.rx(RX),				// serial receive
		.din(CPU_DO),			// data bus input
		.dout(acia_do),			// data bus output
		.tx(TX),				// serial transmit
		.irq(acia_irq)			// interrupt request
	);
	
	// 256B Wishbone bus master and SB IP cores @ F100-F1FF
	wire [7:0] wb_do;
	wire wb_irq, wb_rdy;
	system_bus usysbus(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(wb_sel),			// chip select
		.we(CPU_WE),			// write enable
		.addr(CPU_AB[7:0]),		// address
		.din(CPU_DO),			// data bus input
		.dout(wb_do),			// data bus output
		.rdy(wb_rdy),			// processor stall
		.irq(wb_irq),			// interrupt request
		.spi0_mosi(spi0_mosi),	// spi core 0 mosi
		.spi0_miso(spi0_miso),	// spi core 0 miso
		.spi0_sclk(spi0_sclk),	// spi core 0 sclk
		.spi0_cs0(spi0_cs0)		// spi core 0 cs
	);
	
	// combine IRQs
	assign CPU_IRQ = acia_irq | wb_irq;
	
	// combine RDYs
	assign CPU_RDY = vid_rdy & wb_rdy;
	
	// 256B GPIO @ F200-F2FF
	reg [7:0] gpio_do;
	always @(posedge clk)
		if((CPU_WE == 1'b1) && (gpio_sel == 1'b1))
			gpio_o <= CPU_DO;
	always @(posedge clk)
		gpio_do <= gpio_i;
	
	// LED PWM controller
	wire [7:0] led_do;
	led_pwm uledpwm(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(led_sel),			// chip select
		.we(CPU_WE),			// write enable
		.addr(CPU_AB[3:0]),		// address
		.din(CPU_DO),			// data bus input
		.dout(led_do),			// data bus output
		.rgb0(rgb0),			// rgb0 pin
		.rgb1(rgb1),			// rgb1 pin
		.rgb2(rgb2)				// rgb2 pin
	);
	
	// 2kB ROM @ f800-ffff
	reg [7:0] rom_mem[2047:0];
	reg [7:0] rom_do;
	initial
		$readmemh("rom.hex",rom_mem);
	always @(posedge clk)
		rom_do <= rom_mem[CPU_AB[10:0]];

	// data mux only updates select lines when CPU_RDY asserted
	reg [6:0] mux_sel;
	always @(posedge clk)
		if(CPU_RDY)
			mux_sel <= {rom_sel,led_sel,gpio_sel,wb_sel,acia_sel,video_sel,basic_sel,ram_sel};
	always @(*)
		casez(mux_sel)
			8'b00000001: CPU_DI = ram_do;
			8'b0000001z: CPU_DI = basic_do;
			8'b000001zz: CPU_DI = video_do;
			8'b00001zzz: CPU_DI = acia_do;
			8'b0001zzzz: CPU_DI = wb_do;
			8'b001zzzzz: CPU_DI = gpio_do;
			8'b01zzzzzz: CPU_DI = led_do;
			8'b1zzzzzzz: CPU_DI = rom_do;
			default: CPU_DI = rom_do;
		endcase
endmodule
