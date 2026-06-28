echo off
ffmpeg -i %1 -sws_flags neighbor -filter:v "scale=400:600" -crf 18 -c:v libx264 -pix_fmt gray8 %~d1%~p1%~n1_upscaled.mp4