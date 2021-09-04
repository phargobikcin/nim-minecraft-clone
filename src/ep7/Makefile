NIMC_DEBUG = nim cpp --styleCheck:hint --hint\[Processing\]\:on --excessiveStackTrace\:on  --lineTrace:on --opt:none
NIMC_DEBUG_ORC = $(NIMC_DEBUG) --gc:orc

BINS = main.bin

all: $(BINS)

%.bin: %.nim
	$(NIMC_DEBUG_ORC) $(NIM_PATHS) -o=$@ $<

clean:
	rm -f *.bin *.log
