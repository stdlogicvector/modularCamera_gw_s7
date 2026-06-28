#!/usr/bin/python3

import msvcrt
import argparse
import serial
import time
from datetime import datetime

def setReg(port, nr, val):
    print("Setting FPGA Register {:d} to 0x{:04X}".format(nr, val))
    cmd = "{{W{:02X}{:04X}}}".format(nr, val)

    if not port == None:
        port.write(cmd.encode())
        reply = port.read_until().decode()
        
        if len(reply) > 0 and reply[0] == "!":
            return True
        else:
            print("fail")
            return False
        
def getReg(port, nr):
    print("Reading FPGA Register {:d}".format(nr))
    cmd = "{{R{:02X}}}".format(nr)

    if not port == None:
        port.write(cmd.encode())
        reply = port.read_until().decode()
        
        print(reply)
        
        return True
        
def setSensorReg(port, nr, val):
    print("Setting Sensor Register {:d} to 0x{:02X}".format(nr, val))
    cmd = "{{w{:02X}{:02X}}}".format(nr, val)

    if not port == None:
        port.write(cmd.encode())
        reply = port.read_until().decode()
        
        if reply[0] == "!":
            return True
        else:
            print("fail")
            return False
        
def getSensorReg(port, nr):
    print("Reading Sensor Register {:d}".format(nr))
    cmd = "{{r{:02X}}}".format(nr)

    if not port == None:
        port.write(cmd.encode())
        reply = port.read_until().decode()
        
        print(reply)
        
        return True


# v4l2-ctl -d /dev/video2 -D --list-formats-ext
# ffplay -f dshow -pix_fmt gray -video_size 80x120 -i video="modularCamera"
# ffplay -f dshow -video_size 774x774 -i video="Framegrabber"
# ffplay -f dshow -vcodec rawvideo -video_size 80x120 -i video="modularCamera" -vf "scale=400:600,transpose=1" -sws_flags neighbor
# ffmpeg -f dshow -vcodec rawvideo -video_size 80x120 -i video="modularCamera" -f nut E:\tmp\test_1000fps.nut

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--camera', help='Camera Control Port', default="COM34")
    parser.add_argument('-o', '--output', help='Output File', default=None)
    parser.add_argument('-n', '--number', help='Number of frames to record', default=None)
    parser.add_argument('-d', '--display', help='Show Live Image', default=True, action='store_true')
    args = parser.parse_args()

    fpga = serial.Serial(port=args.camera, baudrate=921600, timeout=1.0, dsrdtr=False, exclusive=True)

    h = 576
    w = 720

    #setReg(fpga, 28, 0x0000)

    setReg(fpga, 0x01, 0x00) 
    getReg(fpga, 0x05)

    setSensorReg(fpga, 0x0F, 0x80)

    time.sleep(0.1)

    setSensorReg(fpga, 0x0F, 0x00)  # Remove PowerDown
    setSensorReg(fpga, 0x1D, 0x40)  # Enable LLC Driver

    getSensorReg(fpga, 0x11)
    getSensorReg(fpga, 0x10)
    getSensorReg(fpga, 0x12)
    getSensorReg(fpga, 0x13)

    setSensorReg(fpga, 0x00, 0x00)  # Select CVBS on AIN1
    
#    setSensorReg(fpga, 0x34, 0x00)
#    setSensorReg(fpga, 0x35, 0x00)
#    setSensorReg(fpga, 0x36, 0x00)

    setSensorReg(fpga, 0x32, 0x41)
    setSensorReg(fpga, 0x6A, 0x03)  # Select HSync
    setSensorReg(fpga, 0x6B, 0x11)  # Select VSync 0x11, DV = 0x13
    setSensorReg(fpga, 0x14, 0x15)  # Select Pattern
#    setSensorReg(fpga, 0x0C, 0x37)  # Force freerun
  
    setSensorReg(fpga, 0x03, 0x0C)  # Enable Output Drivers

    setReg(fpga, 28, 0x0005)

#    msvcrt.getch()

#    getSensorReg(fpga, 0x00)
#    setSensorReg(fpga, 0x00, 0x01)
#    getSensorReg(fpga, 0x00)

#    getSensorReg(fpga, 0x01)
#    getSensorReg(fpga, 0x02)

    fpga.close()

if __name__ == '__main__':
    main()
