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

#include <assert.h>

void MlSim::exec(insn_t insn)
{
	cycle_cnt++;

	if (verbose)
		printf("exec:       %08x (maddr=%05x, caddr=%03x, op=%d)\n",
				insn.x, insn.maddr(), insn.caddr(), insn.op());

	// SetVBP
	if (insn.op() == 8) {
		assert(insn.caddr() == 0);
		VBP = insn.maddr();
		if (trace)
			fprintf(trace, "SetVBP 0x%05x // -> 0x%05x\n", insn.maddr(), VBP);
		return;
	}

	// AddVBP
	if (insn.op() == 9) {
		assert(insn.caddr() == 0);
		VBP = (VBP + insn.maddr()) & 0x1ffff;
		if (trace)
			fprintf(trace, "AddVBP 0x%05x // -> 0x%05x\n", insn.maddr(), VBP);
		return;
	}

	// SetLBP
	if (insn.op() == 10) {
		assert(insn.caddr() == 0);
		LBP = insn.maddr();
		if (trace)
			fprintf(trace, "SetLBP 0x%05x // -> 0x%05x\n", insn.maddr(), LBP);
		return;
	}

	// AddLBP
	if (insn.op() == 11) {
		assert(insn.caddr() == 0);
		LBP = (LBP + insn.maddr()) & 0x1ffff;
		if (trace)
			fprintf(trace, "AddLBP 0x%05x // -> 0x%05x\n", insn.maddr(), LBP);
		return;
	}

	// SetSBP
	if (insn.op() == 12) {
		assert(insn.caddr() == 0);
		SBP = insn.maddr();
		if (trace)
			fprintf(trace, "SetSBP 0x%05x // -> 0x%05x\n", insn.maddr(), SBP);
		return;
	}

	// AddSBP
	if (insn.op() == 13) {
		assert(insn.caddr() == 0);
		SBP = (SBP + insn.maddr()) & 0x1ffff;
		if (trace)
			fprintf(trace, "AddSBP 0x%05x // -> 0x%05x\n", insn.maddr(), SBP);
		return;
	}

	// SetCBP
	if (insn.op() == 14) {
		assert(insn.maddr() == 0);
		CBP = insn.caddr();
		if (trace)
			fprintf(trace, "SetCBP 0x%03x // -> 0x%03x\n", insn.caddr(), CBP);
		return;
	}

	// AddCBP
	if (insn.op() == 15) {
		assert(insn.maddr() == 0);
		CBP = (CBP + insn.caddr()) & 0x1ff;
		if (trace)
			fprintf(trace, "AddCBP 0x%03x // -> 0x%03x\n", insn.caddr(), CBP);
		return;
	}

	// Store/ReLu
	if (insn.op() == 16 || insn.op() == 17 || insn.op() == 18 || insn.op() == 20 || insn.op() == 21 || insn.op() == 22)
	{
		int maddr = (SBP + insn.maddr()) & 0x1ffff;

		assert(insn.caddr() < 32);
		int32_t v0 = acc0 >> insn.caddr();
		int32_t v1 = acc1 >> insn.caddr();

		v0 = std::min(v0, 127);
		v1 = std::min(v1, 127);

		if (insn.op() == 20 || insn.op() == 21 || insn.op() == 22) {
			v0 = std::max(v0, 0);
			v1 = std::max(v1, 0);
		} else {
			v0 = std::max(v0, -128);
			v1 = std::max(v1, -128);
		}

		if (insn.op() == 16 || insn.op() == 17 || insn.op() == 20 || insn.op() == 21) {
			if (verbose)
				printf("write: %02x @%05x\n", v0, maddr);
			main_mem_tags[maddr] = true;
			main_mem[maddr] = v0;
		}

		if (insn.op() == 16 || insn.op() == 18 || insn.op() == 20 || insn.op() == 22) {
			if (verbose)
				printf("write: %02x @%05x\n", v1, maddr+1);
			main_mem_tags[maddr+1] = true;
			main_mem[maddr+1] = v1;
		}

		if (trace) {
			if (insn.op() == 16)
				fprintf(trace, "Store 0x%05x, 0x%03x // 0x%08x 0x%08x -> 0x%02x 0x%02x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc0, acc1, v0, v1, maddr);
			if (insn.op() == 17)
				fprintf(trace, "Store0 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc0, v0, maddr);
			if (insn.op() == 18)
				fprintf(trace, "Store1 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc1, v1, maddr+1);
			if (insn.op() == 20)
				fprintf(trace, "ReLU 0x%05x, 0x%03x // 0x%08x 0x%08x -> 0x%02x 0x%02x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc0, acc1, v0, v1, maddr);
			if (insn.op() == 21)
				fprintf(trace, "ReLU0 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc0, v0, maddr);
			if (insn.op() == 22)
				fprintf(trace, "ReLU1 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc1, v1, maddr+1);
		}
		return;
	}

	// Save
	if (insn.op() == 24 || insn.op() == 25 || insn.op() == 26)
	{
		int maddr = (SBP + insn.maddr()) & 0x1ffff;
		assert(maddr % 2 == 0);

		if (insn.op() == 24 || insn.op() == 25)
		{
			main_mem_tags[maddr] = true;
			main_mem_tags[maddr+1] = true;
			main_mem_tags[maddr+2] = true;
			main_mem_tags[maddr+3] = true;

			main_mem[maddr] = acc0;
			main_mem[maddr+1] = acc0 >> 8;
			main_mem[maddr+2] = acc0 >> 16;
			main_mem[maddr+3] = acc0 >> 24;
		}

		if (insn.op() == 24 || insn.op() == 26)
		{
			main_mem_tags[maddr+4] = true;
			main_mem_tags[maddr+5] = true;
			main_mem_tags[maddr+6] = true;
			main_mem_tags[maddr+7] = true;

			main_mem[maddr+4] = acc1;
			main_mem[maddr+5] = acc1 >> 8;
			main_mem[maddr+6] = acc1 >> 16;
			main_mem[maddr+7] = acc1 >> 24;
		}

		if (trace) {
			if (insn.op() == 24)
				fprintf(trace, "Save 0x%05x, 0x%03x // 0x%08x 0x%08x -> 0x%08x 0x%08x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc0, acc1, acc0, acc1, maddr);
			if (insn.op() == 25)
				fprintf(trace, "Save0 0x%05x, 0x%03x // 0x%08x -> 0x%08x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc0, acc0, maddr);
			if (insn.op() == 26)
				fprintf(trace, "Save1 0x%05x, 0x%03x // 0x%08x -> 0x%08x @ 0x%05x\n", insn.maddr(), insn.caddr(), acc1, acc1, maddr+4);
		}
		return;
	}

	// LdSet/LdAdd
	if (insn.op() == 28 || insn.op() == 29 || insn.op() == 30 ||
			insn.op() == 32 || insn.op() == 33 || insn.op() == 34)
	{
		int maddr = (LBP + insn.maddr()) & 0x1ffff;
		assert(maddr % 2 == 0);

		int32_t v0 = 0;
		v0 |= main_mem[maddr];
		v0 |= main_mem[maddr+1] << 8;
		v0 |= main_mem[maddr+2] << 16;
		v0 |= main_mem[maddr+3] << 24;

		int32_t v1 = 0;
		v1 |= main_mem[maddr+4];
		v1 |= main_mem[maddr+5] << 8;
		v1 |= main_mem[maddr+6] << 16;
		v1 |= main_mem[maddr+7] << 24;

		if (insn.op() == 28 || insn.op() == 29)
			acc0 = v0;

		if (insn.op() == 28 || insn.op() == 30)
			acc1 = v1;

		if (insn.op() == 32 || insn.op() == 33)
			acc0 += v0;

		if (insn.op() == 32 || insn.op() == 34)
			acc1 += v1;

		if (trace) {
			if (insn.op() == 28)
				fprintf(trace, "LdSet 0x%05x // -> 0x%08x 0x%08x\n", insn.maddr(), acc0, acc1);
			if (insn.op() == 29)
				fprintf(trace, "LdSet0 0x%05x // -> 0x%08x\n", insn.maddr(), acc0);
			if (insn.op() == 30)
				fprintf(trace, "LdSet1 0x%05x // -> 0x%08x\n", insn.maddr(), acc1);
			if (insn.op() == 32)
				fprintf(trace, "LdAdd 0x%05x // -> 0x%08x 0x%08x\n", insn.maddr(), acc0, acc1);
			if (insn.op() == 33)
				fprintf(trace, "LdAdd0 0x%05x // -> 0x%08x\n", insn.maddr(), acc0);
			if (insn.op() == 34)
				fprintf(trace, "LdAdd1 0x%05x // -> 0x%08x\n", insn.maddr(), acc1);
		}
		return;
	}

	// MACC/MMAX
	if (insn.op() == 40 || insn.op() == 41 || insn.op() == 42 || insn.op() == 43 || insn.op() == 45)
	{
		int maddr = (VBP + insn.maddr()) & 0x1ffff;
		int caddr = (CBP + insn.caddr()) & 0x1ff;
		assert(maddr % 2 == 0);

		ops_cnt++;

		// MACCZ/MMAXZ
		if ((insn.op() & 2) != 0) {
			acc0 = 0;
			acc1 = 0;
		}

		// MMAXN
		if ((insn.op() & 4) != 0) {
			acc0 = 0x80000000;
			acc1 = 0;
		}

		for (int i = 0; i < 8; i ++)
		{
			int32_t c0 = int8_t(coeff0_mem[caddr] >> (i*8));
			int32_t c1 = int8_t(coeff1_mem[caddr] >> (i*8));
			int32_t m = int8_t(main_mem[maddr+i]);
			int32_t p0 = c0*m, p1 = c1*m;

			if ((insn.op() & 1) != 0) {
				if (uint8_t(c0) != 0x00)
					acc0 = std::max(acc0, p0);
				acc1 += p1;
			} else {
				acc0 += p0;
				acc1 += p1;
			}
		}

		if (trace) {
			uint64_t mdata = 0;
			for (int i = 0; i < 8; i ++)
				mdata |= uint64_t(main_mem[maddr+i]) << (8*i);
			if (insn.op() == 40)
				fprintf(trace, "MACC 0x%05x, 0x%03x // 0x%016llx @ 0x%05x, 0x%016llx 0x%016llx @ 0x%03x -> 0x%08x 0x%08x\n",
						insn.maddr(), insn.caddr(), (long long)mdata, maddr, (long long)coeff0_mem[caddr],
						(long long)coeff1_mem[caddr], caddr, acc0, acc1);
			if (insn.op() == 41)
				fprintf(trace, "MMAX 0x%05x, 0x%03x // 0x%016llx @ 0x%05x, 0x%016llx 0x%016llx @ 0x%03x -> 0x%08x 0x%08x\n",
						insn.maddr(), insn.caddr(), (long long)mdata, maddr, (long long)coeff0_mem[caddr],
						(long long)coeff1_mem[caddr], caddr, acc0, acc1);
			if (insn.op() == 42)
				fprintf(trace, "MACCZ 0x%05x, 0x%03x // 0x%016llx @ 0x%05x, 0x%016llx 0x%016llx @ 0x%03x -> 0x%08x 0x%08x\n",
						insn.maddr(), insn.caddr(), (long long)mdata, maddr, (long long)coeff0_mem[caddr],
						(long long)coeff1_mem[caddr], caddr, acc0, acc1);
			if (insn.op() == 43)
				fprintf(trace, "MMAXZ 0x%05x, 0x%03x // 0x%016llx @ 0x%05x, 0x%016llx 0x%016llx @ 0x%03x -> 0x%08x 0x%08x\n",
						insn.maddr(), insn.caddr(), (long long)mdata, maddr, (long long)coeff0_mem[caddr],
						(long long)coeff1_mem[caddr], caddr, acc0, acc1);
			if (insn.op() == 45)
				fprintf(trace, "MMAXN 0x%05x, 0x%03x // 0x%016llx @ 0x%05x, 0x%016llx 0x%016llx @ 0x%03x -> 0x%08x 0x%08x\n",
						insn.maddr(), insn.caddr(), (long long)mdata, maddr, (long long)coeff0_mem[caddr],
						(long long)coeff1_mem[caddr], caddr, acc0, acc1);
		}
		return;
	}

	abort();
}

void MlSim::run(int addr)
{
	assert(addr < int(main_mem.size()));
	assert(addr % 4 == 0);

	insn_t insn;
	insn.x |= main_mem[addr];
	insn.x |= main_mem[addr+1] << 8;
	insn.x |= main_mem[addr+2] << 16;
	insn.x |= main_mem[addr+3] << 24;

	if (verbose)
		printf("seq: @%05x %08x (maddr=%05x, caddr=%03x, op=%d)\n",
				addr, insn.x, insn.maddr(), insn.caddr(), insn.op());

	// Sync
	if (insn.op() == 0) {
		cycle_cnt += 8;
		return run(addr+4);
	}

	// Call
	if (insn.op() == 1) {
		assert(insn.caddr() == 0);
		run(insn.maddr());
		return run(addr+4);
	}

	// Return
	if (insn.op() == 2) {
		assert(insn.maddr() == 0);
		assert(insn.caddr() == 0);
		return;
	}

	// Execute
	if (insn.op() == 3) {
		int len = insn.maddr();
		assert(len <= 512);
		for (int i = insn.caddr(); i < insn.caddr()+len; i++)
			exec(code_mem[i]);
		return run(addr+4);
	}

	// LoadCode
	if (insn.op() == 4) {
		uint32_t v = 0;
		v |= main_mem[insn.maddr()];
		v |= main_mem[insn.maddr()+1] << 8;
		v |= main_mem[insn.maddr()+2] << 16;
		v |= main_mem[insn.maddr()+3] << 24;
		code_mem[insn.caddr()] = v;
		cycle_cnt++;
		goto continueLoad;
	}

	// LoadCoeff
	if (insn.op() == 5 || insn.op() == 6) {
		uint64_t v = 0;
		v |= uint64_t(main_mem[insn.maddr()]);
		v |= uint64_t(main_mem[insn.maddr()+1]) << 8;
		v |= uint64_t(main_mem[insn.maddr()+2]) << 16;
		v |= uint64_t(main_mem[insn.maddr()+3]) << 24;
		v |= uint64_t(main_mem[insn.maddr()+4]) << 32;
		v |= uint64_t(main_mem[insn.maddr()+5]) << 40;
		v |= uint64_t(main_mem[insn.maddr()+6]) << 48;
		v |= uint64_t(main_mem[insn.maddr()+7]) << 56;
		if (insn.op() == 5)
			coeff0_mem[insn.caddr()] = v;
		else
			coeff1_mem[insn.caddr()] = v;
		cycle_cnt++;
		goto continueLoad;
	}

	// ContinueLoad
	if (0) {
continueLoad:;
		insn_t insn2;
		insn2.x |= main_mem[addr+4];
		insn2.x |= main_mem[addr+5] << 8;
		insn2.x |= main_mem[addr+6] << 16;
		insn2.x |= main_mem[addr+7] << 24;

		if (insn2.op() == 7)
		{
			if (verbose)
				printf("seq: @%05x %08x (maddr=%05x, caddr=%03x, op=%d)\n",
						addr+4, insn2.x, insn2.maddr(), insn2.caddr(), insn2.op());

			int len = insn2.maddr();
			assert(len < 512);

			cycle_cnt += len;

			for (int i = 1; i <= len; i++)
			{
				// LoadCode
				if (insn.op() == 4) {
					uint32_t v = 0;
					v |= main_mem[insn.maddr()+4*i];
					v |= main_mem[insn.maddr()+4*i+1] << 8;
					v |= main_mem[insn.maddr()+4*i+2] << 16;
					v |= main_mem[insn.maddr()+4*i+3] << 24;
					code_mem[insn.caddr()+i] = v;
				}

				// LoadCoeff
				if (insn.op() == 5 || insn.op() == 6) {
					uint64_t v = 0;
					v |= uint64_t(main_mem[insn.maddr()+8*i]);
					v |= uint64_t(main_mem[insn.maddr()+8*i+1]) << 8;
					v |= uint64_t(main_mem[insn.maddr()+8*i+2]) << 16;
					v |= uint64_t(main_mem[insn.maddr()+8*i+3]) << 24;
					v |= uint64_t(main_mem[insn.maddr()+8*i+4]) << 32;
					v |= uint64_t(main_mem[insn.maddr()+8*i+5]) << 40;
					v |= uint64_t(main_mem[insn.maddr()+8*i+6]) << 48;
					v |= uint64_t(main_mem[insn.maddr()+8*i+7]) << 56;
					if (insn.op() == 5)
						coeff0_mem[insn.caddr()+i] = v;
					else
						coeff1_mem[insn.caddr()+i] = v;
				}

			}

			return run(addr+8);
		}

		return run(addr+4);
	}

	exec(insn);
	return run(addr+4);
}

void MlSim::readBinFile(FILE *f)
{
	for (int i = 0; i < int(main_mem.size()); i++) {
		int c = fgetc(f);
		if (c < 0) {
			if (verbose)
				printf("read %d bytes from bin file.\n", i);
			break;
		}
		main_mem[i] = c;
	}
}

void MlSim::writeHexFile(FILE *f)
{
	bool print_addr = true;
	int cnt = 0;

	for (int i = 0; i < int(main_mem_tags.size()); i++) {
		if (!main_mem_tags[i]) {
			if (cnt != 0) {
				fprintf(f, "\n");
				cnt = 0;
			}
			print_addr = true;
		} else {
			if (print_addr) {
				if (verbose)
					printf("new hex file section at 0x%05x.\n", i);
				fprintf(f, "@%05x\n", i);
			}

			if (cnt++ == 16) {
				fprintf(f, "\n");
				cnt = 1;
			} else if (cnt != 1) {
				fprintf(f, " ");
			}

			fprintf(f, "%02x", main_mem[i]);
			print_addr = false;
		}
	}
}

void MlSim::writeBinFile(FILE *f)
{
	if (verbose)
		printf("writing 128 kB bin file.\n");

	fwrite(main_mem.data(), 128*1024, 1, f);
}
