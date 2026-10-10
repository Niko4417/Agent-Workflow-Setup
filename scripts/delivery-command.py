#!/usr/bin/env python3
"""Run gated delivery argv at the explicit verified Git root, without a shell."""
import importlib.util
from pathlib import Path
import subprocess
import sys

spec = importlib.util.spec_from_file_location('delivery_hook', Path(__file__).resolve().with_name('delivery-hook.py'))
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)

if __name__ == '__main__':
    try:
        sys.exit(delivery.entrypoint_main(sys.argv[1:]))
    except (ValueError, KeyError, IndexError, OSError, subprocess.CalledProcessError) as error:
        print('[delivery-command] BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(2)
