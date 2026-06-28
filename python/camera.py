#!/usr/bin/python3

import os
import msvcrt
import argparse
import serial
import time
import atexit
from datetime import datetime

def setReg(port, nr, val, silent = False):
    if not silent:
        print("Setting FPGA   Register {:>4d} = 0x{:04X}".format(nr, val))

    cmd = "{{W{:02X}{:04X}}}".format(nr, val)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if len(reply) > 0 and reply[0] == "!":
            return True
        else:
            if not silent:
                print("fail")
            return False
        
def getReg(port, nr, silent = False):
    if not silent:
        print("Reading FPGA   Register {:>4d} = 0x".format(nr), end="")
    cmd = "{{R{:02X}}}".format(nr)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if not silent:
            if reply[1] == 'R':
                print(reply[2:-2])
                val = int(reply[2:-2], 16)
                return val
            else:
                print(reply)
                return False

def setLut(port, nr, addr, silent = False):
    if not silent:
        print("Setting LUT")
    cmd = "{{P{:02X}{:04X}}}".format(2**nr, addr)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        for i in range(0, 4096):
            cmd = "{{L{:08X}}}".format(i // 16)
            port.write(cmd.encode())
            #time.sleep(0.1)
            port.write("\r".encode())
            reply = port.read_until().decode()
            
            if not silent:
                if i % 64 == 0:
                    print(".")
        
        return True

def setSensorReg_16_16(port, nr, val, silent = False):
    if not silent:
        print("Setting Sensor Register {:>4d} = 0x{:04X}".format(nr, val))

    cmd = "{{w{:04X}{:04X}}}".format(nr, val)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if reply[0] == "!":
            return True
        else:
            if not silent:
                print("fail")
            return False

def setSensorReg_8_16(port, nr, val, silent = False):
    if not silent:
        print("Setting Sensor Register {:>4d} = 0x{:04X}".format(nr, val))

    cmd = "{{w{:02X}{:04X}}}".format(nr, val)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if reply[0] == "!":
            return True
        else:
            if not silent:
                print("fail")
            return False

def setSensorReg_8_8(port, nr, val, silent = False):
    if not silent:
        print("Setting Sensor Register {:>4d} = 0x{:02X}".format(nr, val))

    cmd = "{{w{:02X}{:02X}}}".format(nr, val)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if reply[0] == "!":
            return True
        else:
            if not silent:
                print("fail")
            return False

def getSensorReg_16(port, nr, silent = False):
    if not silent:
        print("Reading Sensor Register {:>4d} = 0x".format(nr), end="")

    cmd = "{{r{:04X}}}".format(nr)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if not silent:
            if reply[1] == 'r':
                print(reply[2:-2])
                val = int(reply[2:-2], 16)
                return val
            else:
                print(reply)
                return False

def getSensorReg_8(port, nr, silent = False):
    if not silent:
        print("Reading Sensor Register {:>4d} = 0x".format(nr), end="")

    cmd = "{{r{:02X}}}".format(nr)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if not silent:
            if reply[1] == 'r':
                print(reply[2:-2])
                val = int(reply[2:-2], 16)
                return val
            else:
                print(reply)
                return False       


# v4l2-ctl -d /dev/video2 -D --list-formats-ext
# ffplay -hide_banner -loglevel error -f dshow -pix_fmt gray -video_size 80x120 -i video="modularCamera"
# ffplay -hide_banner -loglevel error -f dshow -video_size 774x774 -i video="Framegrabber"
# 
# 
# ffmpeg -vcodec rawvideo -video_size 80x120 -i video="modularCamera" -framerate 100 -vframes:v 1 -f image2 -y D:\tmp\test100fps.raw
# ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size 80x120 -i video="modularCamera" -framerate 100  -vf "scale=400:600" -sws_flags neighbor

# ffmpeg -f dshow -c:v rawvideo -r 500 -rtbufsize 100M -video_size 80x120 -i video="modularCamera" -sws_flags neighbor -r 25 -filter:v "setpts=20.0*PTS,scale=400:600" D:\tmp\test7_500.avi

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--port', help='Camera Control Port', default="COM32")
    parser.add_argument('-m', '--mode', help='Camera Mode', default="adv7182")
    parser.add_argument('-r', '--framerate', help='Framerate', default=30)
    parser.add_argument('-e', '--exposure', help='Exposure Time in us', default=1000)
    parser.add_argument('-t', '--test', help='Testimage', default=None)
    parser.add_argument('-o', '--output', help='Output File', default=None)
    parser.add_argument('-n', '--number', help='Number of frames to record', default=None)
    parser.add_argument('-d', '--display', help='Show Live Image', default=False, action='store_true')
    parser.add_argument('-c', '--capture', help='Record Video', default=None)
    args = parser.parse_args()

    fpga = serial.Serial(port=args.port, baudrate=921600, timeout=1.0, dsrdtr=False, exclusive=True)

    atexit.register(setReg, port=fpga, nr=0x01, val=0x0002)

    if args.mode == "cameralink":
        w = 774
        h = 774

        setReg(fpga, 12, h)
        setReg(fpga, 13, w)
        setReg(fpga, 6, h)
        setReg(fpga, 7, w)
        setReg(fpga, 3, 60)

        setReg(fpga, 0x01, 0x0006)

        if args.display:
            os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size {:d}x{:d} -i video="modularCamera"'.format(h, w))
        else:
            msvcrt.getch()

        setReg(fpga, 0x01, 0x0000)

    elif args.mode == "capsense":
        
        setReg(fpga, 11, 450)
        setReg(fpga, 1, 0x8000)
        
        while True:
            time.sleep(0.05)
            val = getReg(fpga, 0x80 | 0, True)
            
            print("\033[1A\033[2K{:d} ".format(val), end="")
            
            for i in range(0, val//2):
                print("#", end="")

            print("")

            if msvcrt.kbhit():
                break

        setReg(fpga, 1, 0x0000)

    elif args.mode.startswith("python"):
        w = 640
        h = 480
        
        interval = 33000;                       # Set Frame Interval in us
        setReg(fpga, 0x02, interval & 0xFFFF)
        setReg(fpga, 0x03, interval >> 16)

        setReg(fpga, 0x07, 3)

        exposure = 1000 #3780
        setReg(fpga, 0x04, exposure)
        
        setReg(fpga, 28, 6)

        setReg(fpga, 0x01, 0x0003 + (int(args.test) << 8))

        if args.display:
            print("Displaying Video")
            os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size 640x480 -i video="modularCamera" -vf "scale={:d}:{:d}"'.format(w // 1, h // 1))
        else:
            print("Select DBG 0-7")
            while True: 
                time.sleep(0.1)
                if msvcrt.kbhit():
                    key = msvcrt.getch()
                    if key == b'\x1b':
                        break
                    else:
                        setReg(fpga, 28, int(key)) # Debug Mux

        setReg(fpga, 1, (0 << 4)) # Disable

    elif args.mode.startswith("ev76c560"):
        w = 1280
        h = 1024

        setReg(fpga, 1, (1 << 4)) # Enable and Init
        time.sleep(0.5)

        #setSensorReg_8_16(fpga, 0x09, 0x6852)
        #setSensorReg_8_16(fpga, 0x44, 0x0000)   # Always Enable DataClk
        #setSensorReg_8_16(fpga, 0x0B, 0x0145)   # Enable Trigger Pin and Strobe during Integration
        #setSensorReg_8_16(fpga, 0x0B, 0x0144)   # Disable Standby

        #getSensorReg_8(fpga, 0x08)
        #getSensorReg_8(fpga, 0x09)

        #setSensorReg_8_16(fpga, 0x08, 0b1101_1011_0010_0001)
        #setSensorReg_8_16(fpga, 0x09, 0b011_01000_01000111)
 
        #getSensorReg_8(fpga, 0x08)
        #getSensorReg_8(fpga, 0x09)
        #getSensorReg_8(fpga, 0x0A)
        #getSensorReg_8(fpga, 0x0B)
        #getSensorReg_8(fpga, 0x44)

        #for i in range(0x00, 0x80):
            #getSensorReg_8(fpga, i)

        getSensorReg_8(fpga, 0x0A)

        getSensorReg_8(fpga, 0x3E)  # Status

        setReg(fpga, 5, w)
        setReg(fpga, 6, h)
        
        framerate = int(args.framerate)
        interval = 1000000 // framerate

        if interval < 17000:
            interval = 170000

        setReg(fpga, 0x02, interval & 0xFFFF)
        setReg(fpga, 0x03, interval >> 16)
        setReg(fpga, 0x04, 1)

        exposure_ms = int(args.exposure)
        setSensorReg_8_16(fpga, 0x0E, int(exposure_ms * 64))
        #getSensorReg_8(fpga, 0x0E)
       
        #setSensorReg_8_16(fpga, 0x0A, 0x0200)
        #getSensorReg_8(fpga, 0x0A)

        #setReg(fpga, 28, 7) # Debug Mux
        
        #msvcrt.getch()
        setReg(fpga, 0x01, (1 << 4) | (1 << 0))  # Enable Sensor and TriggerGen

#        while True: 
#            time.sleep(0.1)
#            if msvcrt.kbhit():
#                key = msvcrt.getch()
#                if key == b'\x1b':
#                    break
#                else:
#                    setReg(fpga, 28, int(key)) # Debug Mux

        if args.display:
            print("Displaying Video")
            os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size 1280x1024 -i video="modularCamera" -vf "scale={:d}:{:d}"'.format(w // 1, h // 1))
        elif args.capture is not None:
            print("Capturing Video")
            #os.system('ffmpeg -f dshow -c:v rawvideo -r {:d} -rtbufsize 1000M -video_size 1280x1024 -i video="modularCamera" -r {:d} -filter:v "setpts={:f}*PTS" {:s}'.format(framerate, 25, framerate / 25.0, args.capture))
            os.system('ffmpeg -f dshow -c:v rawvideo -r {:d} -rtbufsize 1000M -video_size 1280x1024 -i video="modularCamera" -c:v libx264 -preset ultrafast -tune zerolatency -crf 26 {:s}'.format(framerate, args.capture))
        else:
            print("Press any key to stop")
            msvcrt.getch()

        setReg(fpga, 1, (0 << 4)) # Disable

    elif args.mode.startswith("mt9p"):
        w = 2592
        h = 1944

        setReg(fpga, 28, 7) # Debug Mux
        
        interval = 300000
        if args.mode == "mt9p_usb3":
            interval = 80000
        
        setReg(fpga, 0x02, interval & 0xFFFF)
        setReg(fpga, 0x03, interval >> 16)

        setReg(fpga, 0x0A, 50000)
        #setReg(fpga, 0x09, (10 << 8) | (250))

        setSensorReg_8_16(fpga, 0x0D, 0x0001)    # Reset Sensor
        setSensorReg_8_16(fpga, 0x0D, 0x0000)    

        setSensorReg_8_16(fpga, 0x09, 1200)      # Exposure Time

        setSensorReg_8_16(fpga, 0x0A, 0x8000)    #Invert PixelClk
        setSensorReg_8_16(fpga, 0x1E, 0x4006 | (1 << 9) | (1 << 8) | (1 << 4)) # Enable Triggered Mode, Triggerlevel = high and Strobe
        
        # 40MHz for USB2, 95MHz for USB3
        if args.mode == "mt9p_usb3":
            setSensorReg_8_16(fpga, 0x10, 0x0051)    # Power on PLL  : 40MHz * 19 / (4*2) = 95MHz 
            setSensorReg_8_16(fpga, 0x11, 0x1303)    # PLL Config 1 M=19, N=4
            setSensorReg_8_16(fpga, 0x12, 0x0001)    # PLL Config 2 p1=2

            time.sleep(0.01)

            setSensorReg_8_16(fpga, 0x10, 0x0053)    # Use PLL
                
        setReg(fpga, 5, w)
        setReg(fpga, 6, h)
        
        #setReg(fpga, 0x01, 0x0010)  # Enable Sensor
        setReg(fpga, 0x01, 0x0011)  # Enable Sensor and TriggerGen
              
        if args.display:
            os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size 2592x1944 -i video="modularCamera" -vf "scale={:d}:{:d}"'.format(w // 2, h // 2))
        else:
            msvcrt.getch()
    
        setReg(fpga, 0x01, 0x0000)

    elif args.mode == "orion2k":
        w = 2048
        h = 2048

        setReg(fpga, 28, 0) # Debug Mux
        getReg(fpga, 28 + 0x80)

        setReg(fpga, 28, 1) # Debug Mux

        if args.test is not None:
            interval = 40

            setReg(fpga, 0x02, interval & 0xFFFF)
            setReg(fpga, 0x03, interval >> 16)
            setReg(fpga, 0x04, 10)
            setReg(fpga, 0x07, 175)
            setReg(fpga, 0x05, 2048 // 2) 
            setReg(fpga, 0x06, 2048)

            getReg(fpga, 0x02)
            getReg(fpga, 0x03)
            setReg(fpga, 0x01, 0x0003 + (int(args.test) << 8))

            if args.display:
                print("Displaying Video")
                os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size {:d}x{:d} -i video="modularCamera" -vf "scale={:d}:{:d}"'.format(h, w, h // 2, w // 2))
            else:
                msvcrt.getch()

            setReg(fpga, 0x01, 0x0000)
        else:
            interval = 125

            setReg(fpga, 0x02, interval & 0xFFFF)
            setReg(fpga, 0x03, interval >> 16)
            setReg(fpga, 0x06, 2048)

            setReg(fpga, 0x0A, 5000)    # Integration Time

            #getSensorReg_8(fpga, 0x01)          # Status 1
            #time.sleep(1)
            #getSensorReg_8(fpga, 0x02)          # Status 2
            #time.sleep(1)
            #getSensorReg_8(fpga, 0x03)          # Status 3
            #time.sleep(1)

            setSensorReg_8_8(fpga, 0x10, 0x0C)  # Select Segments 3 & 4
            setSensorReg_8_8(fpga, 0x01, 0x09)  # Write Register Values
            setSensorReg_8_8(fpga, 0x06, 0x3F)  # Set EndOfRange to 11bits
            setSensorReg_8_8(fpga, 0x0B, 0xA7)  # Set Trainingpattern 1
            setSensorReg_8_8(fpga, 0x0C, 0xA7)  # Set Trainingpattern 2
            setSensorReg_8_8(fpga, 0x05, 0x80)  # Set BlackLevelOffset to 0x80
            setSensorReg_8_8(fpga, 0x04, 0x40)  # Set Analog Gain Factor to 0x40
            setSensorReg_8_8(fpga, 0x08, 0b00_010_001)  # LVDS Drive Strength
            #setSensorReg_8_8(fpga, 0x03, 0xDA)
            setSensorReg_8_8(fpga, 0x01, 0x09)  # Write Register Values

            setReg(fpga, 0x0D, 0xA7A7)

            setReg(fpga, 0x01, 0x0081)    # Enable Bitslip
            time.sleep(0.1)
            setReg(fpga, 0x01, 0x0001)    # Don't enable Bitslip
            
            if args.display:
                print("Displaying Video")
                os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size {:d}x{:d} -i video="modularCamera" -vf "scale={:d}:{:d}"'.format(h, w, h * 2 // 3, w * 2 // 3))
            else:
                print("Select DBG 0-7")
                while True: 
                    time.sleep(0.1)
                    if msvcrt.kbhit():
                        key = msvcrt.getch()
                        if key == b'\x1b':
                            break
                        else:
                            setReg(fpga, 28, int(key)) # Debug Mux
                #msvcrt.getch()

            setReg(fpga, 0x01, 0x0000)

    elif args.mode == "hallarray":
        setReg(fpga, 0x04, 25) # Settlingtime in us

        #setLut(fpga, 0, 0)

        if args.test is not None:
            setReg(fpga, 0x02, 60000)
            setReg(fpga, 0x01, 0x0003 + (int(args.test) << 8))  # Enable Testimage
        else:
            setReg(fpga, 0x02, 33000)
            setReg(fpga, 0x01, 0x0011)  # Enable Sensor and TriggerGen
                
        if args.display:
            os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size 64x64 -i video="modularCamera" -sws_flags neighbor -vf "scale=320:320"')
        else:
            msvcrt.getch()
    
        setReg(fpga, 0x01, 0x0000)

    elif args.mode == "linearccd":
        w = 5000
        h = 120

        setReg(fpga, 0x04, 10)          # Exposuretime in us
        
        if args.test is not None:
            setReg(fpga, 0x02, 60000)
            setReg(fpga, 0x01, 0x0003)  # Enable Testimage
        else:
            setReg(fpga, 0x02, 1850)
            setReg(fpga, 0x01, 0x0001)  # Enable TriggerGen
            
        if args.display:
            os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size 5000x120 -i video="modularCamera"')
        else:
            msvcrt.getch()
    
        setReg(fpga, 0x01, 0x0000)

    elif args.mode == "aisc110":
        w = 80
        h = 120

        ts = int(time.time()) >> 16

        setReg(fpga, 0x1f, ts, True)

        # Reset FIFO and Metadata
        setReg(fpga, 0x00, 0x8000, True)

        framerate = int(args.framerate)
        exposure = int(args.exposure)
        period = 1000000 // framerate

        # Set Triggerperiod
        setReg(fpga, 2, period & 0xFFFF, True)
        setReg(fpga, 3, period >> 16, True)
        
        if exposure >= period:
            exposure = period - 1
    
        # Set Exposureduration
        setReg(fpga, 4, exposure)
        getReg(fpga, 4)

        setReg(fpga, 16, 0xFFFF, True)
        setReg(fpga, 17, 0xFFFF, True)

        # Set Test-Imagesize
        setReg(fpga, 5, w//4)
        setReg(fpga, 6, h)

        getReg(fpga, 5)
        getReg(fpga, 6)

        # FIFO-USB Timing
        setReg(fpga, 7, 0, True)
        setReg(fpga, 9, 0x0101, True)

        if args.test is not None:
            setReg(fpga, 0x01, 0x0002) # Enable internale source
        else:
            setReg(fpga, 0x01, 0x0010, True) # Enable Sensor
  
            # Read Sensor ID & Status
            #getSensorReg_16(fpga, 0x00)
            #getSensorReg_16(fpga, 0x02)
            #getSensorReg_16(fpga, 0x06)

            # Configure Sensor GPIO (GPIO0 = Exposure In, GPIO1 = Unused, GPIO2 = FrameSync Out, GPIO3 = Unused)
            setSensorReg_16_16(fpga, 0x08, 0x0502)
            getSensorReg_16(fpga, 0x08)
        
            # Configure Sensor Imager (Always On = 1, Threshold = 0xF, Ext.Trigger = 1, ExposureMode = 0 (Single Exposure), Imager On = 1)
            #setSensorReg(fpga, 0x12, 0x807D)
            setSensorReg_16_16(fpga, 0x12, 0x8001)   # Trigger used as exposure signal
            getSensorReg_16(fpga, 0x12)
            #setSensorReg_8_16(fpga, 0x30, 0x0071)   
            setSensorReg_16_16(fpga, 0x30, 0x0003)   # Analog Array always on (important for external exposure)
            getSensorReg_16(fpga, 0x30)

            # Configure Sensor Exposure Time
            #setSensorReg_16_16(fpga, 0x14, 0x01FA) # 20us
            #setSensorReg_16_16(fpga, 0x14, 0xFFFF)  # 163us
            #getSensorReg_16_16(fpga, 0x14)

        if args.test is not None:
            setReg(fpga, 0x01, 0x0003)  # Enable Testimage and TriggerGen
            setReg(fpga, 0x01, 0x0003 + (int(args.test) << 8))
        else:
            setReg(fpga, 0x01, 0x0011)  # Enable Sensor and TriggerGen
              
        if args.display:
            print("Displaying Video")
            os.system('ffplay -f dshow -rtbufsize 500M -vcodec rawvideo -video_size 80x120 -i video="modularCamera" -vf "scale=400:600" -sws_flags neighbor')
        elif args.capture is not None:
            print("Capturing Video")
            os.system('ffmpeg -f dshow -c:v rawvideo -r {:d} -rtbufsize 1000M -video_size 80x120 -i video="modularCamera" -r {:d} -filter:v "setpts={:f}*PTS" {:s}'.format(framerate, 25, framerate / 25.0, args.capture))
        else:
            msvcrt.getch()

        if args.test is not None:    
            setReg(fpga, 0x01, 0x0002)
        else:
            setReg(fpga, 0x01, 0x0000) # Disable Sensor & TriggerGen

    elif args.mode == "adv7182":
        w = 720
        h = 576

        #setReg(fpga, 28, 0x0000)

        setReg(fpga, 0x01, 0x0000) 
        getReg(fpga, 0x05)

        setSensorReg_8_8(fpga, 0x0F, 0x80)

        time.sleep(0.1)

        setSensorReg_8_8(fpga, 0x0F, 0x00)  # Remove PowerDown
        setSensorReg_8_8(fpga, 0x1D, 0x40)  # Enable LLC Driver

        getSensorReg_8(fpga, 0x11)
        getSensorReg_8(fpga, 0x10)
        getSensorReg_8(fpga, 0x12)
        getSensorReg_8(fpga, 0x13)

        setSensorReg_8_8(fpga, 0x00, 0x00)  # Select CVBS on AIN1
        
    #    setSensorReg_8_8(fpga, 0x34, 0x00)
    #    setSensorReg_8_8(fpga, 0x35, 0x00)
    #    setSensorReg_8_8(fpga, 0x36, 0x00)

        setSensorReg_8_8(fpga, 0x32, 0x41)
        setSensorReg_8_8(fpga, 0x6A, 0x03)  # Select HSync
        setSensorReg_8_8(fpga, 0x6B, 0x11)  # Select VSync 0x11, DV = 0x13
        setSensorReg_8_8(fpga, 0x14, 0x15)  # Select Pattern
    #    setSensorReg_8_8(fpga, 0x0C, 0x37)  # Force freerun
    
        setSensorReg_8_8(fpga, 0x03, 0x0C)  # Enable Output Drivers

        setReg(fpga, 28, 5)

        if args.display:
            os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size {:d}x{:d} -i video="modularCamera"'.format(h, w))
        else:
            msvcrt.getch()

    #    getSensorReg_8(fpga, 0x00)
    #    setSensorReg_8_8(fpga, 0x00, 0x01)
    #    getSensorReg_8(fpga, 0x00)

    #    getSensorReg_8(fpga, 0x01)
    #    getSensorReg_8(fpga, 0x02)

    atexit.unregister(setReg)
    fpga.close()

if __name__ == '__main__':
    main()
