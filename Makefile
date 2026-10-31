
#--------------------------------------------------------------------------------
# Makefile for Verilog Simulation (Xcelium) & Synthesis (Genus) & LEC (Conformal)

# Source: VNCHIP Talent Program
# Reference: https://vnchip-inc.com/
#--------------------------------------------------------------------------------

# Num Core
CORE                ?= 4

# Top-level modules
TOP_TB              ?= dma_top_tb
TOP_SYN             ?= dma_top

# Directories
LIB_DIR             := ./libraries/TIMING/CUSTOM ./libraries/TIMING/STDCELL ./libraries/LEF/STDCELL ./libraries/LEF/CUSTOM ./libraries/LEF/IO
RTL_DIR             := ./RTL
LOG_DIR             := ./log
OUT_DIR             := ./output
RPT_DIR             := ./report
SCRIPT_DIR          := ./scripts

# Files
LIB_FILES           := ss_g_1v08_125c.lib ss_hvt_1v08_125c.lib ram_256x16A_slow_syn.lib rom_512x16A_slow_syn.lib pllclk_slow.lib
RTL_LIST            := apb_master.v axi4_ram_slave.v dma_apb_slave_csr.v dma_axi_fifo.v dma_axi_read_master.v dma_axi_write_master.v \
					   dma_main_engine.v dma_top.v

SRCS                := $(wildcard $(RTL_DIR)/*.v)
SRCS_LAB            := $(shell grep -RL "module $(TOP_TB)" $(RTL_DIR))
SNAPSHOT            := simv
VCD                 := $(TOP_TB).vcd
GENUS_SCRIPT        := $(SCRIPT_DIR)/run_syn.tcl
RESTORE_DB_NAME     := syn.db

# GUI settings (1: enable, 0: disable)
GENUS_GUI_ENABLE    ?= 0
LEC_GUI_ENABLE      ?= 1

# Clock name
CLOCK_NAME          := clk
INPUT_DELAY_RATIO   := 0.3
OUTPUT_DELAY_RATIO  := 0.2

CUSTOM_CONSTRAINT_FILE :=

# Set to 1 if it is a combinational circuit
IS_COMBINATIONAL    := 1

# Clock period sweep parameters (in nanoseconds)
START_PERIOD        := 1
END_PERIOD          := 15
STEP                := 1

# Tools
XMVLOG              := bsub -Is -R "span[hosts=1]" -n $(CORE) xmvlog
XMLAB               := bsub -Is -R "span[hosts=1]" -n $(CORE) xmlab
XMSIM               := bsub -Is -R "span[hosts=1]" -n $(CORE) xmsim
SIMVISION           := bsub -Is -R "span[hosts=1]" -n $(CORE) simvision
GENUS               := bsub -Is -R "span[hosts=1]" -n $(CORE) genus
LEC                 := bsub -Is -R "span[hosts=1]" -n $(CORE) lec

# Flags
XMVLOG_FLAGS        := -sv -message -log $(LOG_DIR)/xmvlog.log
XMLAB_FLAGS         := -access +rwc -TIMESCALE 1ns/1ps -message -log $(LOG_DIR)/xmlab.log
XMSIM_FLAGS         := -message -log $(LOG_DIR)/xmsim.log
GENUS_SYN_FLAGS     := -log $(LOG_DIR)/genus_syn.log $(if $(filter 1,$(GENUS_GUI_ENABLE)),-gui,)
GENUS_RESTORE_FLAGS := -log $(LOG_DIR)/genus_restore.log $(if $(filter 1,$(GENUS_GUI_ENABLE)),-gui,)
LEC_FLAGS           := -XL -LOGfile $(LOG_DIR)/lec.log $(if $(filter 0,$(LEC_GUI_ENABLE)),-nogui,)

# Compare LEC effort (Low | Medium | High | SUper | ULtra | Auto | Light | COMPlete)
LEC_EFFORT          := Medium

# Default target
all: clean wave syn lec

compile:
	@mkdir -p $(LOG_DIR)
	@echo "Compiling RTL files..."
	$(XMVLOG) $(XMVLOG_FLAGS) $(SRCS)

build: compile
	@echo "Elaborating top testbench..."
	$(XMLAB) $(XMLAB_FLAGS) -snapshot $(SNAPSHOT) $(TOP_TB)

run: build
	@echo "Running simulation..."
	$(XMSIM) $(XMSIM_FLAGS) $(SNAPSHOT)

wave: run
	@echo "Launching waveform viewer..."
	$(SIMVISION) $(VCD)

#lab_run:
#	@mkdir -p $(LOG_DIR)
#	@echo "Running simulation..."
#	$(XMVLOG) $(XMVLOG_FLAGS) /VNCHIP/TP2025/1_RTL/0_COMMON/code/datapath_tb.v $(SRCS_LAB)
#	$(XMLAB) $(XMLAB_FLAGS) -snapshot $(SNAPSHOT) $(TOP_TB)
#	$(XMSIM) $(XMSIM_FLAGS) $(SNAPSHOT)
#
#lab_wave: lab_run
#	@echo "Launching waveform viewer..."
#	$(SIMVISION) $(VCD)

syn:
	@mkdir -p $(LOG_DIR) $(OUT_DIR) $(RPT_DIR)
	@echo "Running synthesis with Genus..."
	$(GENUS) $(GENUS_SYN_FLAGS) \
		-files $(GENUS_SCRIPT) \
		-execute "set TOP $(TOP_SYN); \
		          set LIB_DIR {$(LIB_DIR)}; \
		          set RTL_DIR {$(RTL_DIR)}; \
		          set OUT_DIR {$(OUT_DIR)}; \
		          set RPT_DIR {$(RPT_DIR)}; \
		          set LIB_FILE {$(LIB_FILES)}; \
		          set RTL_LIST {$(RTL_LIST)}; \
		          set RESTORE_DB_NAME {$(RESTORE_DB_NAME)}; \
		          set GENUS_GUI_ENABLE {$(GENUS_GUI_ENABLE)}; \
		          set CLOCK_NAME {$(CLOCK_NAME)}; \
		          set INPUT_DELAY_RATIO {$(INPUT_DELAY_RATIO)}; \
		          set OUTPUT_DELAY_RATIO {$(OUTPUT_DELAY_RATIO)}; \
		          set CUSTOM_CONSTRAINT_FILE {$(CUSTOM_CONSTRAINT_FILE)}; \
		          set IS_COMBINATIONAL {$(IS_COMBINATIONAL)}; \
		          set START_PERIOD {$(START_PERIOD)}; \
		          set END_PERIOD {$(END_PERIOD)}; \
		          set STEP {$(STEP)};"

restore_syn:
	@echo "Restoring Genus with synthesized design..."
	@mkdir -p $(LOG_DIR)
	$(GENUS) $(GENUS_RESTORE_FLAGS) \
		-execute "read_db -verbose {$(OUT_DIR)/$(RESTORE_DB_NAME)}"

lec:
	mkdir -p $(LOG_DIR) $(RPT_DIR)
	@echo "set TOP $(TOP_SYN)" > tmp_lec_config.tcl
	@echo "set LIB_DIR {$(LIB_DIR)}" >> tmp_lec_config.tcl
	@echo "set RTL_DIR {$(RTL_DIR)}" >> tmp_lec_config.tcl
	@echo "set OUT_DIR {$(OUT_DIR)}" >> tmp_lec_config.tcl
	@echo "set RPT_DIR {$(RPT_DIR)}" >> tmp_lec_config.tcl
	@echo "set LIB_FILE {$(LIB_FILES)}" >> tmp_lec_config.tcl
	@echo "set RTL_LIST {$(RTL_LIST)}" >> tmp_lec_config.tcl
	@echo "set LEC_EFFORT {$(LEC_EFFORT)}" >> tmp_lec_config.tcl
	@echo "set LEC_GUI_ENABLE {$(LEC_GUI_ENABLE)}" >> tmp_lec_config.tcl
	@echo "Running Conformal LEC for top: $(TOP)"
	$(LEC) $(LEC_FLAGS) -Dofile $(SCRIPT_DIR)/run_lec.tcl

clean:
	@echo "Cleaning up..."
	rm -rf *.vcd *.dsn *.trn xcelium.d fv *tmp* *tstamp $(LOG_DIR) $(OUT_DIR) $(RPT_DIR)

.PHONY: all compile build run wave syn restore_syn lec clean
