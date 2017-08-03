// dvb_fifo_reader.v
// Reads a Transport Stream, 32 bits at a time
// Packetizes, inserts null packets when data is unavailable
// Rochester Institute of Technology
// Electrical Engineering Department
// Graduate Paper

module dvb_fifo_reader (clock_data_in, enable, in_reset, empty_in, data_in, read_in_ret, 
						clock_data_out, out_reset, valid_out, data_out);
								
	// Data Input Interface
	input clock_data_in;
	input enable;
	input in_reset; // Active high
	input empty_in; // Active high
	input [31:0] data_in;
	
	// Tells the interface we read
	output reg read_in_ret;
	
	// Output Interface
	input clock_data_out;
	input out_reset;
	output valid_out;
	output data_out;

	// Input clock domain
	reg fifo_empty;
	reg [31:0] send_fifo;
	reg fifo_filled;
	
	// Output clock domain
	reg [10:0] tx_counter;
	reg [31:0] output_fifo;
	reg fifo_emptied;
	reg first_data;
	reg valid_bit;
	
	// Holds the received packets - make sure we have 47 for a full TS frame
	reg [31:0] packet [46:0];
	reg [6:0] packet_rcvd_cnt;
	reg [6:0] packet_send_cnt;

	// Meta flip-flops
	reg [31:0] send_fifo_mff1;
	reg [31:0] send_fifo_mff2;
	reg fifo_filled_mff1;
	reg fifo_filled_mff2;
	reg fifo_emptied_mff1;
	reg fifo_emptied_mff2;
	
	// Initialization for loop ;)
	integer i;
	
	// Input data clock, receiveshold_fifo data from previous fifo
	always @(posedge clock_data_in, posedge in_reset) begin
		if (in_reset) begin
			// IO
			read_in_ret <= 1'b0;

			// Internal signals
			fifo_empty <= 1'b1;
			for (i=0; i<47; i=i+1) begin
				packet[i] <= {32{1'b1}};
			end
			packet[0] <= 32'h471fff10;
			//packet[1] <= 16'hff10;
			packet_rcvd_cnt <= 7'b0;
			packet_send_cnt <= 7'd0;

			// Inter-clock domain
			send_fifo <= 32'hdeadbeea;
			fifo_filled <= 1'b0;
			
			// Metas
			fifo_emptied_mff1 <= 1'b0;
			fifo_emptied_mff2 <= 1'b0;
		end
		else begin
			// Metas
			fifo_emptied_mff1 <= fifo_emptied;
			fifo_emptied_mff2 <= fifo_emptied_mff1;
			
			// Indicate that we filled the fifo for outputting
			if ((fifo_emptied_mff2 == 1'b1) & (fifo_empty == 1'b0)) begin
				fifo_filled <= 1'b0;
			end
			// Wait for the emptied flag to go low again
			else if ((fifo_emptied_mff2 == 1'b0) & (fifo_filled == 1'b0)) begin
				fifo_empty <= 1'b1;
			end

			// Default case, reset every clock cycle
			read_in_ret <= 1'b0;

			// Only if enable and if the send fifo is currently empty
			if ((enable == 1'b1) & (fifo_empty == 1'b1)) begin
				// Ready to send some data packets, we have enough
				if (packet_rcvd_cnt == 7'd47) begin
					// Send TS packets
					send_fifo <= {packet[packet_send_cnt]};

					// Done (check for 46, upcount takes a clock cycle)
					if (packet_send_cnt == 7'd46) begin
						packet_send_cnt <= 7'b0;
						packet_rcvd_cnt <= 7'b0;
					end
					// Not done: upcount
					else begin
						packet_send_cnt <= packet_send_cnt + 2'd1;
					end

					fifo_filled <= 1'b1;
					fifo_empty <= 1'b0;
				end
				// We need more data packets
				else if (read_in_ret == 1'b0) begin
					// If there's data available (not empty)
					if (empty_in == 1'b0) begin
						// Read available packets
						// Change endian-ness
						packet[packet_rcvd_cnt] <= {data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]};
						packet_rcvd_cnt <= packet_rcvd_cnt + 7'b1;

						// Response to input fifo
						read_in_ret <= 1'b1;
					end
				end
			end
		end // if reset
	end // always

	// One bit at a time ;)
	assign data_out = output_fifo[31];
	assign valid_out = valid_bit;

	// Output data clock domain
	always @(posedge clock_data_out, posedge out_reset) begin
		if (out_reset) begin
			// Internal signals
			tx_counter <= 11'b0;
			output_fifo <= 32'hdeadbeef;
			first_data <= 1'b0;
			valid_bit <= 1'b0;

			// Inter-clock domain
			fifo_emptied <= 1'b0;
			
			// Metas
			send_fifo_mff1 <= 32'hdeadbeee;
			send_fifo_mff2 <= 32'hdeadbeed;
			fifo_filled_mff1 <= 1'b0;
			fifo_filled_mff2 <= 1'b0;
		end
		else begin
			// Metas
			send_fifo_mff1 <= send_fifo;
			send_fifo_mff2 <= send_fifo_mff1;
			fifo_filled_mff1 <= fifo_filled;
			fifo_filled_mff2 <= fifo_filled_mff1;

			// Reset valid out if we outputted a bit previously
			if (valid_bit == 1'b1) begin
				valid_bit <= 1'b0;
			end
			else begin
				// We plan on outputting a bit
				valid_bit <= 1'b1;

				// Done transmitting the previous
				if (tx_counter == 0) begin
					// Move hold to output
					if (fifo_filled_mff2 == 1'b1) begin
						// Null packet: 32 bits long
						output_fifo <= send_fifo_mff2;
						tx_counter <= 11'd31;

						// Signal back that we emptied the send_fifo
						fifo_emptied <= 1'b1;

						// We received the first data packet
						first_data <= 1'b1;
					end
					else begin
						// Null packet: 1504 bits long
						output_fifo <= 32'h471fff10;
						tx_counter <= 11'd1503;
					end
				end
				// Not done, shift our output
				else begin
					output_fifo <= output_fifo << 1'b1;
					tx_counter <= tx_counter - 11'b1;

					// Always fill with 1's in case of NULL packet
					output_fifo[0] <= 1'b1;

					// Wait for the fifo_filled flag to reset
					// And reset the fifo_emptied flag
					if (fifo_filled_mff2 == 1'b0) begin
						fifo_emptied <= 1'b0;
					end
				end 
			end
		end // if reset
	end // always
	
endmodule
