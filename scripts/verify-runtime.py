#!/usr/bin/env python3
"""Verify the actual helper lifecycle without changing global pmset preferences."""
import pathlib, subprocess, time
exe = pathlib.Path(__file__).resolve().parents[1] / 'build/Insomnia.app/Contents/MacOS/Insomnia'
if subprocess.run(['/usr/bin/pgrep', '-x', 'Insomnia'], stdout=subprocess.DEVNULL).returncode == 0:
    raise SystemExit('Quit Insomnia before exercising standalone power helpers.')
for mode in ('stop', 'eof', 'watchdog', 'signal', 'heartbeat'):
    child = subprocess.Popen([str(exe), '--power-helper'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    line = child.stdout.readline().strip()
    assert line == 'READY', line
    active = subprocess.check_output(['/usr/bin/pmset', '-g', 'assertions'], text=True)
    assert f'pid {child.pid}(Insomnia)' in active
    if mode == 'stop': child.stdin.write('STOP\n'); child.stdin.flush()
    elif mode == 'eof': child.stdin.close()
    elif mode == 'signal': child.terminate()
    elif mode == 'heartbeat':
        for _ in range(12):
            child.stdin.write('BEAT\n'); child.stdin.flush(); time.sleep(0.5)
        assert child.poll() is None, 'helper stopped despite valid heartbeats'
        child.stdin.write('STOP\n'); child.stdin.flush()
    child.wait(timeout=8)
    after = subprocess.check_output(['/usr/bin/pmset', '-g', 'assertions'], text=True)
    assert f'pid {child.pid}(Insomnia)' not in after
    marker = pathlib.Path.home() / 'Library/Application Support/StillOnClone/power-owned'
    assert not marker.exists(), f'{mode}: power ownership receipt survived cleanup'
    print(f'PASS {mode}: real assertion acquired and released')
