MAX_ADDRESS = 1024 * 128
MAX_DATA = 1024

# setup SPI
import spidev
spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 8000000  
spi.mode = 0b11

# toggle CS pin manually as writing and reading in the same cycle 
import RPi.GPIO as GPIO
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BOARD)
cs_pin = 22
GPIO.setup(cs_pin, GPIO.OUT)
GPIO.output(cs_pin, GPIO.HIGH)    

# utility functions
def get_cursor_low_high(cursor):
    cursor_low  = cursor & 0xFF 
    cursor_high = cursor >> 8
    return cursor_low, cursor_high

def chunks(l, n):
    """Yield successive n-sized chunks from l."""
    for i in range(0, len(l), n):
        yield l[i:i + n]

def spi_start():
    GPIO.output(cs_pin, GPIO.LOW)    

def spi_stop():
    GPIO.output(cs_pin, GPIO.HIGH)    

def get_ack():
    count = 0
    print("ack ", end = "")
    while True:
        data = spi.readbytes(1)
        # mlaccel core returns 0 when working, 0xFF when done
        if data == [0]:
            break;
        # wait up to 10 cycles before giving up
        count += 1
        if count % 10 == 0:
            print(".", end = "")
    print("")

def spi_wait():
    spi.readbytes(1)

# send an amount of data
def send_data(cursor, data):
    assert cursor <= MAX_ADDRESS
    # send the data to the buffer
    d_len = len(data)
    assert d_len <= MAX_DATA
    spi_start()
    spi.xfer([0x21])
    spi.xfer(data)
    spi_stop()

    # get the buffer written to memory
    spi_start()
    cursor_low, cursor_high = get_cursor_low_high(cursor >> 1)
    spi.xfer([0x23, cursor_low, cursor_high, d_len >> 2])
    spi_wait()
    # wait for data to be written
    get_ack()
    spi_stop()

# read an amount of data
def get_data(cursor, d_len):
    assert cursor <= MAX_ADDRESS
    assert d_len <= MAX_DATA
    # write the address where we want to read
    spi_start()
    cursor_low, cursor_high = get_cursor_low_high(cursor >> 1)
    spi.xfer([0x24, cursor_low, cursor_high, d_len >> 2])
    spi_wait()
    # wait for data to become ready
    get_ack()
    spi_stop()

    # read it
    spi_start()
    spi.xfer([0x22])
    spi_wait()
    data = spi.readbytes(d_len)
    spi_stop()
    return data

# start and wait for kernel
def start_kernel():
    spi_start()
    spi.xfer([0x25])
    spi.xfer([0x00, 0x00])
    spi_stop()

def wait_for_kernel():
    spi_start()
    spi.xfer([0x20])
    spi_wait()
    get_ack()
    spi_stop()

# random write/read test
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

# check ability to write and read up to 1024 bytes
def long_data_test(num_tests, chunk_len):
    data = range(chunk_len)
    data = [d % 256 for d in data ]

    print("writing")
    print("-" * 50)
    cursor = 0
    for t in range(num_tests):
        print("uploading %d bytes to %05x" % (chunk_len, cursor))
        send_data(cursor, data)
        cursor += chunk_len

    print("reading")
    print("-" * 50)
    cursor = 0
    for cursor in range(num_tests):
        print("downloading %d bytes from %05x" % (chunk_len, cursor))
        rx_data = get_data(cursor, chunk_len)
        assert(rx_data == data)
        cursor += chunk_len

    print("success")


if __name__ == '__main__':
    chunk_size = 1024
    assert(chunk_size <= MAX_DATA)

#    long_data_test(128, chunk_size)
#    exit(0)

    # prepare data
    data_in = []
    with open("demo.hex") as data_in_fh:
        data_in_fh.readline()
        for line in data_in_fh.readlines():
            bytes_4 = [int(b, 16) for b in line.strip().split(' ')]
            data_in += bytes_4

    # upload kernel
    print("uploading demo kernel")
    cursor = 0
    for chunk in chunks(data_in, chunk_size):
        chunk_len = len(chunk)
        print("uploading %d bytes to %05x" % (chunk_len, cursor))
        send_data(cursor, chunk)
        cursor += chunk_len

    # check data is valid
    print("readback")
    cursor = 0
    for chunk in chunks(data_in, chunk_size):
        chunk_len = len(chunk)
        print("downloading %d bytes from %05x" % (chunk_len, cursor))
        data = get_data(cursor, chunk_len)
        assert(data == chunk)
        cursor += chunk_len

    # run and wait for the kernel to finish
    print("start kernel")
    start_kernel()
    print("wait kernel")
    wait_for_kernel()

    # prepare comparison data
    data_out = []
    with open("demo_out.hex") as data_out_fh:
        data_out_fh.readline()
        for line in data_out_fh.readlines():
            bytes_16 = [int(b, 16) for b in line.strip().split(' ')]
            data_out += bytes_16

    # check results are valid
    print("checking results")
    cursor = 0x00010000 
    for chunk in chunks(data_out, chunk_size):
        chunk_len = len(chunk)
        print("downloading %d bytes from %05x" % (chunk_len, cursor))
        data = get_data(cursor, chunk_len)
        assert(data == chunk)
        cursor += chunk_len

    print("success")
