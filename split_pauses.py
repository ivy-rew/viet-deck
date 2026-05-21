#!/usr/bin/env python3
"""Split audio file at silence pauses, trimming trailing beep from each segment."""
import subprocess, re, os, sys

def silencedetect(path, noise='-30dB', duration=0.5, prefix_filter=''):
    af = f'{prefix_filter}silencedetect=noise={noise}:d={duration}'
    r = subprocess.run(['ffmpeg', '-i', path, '-af', af, '-f', 'null', '-'],
                       capture_output=True, text=True)
    starts = [float(x) for x in re.findall(r'silence_start: ([\d.]+)', r.stderr)]
    ends   = [float(x) for x in re.findall(r'silence_end: ([\d.]+)',   r.stderr)]
    return list(zip(starts, ends))

def duration(path):
    r = subprocess.run(['ffprobe', '-i', path, '-show_entries', 'format=duration',
                        '-v', 'quiet', '-of', 'csv=p=0'], capture_output=True, text=True)
    return float(r.stdout.strip())

def main():
    inp  = sys.argv[1]
    outd = sys.argv[2] if len(sys.argv) > 2 else 'split'
    os.makedirs(outd, exist_ok=True)

    pauses = silencedetect(inp, noise='-30dB', duration=1.0)
    total  = duration(inp)

    # Each segment runs from end of one pause to start of the next.
    # silence_start already marks where the beep begins, so cutting there
    # naturally removes the trailing beep.
    segments = []
    boundaries = [(0.0, pauses[0][0])] if pauses else []
    for i in range(len(pauses) - 1):
        boundaries.append((pauses[i][1], pauses[i+1][0]))
    if pauses:
        boundaries.append((pauses[-1][1], total))

    for (seg_start, seg_end) in boundaries:
        if seg_end - seg_start > 0.15:
            segments.append((seg_start, seg_end))

    print(f"Splitting into {len(segments)} segments → {outd}/")
    base = os.path.splitext(os.path.basename(inp))[0]

    for i, (s, e) in enumerate(segments):
        out = os.path.join(outd, f'{base}_{i+1:03d}.mp3')
        subprocess.run(['ffmpeg', '-y', '-i', inp,
                        '-ss', str(s), '-to', str(e),
                        '-c', 'copy', out],
                       capture_output=True)
        print(f"  {i+1:3d}: {s:8.3f}s – {e:8.3f}s  ({e-s:.2f}s)  → {os.path.basename(out)}")

if __name__ == '__main__':
    main()
