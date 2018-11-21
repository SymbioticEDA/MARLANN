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

def send_data(cursor):
    # send the data
    GPIO.output(cs_pin, GPIO.LOW)    
    spi.xfer([0x21, cursor])
    GPIO.output(cs_pin, GPIO.HIGH)    
    #               2 bytes word  len 
    GPIO.output(cs_pin, GPIO.LOW)    
    spi.xfer([0x23, cursor, 0x00, 0x01])
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

def get_data(cursor):
    GPIO.output(cs_pin, GPIO.LOW)    
    spi.xfer([0x24, cursor, 0x00, 0x01])
    get_ack()
    GPIO.output(cs_pin, GPIO.HIGH)    

    GPIO.output(cs_pin, GPIO.LOW)    
    data = spi.xfer([0x22, 0x00,  0])
    GPIO.output(cs_pin, GPIO.HIGH)    
    print(data)
    return data[2]

for cursor in range(255):
    send_data(cursor)
    data = get_data(cursor)
    assert(data == cursor)
