echo off
set /a f = %1 / %2
ffmpeg -f dshow -c:v rawvideo -r %1 -rtbufsize 500M -video_size 64x64 -i video="modularCamera" -r %2 -sws_flags neighbor -vf "setpts=%f%*PTS,scale=320:320" -c:v libx264 %3