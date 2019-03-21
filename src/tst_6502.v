// tst_6502.v - test 6502 core
// 02-11-19 E. Brombaugh

module tst_6502(
    input clk,              // 4..0MHz CPU clock
    input reset,            // Low-true reset
    
    output luma, sync,      // B/W video outputs
    
	output reg [7:0] gpio_o,
	input [7:0] gpio_i,
	
	input RX,				// serial RX
	output TX,				// serial TX
    
    output CPU_IRQ          // diagnostic
);
    // The 6502
    wire [15:0] CPU_AB;
    reg [7:0] CPU_DI;
    wire [7:0] CPU_DO;
    wire CPU_WE, CPU_IRQ;
    cpu ucpu(
        .clk(clk),
        .reset(reset),
        .AB(CPU_AB),
        .DI(CPU_DI),
        .DO(CPU_DO),
        .WE(CPU_WE),
        .IRQ(CPU_IRQ),
        .NMI(1'b0),
        .RDY(1'b1)
    );
    
	// address decode
	wire ram_sel = (CPU_AB[15] == 1'b0) ? 1 : 0;
	wire basic_sel = ((CPU_AB[15:12] == 4'ha)||(CPU_AB[15:12] == 4'hb)) ? 1 : 0;
	wire video_sel = (CPU_AB[15:10] == 6'h34) ? 1 : 0;
    wire gpio_sel = (CPU_AB[15:10] == 6'h37) ? 1 : 0;
	wire acia_sel = (CPU_AB[15:8] == 8'hf0) ? 1 : 0;
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
    VIDEO uvid(
        .clk(clk),
        .reset(reset),
        .sel(video_sel),
        .we(CPU_WE),
        .addr(CPU_AB[9:0]),
        .din(CPU_DO),
        .dout(video_do),
        .luma(luma),
        .sync(sync)
    );
        
	// 1kB GPIO @ DC00-DFFF
	reg [7:0] gpio_do;
	always @(posedge clk)
		if((CPU_WE == 1'b1) && (gpio_sel == 1'b1))
			gpio_o <= CPU_DO;
	always @(posedge clk)
		gpio_do <= gpio_i;
	
	// 256B ACIA @ F000-F0FF
	wire [7:0] acia_do;
	acia uacia(
		.clk(clk),				// system clock
		.rst(reset),			// system reset
		.cs(acia_sel),			// chip select
		.we(CPU_WE),			// write enable
		.rs(CPU_AB[0]),			// register select
		.rx(RX),				// serial receive
		.din(CPU_DO),			// data bus input
		.dout(acia_do),			// data bus output
		.tx(TX),				// serial transmit
		.irq(CPU_IRQ)			// interrupt request
	);
	
	// 2kB ROM @ f800-ffff
    reg [7:0] rom_mem[2047:0];
	reg [7:0] rom_do;
	initial
        $readmemh("rom.hex",rom_mem);
	always @(posedge clk)
		rom_do <= rom_mem[CPU_AB[10:0]];

	// data mux
	reg [5:0] mux_sel;
	always @(posedge clk)
		mux_sel <= {rom_sel,acia_sel,gpio_sel,video_sel,basic_sel,ram_sel};
	always @(*)
		casez(mux_sel)
			6'b000001: CPU_DI = ram_do;
			6'b00001z: CPU_DI = basic_do;
			6'b0001zz: CPU_DI = video_do;
			6'b001zzz: CPU_DI = gpio_do;
			6'b01zzzz: CPU_DI = acia_do;
			6'b1zzzzz: CPU_DI = rom_do;
			default: CPU_DI = rom_do;
		endcase
endmodule
