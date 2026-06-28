echo off
REM ffmpeg -f dshow -c:v rawvideo -rtbufsize 500M -video_size 5000x120 -i video="modularCamera" -c:v libx264 -pix_fmt gray8 %1
ffmpeg -f dshow -c:v rawvideo -rtbufsize 500M -video_size 5000x120 -i video="modularCamera" -pix_fmt gray8 %1