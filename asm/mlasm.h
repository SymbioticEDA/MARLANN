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

#ifndef MLASM_H
#define MLASM_H

#include <stdint.h>
#include <vector>
#include <string>
#include <map>

class MlAsm
{
private:
	enum field_t {
		FIELD_NONE  = 0,
		FIELD_MADDR = 1,
		FIELD_CADDR = 2
	};

	enum state_t {
		STATE_NONE = 0,
		STATE_CODE = 1,
		STATE_DATA = 2
	};

	struct insn_t {
		int position = -1;
		int opcode = -1;
		int maddr = 0;
		int caddr = 0;
	};

	struct symaction_t {
		int insn_idx, factor, divider;
		field_t field;
	};

	struct symbol_t {
		int position = -1;
		std::vector<symaction_t> actions;
	};

	int cursor;
	int linenr;
	state_t state;

	std::vector<uint32_t> data;
	std::vector<bool> data_valid;

	std::vector<insn_t> insns;
	std::map<std::string, symbol_t> symbols;

	void parseArg(const std::string &s, field_t field, int factor = 1, int divider = 1);

public:
	MlAsm()
	{
		cursor = 0;
		linenr = 0;
		state = STATE_NONE;
		data.resize(128 * 1024);
		data_valid.resize(128 * 1024);
	}

	void parseLine(const char *line);
	void assemble();
	void printHexFile(FILE *f);
};

#endif
