from crc import CrcCalculator, Crc8

def parity(in_str): # calculate even parity bit
    c = 0
    for i in in_str:
        if(i=="1"):
            c=c+1
        else:
            pass

    if(c%2!=0): #odd no of 1s
        return "1"
    else: #even no of 1s
        return "0"

START_SEQ = "10101010"
SRC_ADDR_L = 0x67
SRC_ADDR_H = 0x45
DST_ADDR_L = 0x23
DST_ADDR_H = 0x01
PCKT_CNT = 0x0000001
PCKT_TYPE = 0x69
DATA = 0x0123456789ABCDEF
STOP_SEQ = "01010101"

# compute CRC8 | Poly - 100000111
crc_calculator = CrcCalculator(Crc8.CCITT)

# bitstring to calculate checksum for
input = format(SRC_ADDR_L, "08b") + format(SRC_ADDR_H, "08b") + format(DST_ADDR_L, "08b") + format(DST_ADDR_H, "08b") +format(PCKT_CNT, "032b") + format(PCKT_TYPE, "08b") + format(DATA, "064b")

int_arr = [int(input[i:i+8],2) for i in range(0, len(input), 8)] # divide into bytes

byte_arr = bytes(int_arr) # convert to bytearray

checksum = crc_calculator.calculate_checksum(byte_arr) # calculate checksum

CRC8 = format(checksum,"08b") # get string representation of checksum

# fill .mem file with packet bytes

f_sample = open("packet.mem","w")

input = 2*START_SEQ + input + CRC8 + 2*STOP_SEQ # add calculated checksum

int_arr = [input[i:i+8] for i in range(0, len(input), 8)] # divide into bytes

for byte in int_arr:
    str_in = "0"+byte+parity(byte)+"11\n"
    print(str_in)
    f_sample.write(str_in)

f_sample.close()
