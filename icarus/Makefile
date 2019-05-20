# Makefile for Icarus Verilog simulation
# 02-11-2019 E. Brombaugh

# sources
SOURCES =	tb_tst_6502.v ../src/tst_6502.v ../src/acia.v ../src/ram_32kb.v \
			../src/video.v ../src/vram_32kb.v ../src/satsu.v ../src/rom_cg_2kB.v \
			../src/system_bus.v ../src/wishbone.v ../src/led_pwm.v \
			../src/ps2.v ../src/snd.v \
			../verilog-6502/cpu.v ../verilog-6502/ALU.v \
			../osdvu/uart.v
        
# preparing the machine code
HEX =	rom.hex

# top level
TOP = tb_tst_6502
			
# Executables
VLOG = iverilog
WAVE = gtkwave
TECH_LIB = /usr/local/share/yosys/ice40/cells_sim.v
ASM6502 = acme
HEXDUMP = hexdump
HEXDUMP_ARGS = -v -e '1/1 "%02x " "\n"'

# targets
all: $(TOP).vcd

$(HEX):
	$(MAKE) -C ../cc65/
	cp ../cc65/$(HEX) .
			
wave: $(TOP).vcd $(TOP).gtkw
	$(WAVE) $(TOP).gtkw
	
$(TOP).vcd: $(TOP)
	./$(TOP)

$(TOP): $(SOURCES) $(HEX)
	$(VLOG) -D icarus -l $(TECH_LIB) -o $(TOP) $(SOURCES)
	
clean:
	rm -rf a.out *.obj $(HEX) $(RPT) $(TOP) $(TOP).vcd
	
