# Makefile for SMBus UVM IP Verification
SHELL := /bin/bash
PROJECT_ROOT := $(abspath ..)
WORK_DIR := $(PROJECT_ROOT)/sim/work
LOG_DIR := $(PROJECT_ROOT)/log
NUM_SLAVE ?= 1

TESTS := reset_test idle_test start_stop_test write_test read_test ack_test nack_test multi_byte_test restart_test random_test

.PHONY: all clean compile regression topo_regression $(TESTS)

all: compile regression topo_regression

compile:
	./compile.sh $(NUM_SLAVE)

regression:
	@echo "Starting Regression for TC001~TC010 (NUM_MASTER=1, NUM_SLAVE=1)..."
	@mkdir -p $(LOG_DIR)
	./compile.sh 1
	@for t in $(TESTS); do \
		echo "Running $$t..."; \
		./run.sh $$t || exit 1; \
	done
	@echo "All legacy tests completed successfully!"

topo_regression:
	@echo "Starting Topology Regression (1:1, 2:1, 1:2, 2:2)..."
	@mkdir -p $(LOG_DIR)
	./compile.sh 1
	./run.sh topo_1x1_test
	./run.sh topo_2x1_test
	./compile.sh 2
	./run.sh topo_1x2_test
	./run.sh topo_2x2_test
	@echo "All topology tests (1:1, 2:1, 1:2, 2:2) completed successfully!"

$(TESTS):
	./run.sh $@

clean:
	rm -rf work opt_top transcript *.vstf *.wlf $(LOG_DIR)/*.log
