echo off
set /a f = %1 / %2
ffmpeg -f dshow -c:v rawvideo -r %1 -rtbufsize 1000M -video_size 640x480 -i video="modularCamera" -r %2 -filter:v "setpts=%f%*PTS" %3