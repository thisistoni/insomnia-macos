#!/usr/bin/env python3
"""Verify the actual helper lifecycle without changing global pmset preferences."""
import pathlib
import subprocess
import time

exe = pathlib.Path(__file__).resolve().parents[1] / 'build/Insomnia.app/Contents/MacOS/Insomnia'
marker = pathlib.Path.home() / 'Library/Application Support/StillOnClone/power-owned'
if subprocess.run(['/usr/bin/pgrep', '-x', 'Insomnia'], stdout=subprocess.DEVNULL).returncode == 0:
    raise SystemExit('Quit Insomnia before exercising standalone power helpers.')

cases = [(mode, []) for mode in ('stop', 'eof', 'watchdog', 'signal', 'heartbeat')]
cases += [('display-sleep', ['--allow-display-sleep']), ('idle', ['--allow-idle'])]
for mode, flags in cases:
    child = subprocess.Popen(
        [str(exe), '--power-helper', *flags],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    owner = f'pid {child.pid}(Insomnia):'
    try:
        line = child.stdout.readline().strip()
        assert line == 'READY', line
        assert marker.exists(), f'{mode}: power ownership receipt missing'
        active = subprocess.check_output(['/usr/bin/pmset', '-g', 'assertions'], text=True)
        owned = '\n'.join(line for line in active.splitlines() if owner in line)
        assert ('PreventUserIdleSystemSleep' in owned) == (mode != 'idle'), owned
        assert ('PreventUserIdleDisplaySleep' in owned) == (not flags), owned
        if mode == 'eof':
            child.stdin.close()
        elif mode == 'signal':
            child.terminate()
        elif mode != 'watchdog':
            if mode == 'heartbeat':
                for _ in range(12):
                    child.stdin.write('BEAT\n')
                    child.stdin.flush()
                    time.sleep(0.5)
                assert child.poll() is None, 'helper stopped despite valid heartbeats'
            child.stdin.write('STOP\n')
            child.stdin.flush()
        child.wait(timeout=8)
        assert child.returncode == 0, f'{mode}: helper exited with {child.returncode}'
        after = subprocess.check_output(['/usr/bin/pmset', '-g', 'assertions'], text=True)
        assert owner not in after
        assert not marker.exists(), f'{mode}: power ownership receipt survived cleanup'
        print(f'PASS {mode}: expected system/display assertions and complete cleanup')
    finally:
        if child.poll() is None:
            child.terminate()
            child.wait(timeout=8)
