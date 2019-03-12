# up5k_basic
A small 6502 system with MS BASIC in ROM. This system
includes 32kB SRAM (using one of the four available SPRAM cores), 8 bits
input, 8 bits output, a 9600bps serial I/O port and 12kB of ROM that's
split into 4kB for startup and I/O support and 8kB which is a copy of the
Ohio Scientific C1P 8k Microsoft BASIC.

## prerequisites
To build this you will need the following FPGA tools

* Icestorm - ice40 FPGA tools
* Yosys - Synthesis
* Nextpnr - Place and Route

Info on these can be found at http://www.clifford.at/icestorm/

You will also need the following 6502 tools to build the startup ROM:

* cc65 6502 C compiler (for default option) https://github.com/cc65/cc65

## Building

	git clone https://github.com/emeb/up5k_basic.git
	cd up5k_basic
	git submodule update --init
	cd icestorm
	make

## Loading

I built this system on a upduino and programmed it with a custom USB->SPI
board that I built so you will definitely need to tweak the programming
target of the Makefile in the icestorm directory to match your own hardware.

## Running BASIC

You will need to connect a 9600bps serial terminal port to the TX/RX pins of
the FPGA (depends on your .pcf definitions - pins 3/4 in my build for the
upduino). Load the bitstream an you'll see the boot prompt:

    C/W?

This is asking if you're doing a cold or warm start. Hit "C" (must be
uppercase) and then BASIC will start running. It will prompt you:

    MEMORY SIZE?

to which you answer with 'enter' to let it use all memory. It then prompts
with:

    TERMINAL WIDTH?

Again, hit 'enter' to use the default. It then prints a welcome message and
is ready to accept BASIC commands and code. You can find out more about
how to use this version of BASIC here: https://www.pcjs.org/docs/c1pjs/

## Simulating

Simulation is supported and requires the following prerequisites:

* Icarus Verilog simulator http://iverilog.icarus.com/
* GTKWave waveform viewer http://gtkwave.sourceforge.net/

To simulate, use the following commands

	cd icarus
	make
	make wave

This will build the simulation executable, run it and then view the output.

## Thanks

Thanks to the developers of all the tools used for this, as well as the authors
of the IP cores I snagged for the 6502 and UART. I've added those as submodules
so you'll know where to get them and who to give credit to.
