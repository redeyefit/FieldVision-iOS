#!/bin/bash
export SIM_MODE=false
export LIVE_MODE=true
python fieldvision_daemon.py
echo "Logs written to ./logs"
