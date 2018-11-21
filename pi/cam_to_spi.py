# import the necessary packages
from picamera.array import PiRGBArray
from picamera import PiCamera
import spidev
import time
import cv2

# initialize the camera and grab a reference to the raw camera capture
camera = PiCamera()

export_resolution = (16, 16)
camera_res = (32, 32)

camera.resolution = camera_res
camera.framerate = 32
rawCapture = PiRGBArray(camera, size=camera_res)

# allow the camera to warmup
time.sleep(0.1)


import spidev
spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 8000000  

# capture frames from the camera
time_start = time.time()
frames = 0
for frame in camera.capture_continuous(rawCapture, format="bgr", use_video_port=True):
        # grab the raw NumPy array representing the image, then initialize the timestamp
    # and occupied/unoccupied text
    image = frame.array

    #grey scale
    image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # resize
    if export_resolution != camera_res:
        image = cv2.resize(image, dsize=export_resolution, interpolation=cv2.INTER_CUBIC)

    #cv2.imshow("Frame", image)
    key = cv2.waitKey(1) & 0xFF

    #print(image[0])
    for row in image:
        spi.xfer(row.tolist())
    # clear the stream in preparation for the next frame
    rawCapture.truncate(0)

    # if the `q` key was pressed, break from the loop
    if key == ord("q"):
        break
    frames += 1
    if frames % 100 == 0:
        print(time.time() - time_start)
        time_start = time.time()
