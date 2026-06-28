#!/usr/bin/python3

from __future__ import annotations
from typing import List, Dict
import math
import struct

def LerpColor(initialColor: List[float], targetColor: List[float], lerping_factor: float) -> List[float]:
    return [initialColor[i] + (targetColor[i] - initialColor[i]) * lerping_factor for i in range(len(initialColor))]

def LerpColorMultipleSteps(initialColor: List[float], targetColor: List[float], number_steps: int) -> List[List[float]]:
    return [LerpColor(initialColor, targetColor, i/number_steps) for i in range(number_steps + 1)]


def YUVtoRGB(Y: int, U: int, V: int) -> List[float]:
    R = Y + 1.14 * V
    G = Y - 0.395 * U - 0.581 * V
    B = Y + 2.033 * U
    return [R, G, B]


def RGBtoYUV(R: float, G: float, B: float) -> List[float]:
    Y = R * .299000 + G * .587000 + B * .114000
    U = 0.492 * (B - Y)
    V = 0.877 * (R - Y)
    return [Y, U, V]
import argparse


def GenerateGradient(startColor: List[float], targetColor: List[float], steps: int = 1) -> List[float]:
    return LerpColorMultipleSteps(startColor, targetColor, steps)


def GenerateLUT(file, gradient: List[float]):
    i = 0
    for c in gradient:
        y = math.floor(c[0] * 255)
        u = math.floor(c[1] * 255 + 128)
        v = math.floor(c[2] * 255 + 128)

        val = struct.pack("BBB", y, u, v)

        file.write("16#{:s}#,".format(val.hex()))

        i = i + 1
        if i % 16 == 0:
            print(c,y,u,v,val.hex())
            file.write("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-c1", help="string, YUV start color, values seperated by underscores (e.g. 0.4_-0.1_0.2", type=str)
    parser.add_argument("-c2", help="string, YUV target color, values seperated by underscores (e.g. 0.4_-0.1_0.2", type=str)
    #parser.add_argument("-c1", help="string, RGB start color, values seperated by underscores (e.g. 255_60_0", type=str)
    #parser.add_argument("-c2", help="string, RGB target color, values seperated by underscores (e.g. 30_200_150", type=str)
    parser.add_argument("-o", help="string, output filepath")
    parser.add_argument("-steps", help="int, Steps of gradient", type=int, default=1024)

    args = parser.parse_args()
    startColor = [float(val) for val in args.c1.split("_")]
    targetColor = [float(val) for val in args.c2.split("_")]

    print(startColor)
    print(targetColor)

    #startColorYUV = RGBtoYUV(startColor[0], startColor[1], startColor[2])
    #targetColorYUV = RGBtoYUV(targetColor[0], targetColor[1], targetColor[2])

    #print(startColorYUV)
    #print(targetColorYUV)

    gradient = GenerateGradient(startColor, targetColor, args.steps-1)

    f = open(args.o, "w", encoding="utf-8")

    GenerateLUT(f, gradient)

    f.close()
    