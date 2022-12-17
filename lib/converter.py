#!/usr/bin/python3

import glob
import re
import os
import hashlib

import librosa
from icecream import ic


def sha256sum(filename):
    h = hashlib.sha256()
    b = bytearray(128 * 1024)
    mv = memoryview(b)
    with open(filename, "rb", buffering=0) as f:
        while n := f.readinto(mv):
            h.update(mv[:n])
    return h.hexdigest()


def convert(filepath):
    filename = os.path.basename(filepath)
    numbers = [int(s) for s in re.findall(r"\b\d+\b", filename)]
    bpm_known = 0
    for num in numbers:
        if num > 100 and num < 220:
            bpm_known = num
    duration = librosa.get_duration(filename=filepath)
    bpm_calculated = 0
    for beats in [2, 4, 8, 16, 32, 64]:
        bpm_calculated = 60 / (duration / beats)
        if bpm_calculated > 110 and bpm_calculated < 200:
            bpm_calculated = int(round(bpm_calculated, 0))
            break
    bpm = bpm_known
    if bpm == 0:
        bpm = bpm_calculated
    beats = int(round(duration / (60 / bpm)))
    if beats % 2 == 1 or bpm > 220:
        return
    filehash = sha256sum(filepath)
    filehash = filehash[:8]
    ic(filename, filehash, bpm_known, bpm_calculated, duration, bpm, beats)
    new_filepath = f"amens/amen_{filehash}_beats{beats}_bpm{bpm}.flac"
    cmd = f"sox '{filepath}' '{new_filepath}' norm gain -3"
    print(cmd)
    os.system(cmd)


# part 1
# folders = [
#     "Rhythm Lab The Ultimate Amen Breaks Pack/SAMPLED AND REMIXED",
#     "Amen Breaks Compilation",
# ]
# files = []
# for folder in folders:
#     for fname in glob.glob(folder + "/*.wav"):
#         files.append(fname)
#     for fname in glob.glob(folder + "/*/*/*.wav"):
#         files.append(fname)

# files = list(set(files))
# print(f"found {len(files)} files")
# for filepath in files:
#     convert(filepath)

# part 2
files = []
for fname in glob.glob("amens/*flac"):
    if ".slow." in fname:
        continue
    duration = librosa.get_duration(filename=fname)
    cmd = f"sox '{fname}' '{fname}.slow.flac' tempo -s 0.125 highpass 30 phaser 0.9 0.85 4 0.23 1.3 -s deemph trim 0 {duration*2}"
    ic(cmd)
    os.system(cmd)
