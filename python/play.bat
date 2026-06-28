echo off
ffplay -f dshow -rtbufsize 500M -vcodec rawvideo -video_size 80x120 -i video="modularCamera" -vf "scale=400:600" -sws_flags neighbor