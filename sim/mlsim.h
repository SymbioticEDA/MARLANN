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

#ifndef MLSIM_H
#define MLSIM_H

#include <stdint.h>
#include <stdio.h>
#include <vector>
#include <string>
#include <map>

class MlSim
{
private:

public:
	struct insn_t {
		uint32_t x;

		insn_t(uint32_t x = 0) : x(x) { }

		int op() { return x & 0x3f; }
		int maddr() { return x >> 15; }
		int caddr() { return (x >> 6) & 0x1ff; }
	};

	bool verbose = false;

	std::vector<uint8_t> main_mem;
	std::vector<bool> main_mem_tags;

	std::vector<uint32_t> code_mem;
	std::vector<uint64_t> coeff0_mem;
	std::vector<uint64_t> coeff1_mem;

	MlSim()
	{
		main_mem.resize(128 * 1024);
		main_mem_tags.resize(128 * 1024);

		code_mem.resize(512);
		coeff0_mem.resize(512);
		coeff1_mem.resize(512);
	}

	void run(int addr);
	void readBinFile(FILE *f);
	void writeHexFile(FILE *f);
	void writeBinFile(FILE *f);
};

#endif
