#!/bin/bash

cd /home/we/dust/audio
wget https://github.com/schollz/amenbreak/releases/download/assets/amenbreak.tar.gz
tar -xvzf amenbreak.tar.gz
rm amenbreak.tar.gz
cd /home/we/dust/data
wget https://github.com/schollz/amenbreak/releases/download/data/amenbreak.tar.gz
tar -xvzf amenbreak.tar.gz
rm amenbreak.tar.gz
