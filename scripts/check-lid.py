#!/usr/bin/env python3
"""Record real job continuity for a user-operated closed-lid check.

No assertions or power changes: Insomnia must keep this job running itself.
Output stays local in the ignored build directory.
"""
import argparse
import json
import pathlib
import plistlib
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--seconds', type=int, default=900)
args = parser.parse_args()
output = pathlib.Path(__file__).resolve().parents[1] / 'build/hardware/lid-check.jsonl'
output.parent.mkdir(parents=True, exist_ok=True)

def properties(name):
    try:
        raw = subprocess.check_output(['/usr/sbin/ioreg', '-a', '-r', '-n', name], timeout=2)
        entries = plistlib.loads(raw)
        return entries[0] if entries else {}
    except (subprocess.SubprocessError, ValueError, IndexError):
        return {}

end = time.time() + args.seconds
with output.open('w') as log:
    while time.time() < end:
        root = properties('IOPMrootDomain')
        battery = properties('AppleSmartBattery')
        json.dump({'timestamp': time.time(), 'lid_closed': root.get('AppleClamshellState'),
                   'external_power': battery.get('ExternalConnected')}, log)
        log.write('\n')
        log.flush()
        time.sleep(1)
print(f'Continuity log: {output}')
