#!/usr/bin/env python3
"""Compare prebuilt release executables in alternating process order; never builds during measurement."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--binary', action='append', required=True, metavar='NAME=PATH')
parser.add_argument('--stages', nargs='+', choices=['encode', 'decode', 'reuse', 'inspect'])
parser.add_argument('--fixtures', type=Path, required=True)
parser.add_argument('--repeats', type=int, default=5)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
binaries = [argument.split('=', 1) for argument in args.binary]
cases = [('encode', 1920, 1080, 10), ('decode', 1920, 1080, 30), ('reuse', 1920, 1080, 30),
         ('encode', 3840, 2160, 5), ('decode', 3840, 2160, 20), ('reuse', 3840, 2160, 20),
         ('inspect', 32, 32, 100000)]
if args.stages:
    cases = [case for case in cases if case[0] in args.stages]
records = []
args.output.parent.mkdir(parents=True, exist_ok=True)
for repeat in range(args.repeats):
    for mode, width, height, iterations in cases:
        ordered = binaries if repeat % 2 == 0 else list(reversed(binaries))
        for variant, path in ordered:
            output = subprocess.check_output([path, mode, str(width), str(height), str(iterations), str(args.fixtures / f'{width}x{height}.webp')], text=True)
            record = json.loads(output)
            record.update(variant=variant, repeat=repeat + 1)
            records.append(record)
            args.output.write_text(json.dumps(records, indent=2) + '\n')
    print(f'Finished paired repetition {repeat + 1}/{args.repeats}', flush=True)
# Identical outputs are required when executables provide content hashes.
for mode, width, height, _ in cases:
    matching = [record for record in records if record['mode'] == mode and record['width'] == width]
    for key in ['encoded_bytes', 'encoded_hash', 'decoded_hash']:
        values = {record[key] for record in matching if key in record}
        if len(values) != 1:
            raise SystemExit(f'Output mismatch: {mode} {width}x{height} {key}: {values}')
