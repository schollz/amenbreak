#!/bin/bash

cd /home/we/dust/audio
wget -q https://github.com/schollz/amenbreak/releases/download/audio2/amenbreak.tar
tar -xvf amenbreak.tar
rm amenbreak.tar
cd /home/we/dust/data
wget -q https://github.com/schollz/amenbreak/releases/download/audio2/amenbreak_data.tar.gz
tar -xvzf amenbreak_data.tar.gz
rm amenbreak_data.tar.gz
