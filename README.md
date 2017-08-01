# bladerf-dvbs2
## 16-APSK DVB-S2 Transmitter for BladeRF

### DVB-S2 Transmitter written by Adam Steenkamer, Integration performed by Matthew Zachary

### Developed for the bladeRF with 40kLE Cyclone IV FPGA

 

Pre-compiled FPGA image is provided under quartus/work/output_files

The Nuand bladeRF-cli API can still be used. Leave the tx data format in binary mode, and pass in TS (transport stream) packets instead of I/Q samples

All receiving blocks have been removed from the FPGA, and therefore, all RX functionality has been removed

The input is buffered by inserting NULL TS packets, and the output is buffered by inserting Dummy PLFrames

 

### Specs:

	Input bit rate: 8M bit/s  
	Output symbol rate: 5.2M samples/s
	  
	FEC Frame Size = Normal (16200)  
	Code Rate = 9/10   
	Roll-off factor = 0.2
 

### Example command:

	bladeRF-cli -e "load fpga quartus/work/output_files/withdvb.rbf; set frequency 1280000000; set bandwidth 3500000; set samplerate 5200000; tx config file=video.ts; tx config repeat=1; set txvga1 -4; set txvga2 25; tx start; tx wait;"