import subprocess
import re
import os
import math
import json
import glob
import traceback

from icecream import ic
import numpy as np
import librosa
from tqdm import tqdm
import click

doplot = False
if not doplot:
    ic.disable()


def gather(fname):
    ic(fname)
    m = []
    data = subprocess.check_output(
        ["aubio", "melbands", "-B", "256", "-H", "128", fname]
    )
    for line in data.split(b"\n"):
        num_strings = re.findall(r"[-+]?(?:\d*\.*\d+)", line.decode())
        nums = []
        for num in num_strings:
            nums.append(float(num))
        if len(nums) == 41:
            m.append(nums)
    mn = np.array(m)
    mn_avg = list(np.mean(mn, axis=0))
    mn_avg = mn_avg[1:]
    ic(np.sum(mn_avg[:2]))
    return mn_avg


def analyze(fname):
    ic(fname)
    duration = librosa.get_duration(filename=fname)
    match = re.search("beats(\d+)", fname)
    beats = 0
    if match:
        beats = int(match.group(1))
    if beats == 0:
        raise "could not parse beats"
    segments = beats * 2
    ic(fname, duration, beats, segments)
    os.system(
        f"sox {fname} output.wav trim 0 {duration/beats/2} : newfile : restart 2>/dev/null"
    )

    if doplot:
        import matplotlib.pyplot as plt

    legend = []
    ys = []
    for i in range(segments):
        legend.append(str(i + 1))
        y = gather2(f"output{i+1:03}.wav")
        x = np.arange(len(y))
        ys.append(np.sum(y[:204]))
        ic(ys)
        if doplot:
            plt.plot(x, y)

    max_val = np.amax(ys)
    kick = []
    for v in ys:
        if v > max_val / 2:
            p = v / max_val * 0.5
            kick.append(p)
        else:
            kick.append(0)
    kick = librosa.amplitude_to_db(kick)
    with open(fname + ".json", "w") as f:
        f.write(json.dumps(list(kick)))

    if doplot:
        plt.legend(legend, loc="upper right")
        plt.savefig("test.png")
        plt.close("all")
        plt.plot(np.arange(len(ys)), ys)
        plt.savefig("test2.png")


def gather2(fname):
    ic(fname)
    data = subprocess.check_output(
        ["sox", fname, "-n", "stat", "-freq"], stderr=subprocess.STDOUT
    )
    vals = dict()
    for i in range(435):
        vals[i] = []
    for line in data.split(b"\n"):
        foo = line.decode().split()
        if len(foo) != 2:
            continue
        try:
            freq = int(round(math.log10(float(foo[0])) * 100))
            power = float(foo[1])
            vals[freq].append(power)
        except:
            pass

    data = []
    for i in range(435):
        if len(vals[i]) == 0:
            data.append(0)
        else:
            data.append(np.mean(vals[i]))
    return data


@click.command()
@click.option("--folder", help="folder to analyze", required=True)
def hello(folder):
    for fname in tqdm(list(glob.glob(folder + "/*.flac"))):
        if "slow" in fname:
            continue
        try:
            analyze(fname)
        except Exception as e:
            traceback.print_exc()
            os.remove(fname)


if __name__ == "__main__":
    hello()
