echo off
set /a f = %1 / %2
ffmpeg -f dshow -c:v rawvideo -r %1 -rtbufsize 500M -video_size 80x120 -i video="modularCamera" -sws_flags neighbor -r %2 -filter:v "setpts=%f%*PTS,scale=400:600" -c:v libx264 -pix_fmt gray8 %3