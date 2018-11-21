import spidev


import spidev
spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 8000000  
spi.mode = 0b11
cs_pin = 22
import RPi.GPIO as GPIO
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BOARD)
GPIO.setup(cs_pin, GPIO.OUT)
GPIO.output(cs_pin, GPIO.HIGH)    

def get_cursor_low_high(cursor):
    cursor = cursor >> 1
    cursor_low  = cursor & 0xFF 
    cursor_high = cursor >> 8
    return cursor_low, cursor_high

def send_data(cursor, data):
    # send the data to the buffer
    d_len = len(data)
    GPIO.output(cs_pin, GPIO.LOW)    
    spi.xfer([0x21])
    spi.xfer(data)
    GPIO.output(cs_pin, GPIO.HIGH)    

    # get the buffer written to memory
    GPIO.output(cs_pin, GPIO.LOW)    
    cursor_low, cursor_high = get_cursor_low_high(cursor)
    spi.xfer([0x23, cursor_low, cursor_high, d_len >> 2])
    get_ack()
    GPIO.output(cs_pin, GPIO.HIGH)    

def get_ack():
    count = 0
    while True:
        data = spi.readbytes(1)
        # mlaccel core returns 0 when working, 0xFF when done
        if data != [0]:
            break;
        # wait up to 10 cycles before giving up
        count += 1
        if(count == 10):
            print("no reply")
            exit(1)

def get_data(cursor, d_len):
    GPIO.output(cs_pin, GPIO.LOW)    
    cursor_low, cursor_high = get_cursor_low_high(cursor)
    spi.xfer([0x24, cursor_low, cursor_high, d_len >> 2])
    get_ack()
    GPIO.output(cs_pin, GPIO.HIGH)    

    GPIO.output(cs_pin, GPIO.LOW)    
    spi.xfer([0x22, 0x00])
    data = spi.readbytes(d_len)
    GPIO.output(cs_pin, GPIO.HIGH)    
    print(data)
    return data

import random
for cursor in range(255):
    rand_data = [ random.randint(0, 255), random.randint(0,255) ]
    send_data(cursor, rand_data)
    data = get_data(cursor, len(rand_data))
    assert(data == rand_data)
