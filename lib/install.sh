#!/bin/bash

cd /home/we/dust/audio
echo "downloading amens"
wget -q https://github.com/schollz/amenbreak/releases/download/audio2/amenbreak.tar
echo "unzipping amens"
tar -xvf amenbreak.tar
rm amenbreak.tar
cd /home/we/dust/data
echo "downloading image data"
wget -q https://github.com/schollz/amenbreak/releases/download/audio2/amenbreak_data.tar.gz
echo "unzipping image data"
tar -xvzf amenbreak_data.tar.gz
rm amenbreak_data.tar.gz
