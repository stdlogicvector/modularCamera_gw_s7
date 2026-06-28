import os
import msvcrt
import argparse
import serial
import time
import atexit

def setReg(port, nr: int, val: int, silent: bool = False) -> bool:
    if not silent:
        print("Setting FPGA   Register {:>3d} = 0x{:04X}".format(nr, val))

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
    else:
        return False
        
def getReg(port, nr: int, silent: bool = False) -> int:
    if not silent:
        print("Reading FPGA   Register {:>3d} = 0x".format(nr), end="")
    cmd = "{{R{:02X}}}".format(nr)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
        
        if len(reply) > 0 and reply[1] == 'r':
            if not silent:
                print(reply[2:-2])
            val = int(reply[2:-2], 16)
            return val
        else:
            if not silent:
                print(reply)
            return 0
    else:
        return 0
            
def setSensorReg(port, nr: int, val: int, silent: bool = False) -> bool:
    if not silent:
        print("Setting Sensor Register {:>3d} = 0x{:04X}".format(nr, val))

    cmd = "{{w{:04X}{:04X}}}".format(nr, val)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        try:
            reply = port.read_until().decode()
                
            if len(reply) > 0 and reply[0] == "!":
                return True
            else:
                if not silent:
                    print("fail")
                return False
        except UnicodeDecodeError:
            return False
    else:
        return False

def getSensorReg(port, nr: int, silent: bool = False) -> int:
    if not silent:
        print("Reading Sensor Register {:>3d} = 0x".format(nr), end="")

    cmd = "{{r{:04X}}}".format(nr)

    if not port == None:
        port.write(cmd.encode())
        time.sleep(0.1)
        port.write("\r".encode())
        reply = port.read_until().decode()
    
        if len(reply) > 0 and reply[1] == 'r':
            if not silent:
                print(reply[2:-2])
            val = int(reply[2:-2], 16)
            return val
        else:
            if not silent:
                print(reply)
            return 0
    else:
        return 0
            
def modSensorReg(port, nr: int, mask: int, val: int, silent: bool = False) -> bool:
    regval = getSensorReg(port, nr, True)

    if mask != 0xFFFF:
        newval = regval & ~mask
        newval = newval | val
    else:
        newval = val

    if not silent:
        print("Modifing Sensor Register {:>3d} from 0x{:4X} to 0x{:4X}".format(nr, regval, newval))

    return setSensorReg(port, nr, newval, True)

def seqSensorReg(port, list, silent: bool = False) -> bool:
    for i in range(len(list)):
        ret = modSensorReg(port, list[i][0], list[i][1], list[i][2], silent)
        if ret == False:
            return False

    return True

def cleanup(port):
    setReg(port, 1, (0 << 4)) # Disable
    port.close()

seq_init_clk_mgmt_0 = [
    [  2, 0xFFFF, 0x0000 ], # Monochrome Sensor
    [ 32, 0xFFFF, 0x3004 ], # Configure clock management ([14:12] = Sample Point)
    [ 20, 0xFFFF, 0x0000 ], # Configure Clock Management
    [ 17, 0xFFFF, 0x2113 ], # Configure PLL
    [ 26, 0xFFFF, 0x2280 ], # Configure PLL Lock Detector
    [ 27, 0xFFFF, 0x3D2D ], # Configure PLL Lock Detector
    [  8, 0xFFFF, 0x0000 ], # Release PLL Soft Reset
    [ 16, 0xFFFF, 0x0003 ], # Enable PLL
]

seq_init_clk_mgmt_1 = [
    [  9, 0xFFFF, 0x0000 ], # Release clock generator Soft Reset
    [ 32, 0xFFFF, 0x3006 ], # Enable logic clock ([14:12] = Sample Point)
    [ 34, 0xFFFF, 0x0001 ], # Enable locig blocks
]

seq_required_regs = [        # P1/SN/SE 10-bit mode with PLL
    [ 197, 0xFFFF, 0x0205 ], # [12:8] Blank out first lines [7:0] Number of Black Lines
    [ 224, 0xFFFF, 0x3E5E ], # [3:0]=14 (), [7:4]=5 (),
    [ 207, 0xFFFF, 0x0000 ], # Number of Reference Lines
    [ 129, 0xFFFF, 0x8001 ], # General Configuraton [15]=Black Calib. on Ref. Lines, [0]= Auto Black Calib.
    [ 128, 0xFFFF, 0x4714 ], # Black Calib Config 
    [ 204, 0xFFFF, 0x01E3 ], # Gain Configuration
    [  41, 0xFFFF, 0x085A ], # [7:4]=5 (), [10:8]=0 (), [12:11]=1 (),
    [  42, 0xFFFF, 0x0011 ], # [6:4]=1 (),
    [  65, 0xFFFF, 0x288B ], # [15:12]=2 (),
    [ 211, 0xFFFF, 0x0E49 ], # [6:4]=4 (), [3:3]=1 (), [1:1]=0 (),
    [  43, 0xFFFF, 0x0008 ], # [1:1]=0 (), [2:2]=0 (), [3:3]=1 (),
    [  70, 0xFFFF, 0x1111 ], # [3:0]=1 (), [7:4]=1 (), [11:8]=1 (), [15:12]=1 (),
    [  67, 0xFFFF, 0x0554 ], # [3:0]=4 (), [7:4]=5 (), [11:8]=5 (), [15:12]=0 (),
    [  66, 0xFFFF, 0x53C6 ], # [3:0]=6 (), [7:4]=12 (),
    [  68, 0xFFFF, 0x0085 ], # [3:0]=5 (),
    [ 215, 0xFFFF, 0x0107 ], # [2:2]=1 (), [1:1]=1 (),
    [ 194, 0xFFFF, 0x0221 ], # Integraton Control
    [ 199, 0xFFFF,     72 ], # Exposure Time Granularity (72 -> 1us Resolution with 72MHz CLK)
    [ 201, 0xFFFF,   2000 ], # Exposure Time (in us)
    [ 200, 0xFFFF, 0x411A ], # Frame/Reset Length
#   [ 194, 0xFFFF, 0x0220 ], # [7:6]=0 (), [9:9]=1 (), [2:2]=0 (),
#   [ 199, 0xFFFF, 0x06A1 ], #
#   [ 201, 0xFFFF, 0x06A1 ], #
#   [ 200, 0xFFFF, 0x01F4 ], #
    [ 192, 0xFFFF, 0x0800 ]  # Sequencer General Configuration
]

seq_soft_power_up = [
    [  32, 0xFFFF, 0x3007 ], # Enable analog clock distribution   (Bit 3 = 0: 10bit mode, = 1: 8bit mode) (Unclear if that setting is sufficient to switch modes)
    [  10, 0xFFFF, 0x0000 ], # Release soft reset state
    [  64, 0xFFFF, 0x0001 ], # Enable biasing block
    [  72, 0xFFFF, 0x2227 ], # Enable charge pump
    [  42, 0xFFFF, 0x0013 ], # Enable column multiplexer
    [  40, 0xFFFF, 0x0003 ], # Enable AFE
    [  48, 0xFFFF, 0x0001 ], # Enable LVDS transmitters
    [ 112, 0xFFFF, 0x0007 ], # Enable column multiplexer
    [ 128, 0xFFFF, 0x4714 ]  # Enable AFE
]

seq_soft_power_down = [
    [ 112, 0xFFFF, 0x0000 ], # Disable LVDS transmitters
    [  48, 0xFFFF, 0x0000 ], # Disable AFE
    [  40, 0xFFFF, 0x0000 ], # Disable column multiplexer
    [  72, 0xFFFF, 0x0200 ], # Disable charge pump
    [  64, 0xFFFF, 0x0000 ], # Disable biasing block
    [  10, 0xFFFF, 0x0999 ]  # Soft Reset
]

seq_deinit_clk_mgmt_0 = [
    [ 34, 0xFFFF, 0x0000 ], # Disable logic blocks
    [ 32, 0xFFFF, 0x3004 ], # Disable logic clock
    [  9, 0xFFFF, 0x0009 ]  # Soft reset clock generator
]

seq_deinit_clk_mgmt_1 = [
    [ 16, 0xFFFF, 0x0000 ], # Disable PLL
    [  8, 0xFFFF, 0x0099 ], # Soft reset PLL
    [ 20, 0xFFFF, 0x0000 ]  # Configure clock management
]

def initialize(port, silent: bool = True) -> bool:
    print("Initializing PLL - ", end="")
    if seqSensorReg(port, seq_init_clk_mgmt_0, silent):
        print("OK!")
    else:
        print(" Failed!")
        return False

    print("Verifing PLL Lock -", end="")
    lock = 0
    for i in range(0, 10):
        time.sleep(0.01)
        lock = getSensorReg(port, 24, True)
        if lock != 0x0000:
            break
        print(".", end="")

    if lock == 0x0000:
        print(" Failed!")
        return False
    else:
        print(" OK!")
    
    print("Initializing Clock Management - ", end="")
    if seqSensorReg(port, seq_init_clk_mgmt_1, silent):
        print("OK!")
    else:
        print(" Failed!")
        return False

    print("Uploading required registers - ", end="")
    if seqSensorReg(port, seq_required_regs, silent):
        print("OK!")
    else:
        print(" Failed!")
        return False

    print("Soft Power-Up - ", end="")
    if seqSensorReg(port, seq_soft_power_up, silent):
        print("OK!")
    else:
        print(" Failed!")
        return False

    return True

def sequencer(port, enable: bool, triggered: bool = True) -> bool:
    if enable:
        print("Enabling Sequencer")
        if triggered:
            return modSensorReg(port, 192, 0x0011, 0x0011, True)
        else:
            return modSensorReg(port, 192, 0x0011, 0x0001, True)
    else:
        print("Disabling Sequencer")
        return modSensorReg(port, 192, 0x0001, 0x0000, True)
    
def monitor(port, sel: int) -> bool:
    print("Setting monitor pin mux to {:d}".format(sel))
    return modSensorReg(port, 192, (0x7 << 11), (sel & 0x7) << 11, True)

def autoExposure(port, enable: bool) -> bool:
    if enable:
        print("Enabling Auto Exposure")
        return modSensorReg(port, 160, 0x0001, 0x0001, True)
    else:
        print("Disabling Auto Exposure")
        return modSensorReg(port, 160, 0x0001, 0x0000, True)    

def deinitialize(port, silent: bool = True) -> bool:
    print("Soft Power-Down - ", end="")
    if seqSensorReg(port, seq_soft_power_down, silent):
        print("OK!")
    else:
        print(" Failed!")
        return False

    print("Disabling Clock Management - ", end="")
    if seqSensorReg(port, seq_deinit_clk_mgmt_0, silent):
        print("OK!")
    else:
        print(" Failed!")
        return False

    print("Disabling PLL - ", end="")
    if seqSensorReg(port, seq_deinit_clk_mgmt_1, silent):
        print("OK!")
    else:
        print(" Failed!")
        return False
    
    return True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--port', help='Camera Control Port', default="COM32")
    parser.add_argument('-r', '--framerate', help='Framerate', default=30)
    parser.add_argument('-e', '--exposure', help='Exposure Time in us', default=1000)
    parser.add_argument('-t', '--test', help='Testimage', default=None, action='store_true')
    parser.add_argument('-o', '--output', help='Output File', default=None)
    parser.add_argument('-n', '--number', help='Number of frames to record', default=None)
    parser.add_argument('-d', '--display', help='Show Live Image', default=False, action='store_true')
    args = parser.parse_args()

    fpga = serial.Serial(port=args.port, baudrate=921600, timeout=1.0, dsrdtr=False, exclusive=True)

    atexit.register(cleanup, port=fpga)

    w = 640
    h = 480
    
    setReg(fpga, 1, (1 << 4))               # Enable Sensor Power Supplies
   
    print("Checking Sensor ID - ", end="")
    if getSensorReg(fpga, 0x000, True) != 0x50D0:
        print("Sensor ID does not match.")
        exit()
    else:
        print("OK!")

    print("Sensor Resolution = ", end="")
    res = getSensorReg(fpga, 0x001, True)
    if res & 0x0300 == 0x0100: 
        print("640x480")
        w = 640
        h = 480
    elif res & 0x0300 == 0x0200:
        print("800x600")
        w = 800
        h = 600
    elif res & 0x0300 == 0x0000:
        print("1280x1024")
        w = 1280
        h = 1024

    initialize(fpga)

    print("Temperature")
    setSensorReg(fpga, 96, 0x0001)          # Enable Temperature Sensor
    getSensorReg(fpga, 97)                  # Temperature Reading

    monitor(fpga, 1)                        # Monitor Pins
    setReg(fpga, 28, 6)                     # Select Debug Mux

    sequencer(fpga, True, True)             # Triggered Mode
    
    interval = 2000;                        # Set Frame Interval in us
    setReg(fpga, 0x02, interval & 0xFFFF)
    setReg(fpga, 0x03, interval >> 16)

    exposure = 100                          # Trigger Pulse Length in us
    setReg(fpga, 0x04, exposure)

    print("ROI")
    roi0_x  = ((w // 8) - 1) << 8
    roi0_y0 = 0
    roi0_y1 = h - 1
    setSensorReg(fpga, 256, roi0_x)
    setSensorReg(fpga, 257, roi0_y0)
    setSensorReg(fpga, 258, roi0_y1)

    roi0_x  = getSensorReg(fpga, 256)
    roi0_y0 = getSensorReg(fpga, 257)
    roi0_y1 = getSensorReg(fpga, 258)
    
    roi0_x0 = roi0_x & 0xFF
    roi0_x1 = roi0_x >> 8
    print("[{:d}, {:d}]-[{:d}, {:d}]".format(roi0_x0, roi0_y0, roi0_x1, roi0_y1))

    print("Resolution")
    getSensorReg(fpga, 240)                 # X Resolution
    getSensorReg(fpga, 241)                 # Y Resolution

    print("Timing")
    #modSensorReg(fpga, 192, 1 << 6, 1 << 6)     # Enable Delay between Lines (only necessary with debug firmware on FX3)
    #modSensorReg(fpga, 193, 0xFF00, 30 << 8)    # Set Length of delay between Lines
    setSensorReg(fpga, 201, 1500)                # Exposure Time

    if args.test is not None:
        setSensorReg(fpga, 144, (1 << 3) | (1 << 2) | (1 << 0))    # Enable framed testpattern
        #setSensorReg(fpga, 146, (16 << 8) | (8 << 0))
        #setSensorReg(fpga, 147, (64 << 8) | (32 << 0))
        setSensorReg(fpga, 150, (3 << 6) | (2 << 4) | (1 << 2) | (0 << 0))

    print("Press any key to start training")
    msvcrt.getch()
    setReg(fpga, 1, (1 << 4) | (1 << 5))    # Training on
    setReg(fpga, 1, (1 << 4) | (0 << 5))    # Training off

    print("Press any key to start trigger generator")
    msvcrt.getch()
    setReg(fpga, 1, (1 << 4) | (1 << 0))    # Enable Trigger Generator

    if args.display:
        print("Displaying Video")
        os.system('ffplay -f dshow -vcodec rawvideo -video_size {:d}x{:d} -i video="modularCamera"'.format(w, h))
        #os.system('ffplay -hide_banner -loglevel error -f dshow -vcodec rawvideo -video_size {:d}x{:d} -i video="modularCamera"'.format(w, h))
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

#        print("Press +/- to change trigger length, ESC to stop trigger generator")
#        while True: 
#            time.sleep(0.1)
#            if msvcrt.kbhit():
#                key = msvcrt.getch()
#                if key == b'\x1b':
#                    break
#                elif key == b'+':
#                    exposure = exposure + 10
#                    setReg(fpga, 0x04, exposure)
#                elif key == b'-':
#                    if exposure > 10:
#                        exposure = exposure - 10
#                        setReg(fpga, 0x04, exposure)
        #msvcrt.getch()

    setReg(fpga, 1, (1 << 4) | (0 << 0))    # Disable Trigger Generator

    print("Temperature")
    getSensorReg(fpga, 97)                  # Temperature Reading

    print("Press any key to disable sensor")
    msvcrt.getch()
    sequencer(fpga, False)
    deinitialize(fpga)

if __name__ == '__main__':
    main()

# 3A6 = 1110100110
# 0A6 = 0010100110  0AA = 0010101010
# 00A = 0000001010  
# 020 = 0000100000

# 135 = 0100110101
# 00A = 0000001010
# 040 = 0001000000
# 3B9 = 1110111001
# 3A6 = 1110100110
