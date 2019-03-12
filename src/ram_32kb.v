// ram_32kb.v - 32k byte inferred RAM
// 03-11-18 E. Brombaugh

module RAM_32kB(
    input clk,
    input sel,
    input we,
    input [14:0] addr,
    input [7:0] din,
    output reg [7:0] dout
);
//`define SIMULATE
`ifdef SIMULATE
	integer i;
    reg [7:0] memory[0:32767];
	
	// clear RAM to avoid simulation errors
	initial
		for (i = 0; i < 32768; i = i +1)
			memory[i] <= 0;
    
    // synchronous write
    always @(posedge clk)
        if(sel & we)
            memory[addr] <= din;
    
    // synchronous read
    always @(posedge clk)
        dout <= memory[addr];
`else
	wire [15:0] data;
	
    // instantiate the big RAM
	SB_SPRAM256KA mem (
		.ADDRESS(addr[14:1]),
		.DATAIN({din,din}),
		.MASKWREN(addr[0]?4'b1100:4'b0011),
		.WREN(we),
		.CHIPSELECT(sel),
		.CLOCK(clk),
		.STANDBY(1'b0),
		.SLEEP(1'b0),
		.POWEROFF(1'b1),
		.DATAOUT(data)
	);
    
    // pipeline the output select
    reg hilo_sel;
    always @(posedge clk)
        hilo_sel <= addr[0];
	
	always @(*)
		dout = hilo_sel ? data[15:8] : data[7:0];
`endif
endmodule
