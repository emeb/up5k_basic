// acia.v - strippped-down version of MC6850 ACIA wrapped around FOSS UART
// 03-02-19 E. Brombaugh

module acia(
	input clk,				// system clock
	input rst,				// system reset
	input cs,				// chip select
	input we,				// write enable
	input rs,				// register select
	input rx,				// serial receive
	input [7:0] din,		// data bus input
	output reg [7:0] dout,	// data bus output
	output tx,				// serial transmit
	output irq				// high-true interrupt request
);
	// generate transmit signal on write to register 1
	wire transmit = cs & rs & we;
	
	// load control register
	reg [1:0] counter_divide_select, transmit_control;
	reg [2:0] word_select;
	reg receive_interrupt_enable;
	always @(posedge clk)
	begin
		if(rst)
		begin
			counter_divide_select <= 2'b00;
			word_select <= 3'b000;
			transmit_control <= 2'b00;
			receive_interrupt_enable <= 1'b0;
		end
		else if(cs & ~rs & we)
			{
				receive_interrupt_enable,
				transmit_control,
				word_select,
				counter_divide_select
			} <= din;
	end
	
	// acia reset generation
	wire acia_rst = rst | (counter_divide_select == 2'b11);
	
	// load dout with either status or rx data
	wire [7:0] rx_byte, status;
	always @(posedge clk)
	begin
		if(rst)
		begin
			dout <= 8'h00;
		end
		else
		begin
			if(cs & ~we)
			begin
				if(rs)
					dout <= rx_byte;
				else
					dout <= status;
			end
		end
	end
	
	// tx empty is cleared when transmit starts, cleared when is_transmitting deasserts
	reg txe;
	wire is_transmitting;
	reg prev_is_transmitting;
	always @(posedge clk)
	begin
		if(rst)
		begin
			txe <= 1'b1;
			prev_is_transmitting <= 1'b0;
		end
		else
		begin
			prev_is_transmitting <= is_transmitting;
			
			if(transmit)
				txe <= 1'b0;
			else if(prev_is_transmitting & ~is_transmitting)
				txe <= 1'b1;
		end
	end
	
	// rx full is set when received pulses, cleared when data reg read
	wire received;
	reg rxf;
	always @(posedge clk)
	begin
		if(rst)
			rxf <= 1'b0;
		else
		begin
			if(received)
				rxf <= 1'b1;
			else if(cs & rs & ~we)
				rxf <= 1'b0;
		end
	end
	
	// assemble status byte
	wire recv_error;
	assign status = 
	{
		irq,				// bit 7 = irq - forced inactive
		1'b0,				// bit 6 = parity error - unused
		recv_error,			// bit 5 = overrun error - same as all errors
		recv_error,			// bit 4 = framing error - same as all errors
		1'b0,				// bit 3 = /CTS - forced active
		1'b0,				// bit 2 = /DCD - forced active
		txe,				// bit 1 = transmit empty
		rxf					// bit 0 = receive full
	};
		
	// instantiate the simplified UART core
	wire is_receiving;	// unused
    uart #(
        .baud_rate(115200),            // default is 9600
        .sys_clk_freq(16000000)      // default is 100000000
     )
    uart_i(
        .clk(clk),                        // The master clock for this module
        .rst(acia_rst),                   // Synchronous reset
        .rx(rx),                          // Incoming serial line
        .tx(tx),                          // Outgoing serial line
        .transmit(transmit),              // Signal to transmit
        .tx_byte(din),                    // Byte to transmit       
        .received(received),              // Indicated that a byte has been received
        .rx_byte(rx_byte),                // Byte received
        .is_receiving(is_receiving),      // Low when receive line is idle
        .is_transmitting(is_transmitting),// Low when transmit line is idle
        .recv_error(recv_error)           // Indicates error in receiving packet.
    );
	
	// generate IRQ
	assign irq = (rxf & receive_interrupt_enable) | ((transmit_control==2'b01) & txe);

endmodule
