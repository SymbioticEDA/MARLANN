#!/usr/bin/python3
import sys

instructions = [ 'Sync', 'Call', 'Return', 'Execute', 'LoadCode', 'LoadCoeff0', 'LoadCoeff1', 'ContinueLoad', 'SetVBP', 'AddVBP', 'SetLBP', 'AddLBP', 'SetSBP', 'AddSBP', 'SetCBP', 'AddCBP', 'Store', 'Store0', 'Store1', '---', 'ReLU', 'ReLU0', 'ReLU1', '---', 'Save', 'Save0', 'Save1', '---', 'LdSet', 'LdSet0', 'LdSet1', '---', 'LdAdd', 'LdAdd0', 'LdAdd1', '---', '---', '---', '---', '---', 'MACC', 'MMAX', 'MACCZ', 'MMAXZ', '---', 'MMAXN' ]

def main(argv0, *args):
    fh_in  = sys.stdin
    fh_out = sys.stdout
    # Repeat ...
    while True:
        # Read input until we get a full VCD input
        l = fh_in.readline()
        if not l:
            return 0
        
        try:
            fh_out.write("%s\n" % instructions[0b111111 & int(l,16)])
        except IndexError:
            fh_out.write("no instruction\n")
        except ValueError:
            fh_out.write("undefined\n")

        fh_out.flush()

if __name__ == '__main__':
    sys.exit(main(*sys.argv))
