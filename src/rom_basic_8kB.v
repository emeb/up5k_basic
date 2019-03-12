// rom_basic_8kB.v - 8k byte ROM with BASIC contents
// 03-11-18 E. Brombaugh

module ROM_BASIC_8kB(
    input clk,
    input [12:0] addr,
    output reg [7:0] dout
);
    reg [7:0] memory [0:8191];

    initial
        $readmemh("../src/basic_8k.hex",memory);
    
    // synchronous ROM
    always @(posedge clk)
        dout <= memory[addr];
        
endmodule
