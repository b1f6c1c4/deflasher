VIVADO?=vivado
DESIGN=$(wildcard design/*.v)
CONSTR=$(wildcard constr/*.xdc)
XCI=$(wildcard ip/*.xci)

program: script/program.tcl build/output.bit
	(cd build/ && $(VIVADO) -mode batch -source ../$< 2>&1) | ./script/log_highlight.sh

build/output.bit: script/run.tcl $(DESIGN) $(CONSTR) $(XCI)
	mkdir -p build/
	(cd build/ && $(VIVADO) -mode batch -source ../$< 2>&1) | ./script/log_highlight.sh

clean:
	rm -rf build/

.PHONY: program clean
