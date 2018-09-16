/*
 *  Copyright (C) 2018  Clifford Wolf <clifford@symbioticeda.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#include "mlsim.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void help(const char *progname, int rc)
{
	printf("\n");
	printf("Usage: %s [options] [bin-file]\n", progname);
	printf("\n");
	printf("  -h\n");
	printf("    print help message\n");
	printf("\n");
	printf("  -v\n");
	printf("    verbose output\n");
	printf("\n");
	printf("  -r addr\n");
	printf("    start address (default = 0)\n");
	printf("\n");
	printf("  -o filename\n");
	printf("    write Verilog .hex file\n");
	printf("\n");
	printf("  -b filename\n");
	printf("    write binary file\n");
	printf("\n");
	exit(rc);
}

int main(int argc, char **argv)
{
	int opt;
	FILE *fIn = stdin;
	bool verbose = false;
	int start_addr = 0;
	std::string hex_filename;
	std::string bin_filename;

	while ((opt = getopt(argc, argv, "hvr:o:b:")) != -1)
	{
		switch (opt)
		{
		case 'h':
			help(argv[0], 0);
			break;
		case 'v':
			verbose = true;
			break;
		case 'r':
			start_addr = strtol(optarg, nullptr, 0);
			break;
		case 'o':
			hex_filename = optarg;
			break;
		case 'b':
			bin_filename = optarg;
			break;
		default:
			help(argv[0], 1);
		}
	}

	if (optind+1 == argc)
	{
		fIn = fopen(argv[optind++], "r");
		if (fIn == nullptr) {
			perror("Open input file");
			exit(1);
		}
	}

	if (optind != argc)
		help(argv[0], 1);

	MlSim worker;

	if (verbose)
		worker.verbose = true;

	worker.readBinFile(fIn);

	worker.run(start_addr);

	if (!hex_filename.empty()) {
		FILE *fOut = stdout;
		if (hex_filename != "-") {
			fOut = fopen(hex_filename.c_str(), "wt");
			if (fOut == nullptr) {
				perror("Open output hex file");
				exit(1);
			}
		}
		worker.writeHexFile(fOut);
		if (hex_filename != "-")
			fclose(fOut);
	}

	if (!bin_filename.empty()) {
		FILE *fOut = stdout;
		if (bin_filename != "-") {
			fOut = fopen(bin_filename.c_str(), "wt");
			if (fOut == nullptr) {
				perror("Open output bin file");
				exit(1);
			}
		}
		worker.writeBinFile(fOut);
		if (bin_filename != "-")
			fclose(fOut);
	}

	return 0;
}
