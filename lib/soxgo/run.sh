#!/bin/bash
ps -ef | grep 'soxgo' | grep -v grep | grep -v run | awk '{print $2}' | xargs -r kill -9
cd "$(dirname "$0")"
nohup ./soxgo -input "${1}" --output "${2}" --stretch "${3}" >/dev/null 2>&1 &
