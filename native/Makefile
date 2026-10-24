# Native (C) Stata plugins of the nwergm package: ergm_mcmc.
# Output: ../lib/plugins/<platform>/<plugin>_<platform>.plugin (the platform suffix matters for `net install`,
# which flattens all files into one folder). spi/ holds StataCorp's plugin interface (SPI 3.0, redistributed as
# published at https://www.stata.com/plugins/); it is not this package's own code.
#   make macos    universal (x86_64 + arm64) binaries, run on macOS
#   make unix     Linux (run on a Linux host or the CI runner)
# Windows (Visual Studio x64 prompt): cl /LD /DSYSTEM=STWIN32 /I spi <plugin>.c spi\stplugin.c /Fe:..\lib\plugins\windows\<plugin>_windows.plugin

CC = clang
CFLAGS = -O2 -Wall -Ispi

.PHONY: macos unix clean macos-ergm_mcmc unix-ergm_mcmc

macos: macos-ergm_mcmc

unix: unix-ergm_mcmc

macos-ergm_mcmc:
	mkdir -p ../lib/plugins/macos
	$(CC) -bundle -o ergm_mcmc.x86_64 ergm_mcmc.c spi/stplugin.c \
		-DSYSTEM=APPLEMAC -target x86_64-apple-macos10.11 $(CFLAGS)
	$(CC) -bundle -o ergm_mcmc.arm64 ergm_mcmc.c spi/stplugin.c \
		-DSYSTEM=APPLEMAC -target arm64-apple-macos11 $(CFLAGS)
	lipo -create -output ../lib/plugins/macos/ergm_mcmc_macos.plugin ergm_mcmc.x86_64 ergm_mcmc.arm64
	codesign -s - ../lib/plugins/macos/ergm_mcmc_macos.plugin
	rm -f ergm_mcmc.x86_64 ergm_mcmc.arm64
	@echo "Built ../lib/plugins/macos/ergm_mcmc_macos.plugin"

unix-ergm_mcmc:
	mkdir -p ../lib/plugins/unix
	gcc -shared -fPIC -DSYSTEM=OPUNIX $(CFLAGS) -o ../lib/plugins/unix/ergm_mcmc_unix.plugin \
		ergm_mcmc.c spi/stplugin.c -ldl
	@echo "Built ../lib/plugins/unix/ergm_mcmc_unix.plugin"

clean:
	rm -f ergm_mcmc.x86_64 ergm_mcmc.arm64 ../lib/plugins/macos/ergm_mcmc_macos.plugin ../lib/plugins/unix/ergm_mcmc_unix.plugin
