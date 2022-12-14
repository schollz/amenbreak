#!/bin/bash
ps -ef | grep 'oscnotify' | grep -v grep | grep -v run | awk '{print $2}' | xargs -r kill -9
cd "$(dirname "$0")"
nohup ./oscnotify -ignore /home/we/dust/code/amenbreak/data -path /home/we/dust/code/amenbreak/ >/dev/null 2>&1 &
