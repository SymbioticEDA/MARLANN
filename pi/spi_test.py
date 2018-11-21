import spidev


import spidev
spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 8000000  
spi.mode = 0b11


def send_data(cursor):
    # send the data
    spi.xfer([0x21, cursor])
    #               2 bytes word  len 
    spi.xfer([0x23, cursor, 0x00, 0x01, 0,0, 0])


def get_data(cursor):
    spi.xfer([0x24, cursor, 0x00, 0x01, 0x00, 0x00, 0])
    data = spi.xfer([0x22, 0x00,  0])
    print(data)
    return data[2]

for cursor in range(100):
    send_data(cursor)
    data = get_data(cursor)
    assert(data == cursor)

#print(spi.readbytes(1))
#spi.xfer([0x20, 0, 0, 0])
#print(spi.readbytes(8))
