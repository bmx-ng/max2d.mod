#!/usr/bin/env python3
"""Run identical scenes sequentially, rotating backend order between repetitions."""
import argparse
import csv
import io
import json
import math
import os
from pathlib import Path
import statistics
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--renderer-exe', required=True)
parser.add_argument('--native-exe', required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--renderer', default='metal')
parser.add_argument('--gpu-driver', default='metal')
parser.add_argument('--frames', type=int, default=360)
parser.add_argument('--repeats', type=int, default=3)
args = parser.parse_args()
if args.frames < 100 or args.repeats < 1:
    parser.error('Use at least 100 frames and one repetition')
args.output.mkdir(parents=True, exist_ok=True)
variants = [('renderer-default', args.renderer_exe, args.renderer),
            ('renderer-gpu', args.renderer_exe, 'gpu'),
            ('native', args.native_exe, '')]
results = []
output_size = None
for repeat in range(args.repeats):
    order = variants[repeat % 3:] + variants[:repeat % 3]
    for scene, sync in [('snow', 0), ('atlas', 0), ('switches', 0), ('snow', 1)]:
        for name, executable, renderer in order:
            stem = f'{repeat+1}-{scene}-vsync{sync}-{name}'
            environment = os.environ.copy()
            environment['SDL_GPU_DRIVER'] = args.gpu_driver
            run = subprocess.run([executable, scene, str(sync), str(args.frames), renderer],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 text=True, env=environment, timeout=120)
            (args.output / (stem + '.csv')).write_text(run.stdout)
            (args.output / (stem + '.stderr')).write_text(run.stderr)
            if run.returncode or '# benchmark complete' not in run.stdout:
                raise RuntimeError(f'{stem} failed: {run.stdout[-1000:]} {run.stderr[-1000:]}')
            expected = f'# backend=native driver={args.gpu_driver}' if name == 'native' else f'# backend=renderer driver={renderer}'
            if expected not in run.stdout.splitlines():
                raise RuntimeError(f'{stem}: requested driver was not selected')
            size = next(line.split('pixels=')[1] for line in run.stdout.splitlines() if 'pixels=' in line)
            if output_size is not None and size != output_size:
                raise RuntimeError(f'{stem}: drawing resolution changed')
            output_size = size
            lines = [line for line in run.stdout.splitlines() if not line.startswith('#')]
            rows = list(csv.DictReader(io.StringIO('\n'.join(lines))))
            if len(rows) != args.frames:
                raise RuntimeError(f'{stem}: incomplete frame capture')
            if any(int(row['visibility_flags']) for row in rows):
                raise RuntimeError(f'{stem}: window occluded, hidden or minimized; capture excluded')
            times = sorted(float(row['total_ms']) for row in rows)
            median = statistics.median(times)
            result = dict(repeat=repeat+1, scene=scene, vsync=sync, backend=name,
                          metadata=[s for s in run.stdout.splitlines() if s.startswith('#')],
                          mean_ms=statistics.mean(times), median_ms=median,
                          p95_ms=times[math.ceil(len(times)*.95)-1],
                          p99_ms=times[math.ceil(len(times)*.99)-1], max_ms=max(times),
                          over_1_5_median=sum(t > median*1.5 for t in times),
                          draw_mean_ms=statistics.mean(float(r['draw_flush_ms']) for r in rows),
                          flip_mean_ms=statistics.mean(float(r['flip_ms']) for r in rows),
                          submissions_per_frame=statistics.mean(int(r['submissions']) for r in rows),
                          vertices_per_frame=statistics.mean(int(r['vertices']) for r in rows))
            results.append(result)
            (args.output / 'summary.json').write_text(json.dumps(results, indent=2)+'\n')
            print(f'{stem}: median {median:.3f} ms, p99 {result["p99_ms"]:.3f} ms', flush=True)
