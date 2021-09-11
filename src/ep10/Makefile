
NIMC_DEBUG_SLOW = nim cpp --verbosity:3 --styleCheck:hint --hint\[Processing\]\:on --excessiveStackTrace\:on --lineTrace:on -x -a --opt:none --gc:orc

# note debug has optimsations on.  It is still debug,  why so black and white?
NIMC_DEBUG = nim cpp --verbosity:3 --styleCheck:hint --hint\[Processing\]\:on --excessiveStackTrace\:on --lineTrace:on -x -a --opt:speed --gc:orc

NIMC_PROFILE = $(NIMC_DEBUG) --profiler:on --stacktrace:on

NIMC_RELEASE = nim cpp -d:release --styleCheck:hint --hint\[Processing\]\:on --gc:orc

NIMC_DANGER = nim cpp -d:danger -d:lto --gc:orc

BINS = main.bin

all: $(BINS)

%.bin: %.nim
	$(NIMC_RELEASE) $(NIM_PATHS) -o=$@ $<

clean:
	rm -f *.bin *.log
