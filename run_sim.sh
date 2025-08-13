#!/bin/bash
export SIM_MODE=true
export LIVE_MODE=false
python fieldvision_daemon.py
echo "Logs written to ./logs"
