#!/usr/bin/env python3
"""Build a committed library snapshot with the current common benchmark harness, without changing checkout state."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('ref', help='Committed library version to benchmark')
parser.add_argument('--span', action='store_true', help='Use the safe array encoding entry point')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--direct-c', choices=['copy', 'into'], help='Use direct C APIs with copied C output or Foundation output storage')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
snapshot = Path(tempfile.mkdtemp(prefix='webp-benchmark-source-'))
archive = subprocess.check_output(['git', 'archive', args.ref], cwd=repo)
subprocess.run(['tar', '-xf', '-', '-C', str(snapshot)], input=archive, check=True)
# Use exactly the same driver and dependency lock for every measured library variant.
shutil.copyfile(repo / 'Benchmark/Package.swift', snapshot / 'Benchmark/Package.swift')
shutil.copyfile(repo / 'Benchmark/Package.resolved', snapshot / 'Benchmark/Package.resolved')
harness = snapshot / 'Benchmark/Sources/MemoryExperiment'
harness.mkdir(parents=True, exist_ok=True)
shutil.copyfile(repo / 'Benchmark/Sources/MemoryExperiment/main.swift', harness / 'main.swift')
command = ['swift', 'build', '--package-path', str(snapshot / 'Benchmark'), '-c', 'release',
           '--disable-automatic-resolution', '--product', 'MemoryExperiment']
if args.span:
    command += ['-Xswiftc', '-DEXPERIMENT_SPAN']
if args.direct_c:
    command += ['-Xswiftc', '-DDIRECT_C_' + args.direct_c.upper()]
subprocess.run(command, check=True)
binpath = subprocess.check_output(['swift', 'build', '--package-path', str(snapshot / 'Benchmark'),
                                   '-c', 'release', '--show-bin-path'], text=True).strip()
args.output.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(Path(binpath) / 'MemoryExperiment', args.output)
args.output.chmod(0o755)
print(f'Built {args.ref} at {args.output}; source snapshot retained at {snapshot}')
