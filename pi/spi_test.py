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
        print(".")
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
    return data

def start_kernel():
    print("start kernel")
    GPIO.output(cs_pin, GPIO.LOW)    
    spi.xfer([0x25, 0, 0])
#    spi.xfer([0x00, 0x00])
    GPIO.output(cs_pin, GPIO.HIGH)    

def wait_for_kernel():
    print("wait kernel")
    GPIO.output(cs_pin, GPIO.LOW)    
    spi.xfer([0x20])
    get_ack()
    GPIO.output(cs_pin, GPIO.HIGH)    


def random_write_read_test():
    import random
    count = 0
    while True:
        print(count)
        count += 1
        for cursor in range(255):
            rand_data = [ random.randint(0, 255), random.randint(0,255) ]
            send_data(cursor, rand_data)
            rx_data = get_data(cursor, len(rand_data))
            assert(rx_data == rand_data)

def long_data_test():
    for cursor in range(128):
        print(cursor)
        data = range(255)
        data *= 4
        send_data(cursor, data)
        rx_data = get_data(cursor, len(data))
        assert(rx_data == data)

def chunks(l, n):
    """Yield successive n-sized chunks from l."""
    for i in xrange(0, len(l), n):
        yield l[i:i + n]

def print_hex(data):
    out_str = ""
    for d in data:
        out_str += "%02x " % d
    print(out_str)

if __name__ == '__main__':
#    long_data_test()
#    exit(0)

    data_in = []
    print("uploading demo kernel")
    with open("demo.hex") as in_data:
        in_data.readline()
        for line in in_data.readlines():
            bytes_4 = [int(b, 16) for b in line.strip().split(' ')]
            data_in += bytes_4
    
    cursor = 0
    for chunk in chunks(data_in, 1024):
        chunk_len = len(chunk)
        print("uploading %d bytes to %d" % (chunk_len, cursor))
        send_data(cursor, chunk)
        cursor += chunk_len

    print("readback")
    cursor = 0
    for chunk in chunks(data_in, 128):
        chunk_len = len(chunk)
        print("downloading %d bytes from %d" % (chunk_len, cursor))
        data = get_data(cursor, chunk_len)
        assert(data == chunk)
        cursor += chunk_len

    start_kernel()
    wait_for_kernel()

    print("checking results")
    data_out = []
    with open("demo_out.hex") as out_data:
        out_data.readline()
        for line in out_data.readlines():
            bytes_16 = [int(b, 16) for b in line.strip().split(' ')]
            data_out += bytes_16

    print("readback")
    cursor = 0x00010000 
    for chunk in chunks(data_out, 128):
        chunk_len = len(chunk)
        print("downloading %d bytes from %d" % (chunk_len, cursor))
        data = get_data(cursor, chunk_len)
        assert(data == chunk)
        cursor += chunk_len

    print("success")
