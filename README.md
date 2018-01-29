# bladerf-dvbs2
#### 16-APSK DVB-S2 Transmitter for the bladeRF SDR FPGA. 
####
#### The DVB-S2 modulation is written completely in Hardware, using Verilog. The transmitter was written by Adam Steenkamer, integration and test was performed by Matthew Zachary. Developed for the bladeRF with 40kLE Cyclone IV FPGA

### File Location:
Pre-compiled FPGA image is provided under quartus/work/output_files

### Description:
The bladeRF-CLI is a command line interface to the BladeRF SDR, developed by Nuand, the maker of the BladeRF hardware.
With the factory FPGA image loaded onto the SDR, the CLI accepts I/Q samples as an input, in order to generate output RF signals.

However, with this bladeRF-dvbs2 FPGA image, the CLI will accept MPEG2 transport stream data as an input. The CLI itself remains unchanged, however, the FPGA image has been modified to interpret the data from the CLI as transport stream data instead of IQ data.

MPEG2 transport streams (TS) can contain video, audio, and data, multiplexed together into a single stream. This TS serves as the input to the DVB-S2 modulation system, which in this case, is performed in the FPGA.

Therefore, this transmitter will be used to provide a 8 Mbps multimedia downlink that uses DVB-S2 modulation. The intended application is for a high-altitude balloon, which transmits live telemetry data and HD video during flight to a receiving base station. The 23cm amateur radio band will be used (1.28 GHz).

This setup has been tested with a Raspberry Pi 3. The Pi Camera 2, alongside the H.264 encoder built into the Pi, is used to capture compressed video. FFMPEG is used to encapsulate this compressed video into a transport stream, which is transmitted using DVB-S2 modulation within the bladeRF FPGA.


### Specs:

|                     |                |
|---------------------|----------------|
| Input bit rate:     | 8M bit/s       |
| Output symbol rate: | 5M samples/s   |

|                     |                |
|---------------------|----------------|
| FEC Frame Size      | Normal (16200) |
| Code Rate           | 9/10           |
| Roll-off Factor     | 0.2            |
 


### Example video capture command:
(captures HD video from the Raspberri Pi Camera 2 to video.ts)
	
	raspivid -n -t 0 -fps 25 -w 1280 -h 720 -pf high -vf -hf -b 1000000 -o - | ffmpeg -re -an -i - -vcodec copy -f mpegts -mpegts_flags system_b - > video.ts
	
	
### Example CLI command:
(sends TS data from video.ts to the bladeRF SDR to be modulated using DVB-S2)

	bladeRF-cli -e "load fpga quartus/work/output_files/withdvb.rbf; set frequency 1280000000; set bandwidth 3500000; set samplerate 5200000; tx config file=video.ts; tx config repeat=1; set txvga1 -4; set txvga2 25; tx start; tx wait;"



	
### Details:
The Nuand bladeRF-cli API can still be used. Leave the tx data format in binary mode, and pass in TS (transport stream) packets instead of I/Q samples

All receiving blocks have been removed from the FPGA, and therefore, all RX functionality has been removed

The input is buffered by inserting NULL TS packets, and the output is buffered by inserting Dummy PLFrames

Recompiling will be necessary for the bladeRF with 115kLE
