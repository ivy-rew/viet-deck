#/bin/bash

sound=$1
ffmpeg -i "$sound" -c:a libmp3lame -b:a 64k "${sound%.*}.mp3"
