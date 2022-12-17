#!/bin/bash

cd /home/we/dust/audio
wget https://github.com/schollz/amenbreak/releases/download/audio2/amenbreak.tar.gz
tar -xvzf amenbreak.tar.gz
rm amenbreak.tar.gz
cd /home/we/dust/data
wget https://github.com/schollz/amenbreak/releases/download/audio2/amenbreak_data.tar.gz
tar -xvzf amenbreak_data.tar.gz
rm amenbreak_data.tar.gz
