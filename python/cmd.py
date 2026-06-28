import socket
import msvcrt

UDP_IP = "192.168.178.100"
UDP_PORT = 0x1000

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP

def cmd(c):
    sock.sendto(b'{' + c.encode(encoding="utf-8") + b'}', (UDP_IP, UDP_PORT))
    data, addr = sock.recvfrom(1024)        # buffer size is 1024 bytes
    print("rx: %s" % data)

def read_reg(i):
    print("Reading Register {:d}".format(i))
    cmd("R{:02X}".format(i))

def write_reg(i, v):
    cmd("W{:02X}{:04X}".format(i, v))

read_reg(5)

sock.close