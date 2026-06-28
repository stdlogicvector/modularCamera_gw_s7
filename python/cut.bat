echo off
ffmpeg -i %1 -ss %2 -t %3 -async 1 %~d1%~p1%~n1_cut%~x1