#!/bin/bash
# Double-click to open the powerscaling dashboard (tools/powerscale): starts its little
# server if it isn't running yet, then opens http://localhost:3001 in your browser.
cd "$(dirname "$0")"
if ! curl -s --max-time 1 http://localhost:3001/ping | grep -q powerscale; then
  nohup python3 tools/powerscale/serve.py 3001 > /tmp/powerscale.log 2>&1 &
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.3
    curl -s --max-time 1 http://localhost:3001/ping | grep -q powerscale && break
  done
fi
open http://localhost:3001
