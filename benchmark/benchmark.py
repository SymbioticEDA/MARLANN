#!/usr/bin/env python3
import os, sys, threading
from os import path
import subprocess
import re

num_runs = 50

fmax = {}

if not path.exists("work"):
    os.mkdir("work")

threads = []

for i in range(num_runs):
    def runner(run):
        ascfile = "work/marlann_s{}.asc".format(run)
        if path.exists(ascfile):
            os.remove(ascfile)
        cmd = ["nextpnr-ice40", "--up5k", "--seed", str(run), "--json", "../demo/marlann.json", "--asc", ascfile, "--freq", "25"] #, "--opt-timing"]
        print(' '.join(cmd))
        result = subprocess.run(cmd, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
        if result.returncode != 0:
            print("Run {} failed!".format(run))
        else:
            icetime_res = subprocess.check_output(["icetime", "-d", "up5k", ascfile])
            print(icetime_res)
            fmax_m = re.search(r'\(([0-9.]+) MHz\)', icetime_res.decode('utf-8'))
            fmax[run] = float(fmax_m.group(1))
    threads.append(threading.Thread(target=runner, args=[i+2]))

for t in threads: t.start()
for t in threads: t.join()

fmax_min = min(fmax.values())
fmax_max = max(fmax.values())
fmax_avg = sum(fmax.values()) / len(fmax)

print("{}/{} runs passed".format(len(fmax), num_runs))
print("icetime: min = {} MHz, avg = {} MHz, max = {} MHz".format(fmax_min, fmax_avg, fmax_max))
