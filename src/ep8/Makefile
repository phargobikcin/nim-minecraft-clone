NIMC_DEBUG = nim cpp --styleCheck:hint --hint\[Processing\]\:on --excessiveStackTrace\:on  --lineTrace:on --opt:none --gc:orc
NIMC_RELEASE = nim cpp -d:release --styleCheck:hint --gc:orc

BINS = main.bin

all: $(BINS)

%.bin: %.nim
	$(NIMC_RELEASE) $(NIM_PATHS) -o=$@ $<

clean:
	rm -f *.bin *.log
