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

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "mlasm.h"

void help(const char *progname)
{
	fprintf(stderr, "Usage: %s [-n] [-t nsecs] [input-file]\n", progname);
	exit(1);
}

int main(int argc, char **argv)
{
	int opt;
	FILE *f = stdin;
	char buffer[4096];

	while ((opt = getopt(argc, argv, "nt:")) != -1)
	{
		switch (opt)
		{
		case 'n':
			printf("Got -n flag.\n");
			break;
		case 't':
			printf("nsecs = %d\n", atoi(optarg));
			break;
		default:
			help(argv[0]);
		}
	}

	if (optind+1 == argc)
	{
		f = fopen(argv[optind++], "r");
		if (f == nullptr) {
			perror("Open input file");
			exit(1);
		}
	}

	if (optind != argc)
		help(argv[0]);
	
	MlAsm worker;

	while (fgets(buffer, 4096, f))
		worker.parseLine(buffer);
	
	worker.assemble();
	worker.printHexFile(stdout);

	return 0;
}
