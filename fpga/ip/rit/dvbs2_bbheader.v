// Inserts 10 byte base-band header in front of the data field
// Performs CRC-8 encoding on each TS packet
// Receive in order of MSB -> LSB, output in same order
// Process a bit at a time


// block made to work with one faster clock. Want input and output at 8MHz so will have block interface with Matt that gets data at 4 MHz and outputs with valid bits at 8MHz to this block&&&*************

module dvbs2_bbheader (clock, reset, enable, bit_in, valid_in, bit_out, valid_out, error);
   // Inputs and Outputs
   input  clock;
   input  reset;
   input  enable;
   input  bit_in;
   input  valid_in;
   output bit_out;
   output valid_out;
   output error;

   // Parameters
   parameter packet_length_bytes  = 188; // Packet is 188 bytes in length
   parameter header_length_bytes  = 10;  // Base-band header is 10 bytes
   parameter packet_length_bits   = packet_length_bytes*8;
   parameter header_length_bits   = header_length_bytes*8;
   parameter kbch                 = 58192; // number of bits in BBFrame for 9/10 code rate and FEC Coding with normal FECFRAME size
   parameter input_buffer_length  = 80; // number of bytes to buffer at the input

   // Constant BBHeader field values
   // first byte is MATYPE-1
   //    TS/GS Field (2 bits): Transport Stream Input or Generic Stream Input (packetized or continuous) [make it 11 for transport stream]
   //    SIS/MIS Field (1 bit): Single Input Stream or Multiple Input Stream [make it 1 for single stream]
   //    CCM/ACM Field (1 bit): Constant Coding & Modulation or Adaptive Coding & Modulation (VCM=ACM) [Make it 1 for CCM]
   //    ISSYI (1 bit): Input Stream Synchronization Indicator [make it 0 to be inactive]
   //    NPD (1 bit): Null-packet deletion active/not active [make it 0 to be ianctive]
   //    RO (2 bits): Transmission Roll-off Factor (00=0,35  01=0,25  10=0,20  11=reserved) [GNU Radio Projects had 0.20 roll-off factors]
   parameter [7:0]  MATYPE1 = {2'b11,1'b1,1'b1,1'b0,1'b0,2'b10};
   // second byte is MATYPE-2
   //    If SIS/MIS = Multiple Input Stream, MATYPE2=Input Stream Identifier (ISI)
   //    Else MATYPE2 is reserved
   parameter [7:0]  MATYPE2 = 8'h00; // Reserved for single TS
   // UPL (2 bytes): user packet length, range 0-65,535
   //    UPL = 188*8 (in decimal) for MPEG transport stream packets
   parameter [15:0] UPL     = packet_length_bits;
   // DFL (2 bytes): data field length, range 0-58,112
   //    example: DFL=0x000A for dfl of 10 bits
   //    Kbch - 80 (in decimal) where Kbch = # of bits of BCH uncoded Block (BCH = Bose-Chaudhuri-Hocquenghem multiple error correction binary block code)
   //    no padding for broadcast service applications; DFL = Kbch-80 so no padding needed.
   // Resulting BBFRAME should have constant length of Kbch bits
   //    Kbch depends on FEC rate
   parameter [15:0] DFL     = kbch-header_length_bits; // number of bits in data field = BBFrame size - size of header
   // SYNC (1 byte): copy of User Packet Sync-byte
   //    SYNC = 47 (in hex) for MPEG transport stream packets
   parameter [7:0]  SYNC    = 8'h47;

   // Number of bytes in DF
   parameter [12:0] dfl_length_bytes = DFL/8;

   // States
   parameter [1:0] WAIT_TO_START  = 2'b00;
   parameter [1:0] ADD_HEADER     = 2'b01;
   parameter [1:0] PROCESS_PACKET = 2'b10;

   // Internal Signals
   reg [1:0]  state; // Keep track of current state
   reg [7:0]  up_count; // Keep track of what byte of the UP is being worked on (input)
   reg [12:0] df_count; // keep track of what byte of the DF is being worked on (output)
   reg [3:0]  header_count; // Keep track of what byte of the BBHeader is being worked on (output)
   reg        bit_out; // Register to hold bit_out output
   reg        valid_out; // Register to hold valid_out output
   wire       error; // Register to hold error output
   reg        sync_error; // sync byte not where it should be
   reg        fifo_error; // fifo full when trying to write to it
   reg [15:0] SYNCD; // SYNCD (2 bytes): (for packetized TS) distance in bits from beginning of data_field & first UP from this frame (first bit of CRC-8)
   reg [8:1]  crc8_lfsr; // 8 bit LFSR for CRC-8 encoder implementation
   reg        lfsr_in; // 1 bit input to CRC-8 LFSR
   reg        lfsr_en; // 1 bit signal to enable CRC-8 LFSR operation
   reg        lfsr_clr; // 1 bit signal to clear CRC-8 LFSR
   reg [2:0]  bit_count; // bit counter for CRC-8 LFSR feeding
   reg [7:0]  temp; // temporary bytes
   reg        fifo_in; // input to FIFO
   reg        fifo_rd; // read request signal to FIFO
   reg        fifo_wr; // write request signal to FIFO
   wire       fifo_empty; // empty signal from FIFO
   wire       fifo_full; // full signal from FIFO
   wire       fifo_out; // output from FIFO
   wire       clock_not; // inverted version of clock to read from the FIFO on negative edge of clock
   reg        first_bit_flag; // flag to know not to use the FIFO output before first read request at a given time
   reg        fifo_empty_reg; // register FIFO empty signal to match up with when output would actually be available to make sure wanted to read
   reg        lfsr_restore; // Signal to restore LFSR contents to the value of crc8_lfsr_save
   reg [8:1]  crc8_lfsr_save; // need to save LFSR value if starting new BBFRAME without finishing UP
   reg        start_flag; // Don't start internal processing of headers and frames until the block starts receiving data

   assign clock_not = ~clock; // create inverted version of clock

   assign error = sync_error | fifo_error; // raise error output for any error

   // Synchronous FIFO for input data
   //    128 words (word = 1 bit) deep
   //    Separate read and write clocks
   //    Data becomes available after 'rdreq' is asserted, acting as a read request
   fifo_1bit_dual_clk_7bit data_in_fifo (
      .data    (fifo_in), // data is [0:0]
      .rdclk   (clock_not),
      .rdreq   (fifo_rd),
      .wrclk   (clock),
      .wrreq   (fifo_wr),
      .q       (fifo_out), // q is [0:0]
      .rdempty (fifo_empty), // empty signal from the read side of the FIFO
      .wrfull  (fifo_full) // full signal from the write side of the FIFO
   );

   // Deal with input data
   //    Add input data to FIFO if it is valid (deal with write side of FIFO)
   reg [7:0] fifo_up_count;
   reg [2:0] fifo_bit_cnt;


   // Deal with intput data
   always @(posedge clock, posedge reset) begin
      if (reset) begin // if reset
         fifo_in       <= 1'b0;
         fifo_wr       <= 1'b0;
         fifo_error    <= 1'b0;
         fifo_up_count <= 8'h00;
         fifo_bit_cnt  <= 3'b000;
         sync_error    <= 1'b0;
         start_flag    <= 1'b0;
      end // if reset
      else begin // else not reset
         if (valid_in) begin // write input bit to FIFO if it is valid
            start_flag <= 1'b1;
            // Check for sync byte if start of UP and don't add to FIFO
            if (fifo_up_count==8'h00) begin
               if(bit_in!=SYNC[~fifo_bit_cnt]) begin
                  sync_error <= 1'b1;
               end
               else begin
                  sync_error <= 1'b0;
               end
               fifo_in <= 1'b0;
               fifo_wr <= 1'b0; // Don't add sync byte to FIFO since it is replaced with CRC value later anyway
            end
            else begin // Add input bit to FIFO if it isn't a sync byte
               fifo_in <= bit_in;
               fifo_wr <= 1'b1;

               if (fifo_full) begin // error if trying to write to a full FIFO
                 fifo_error <= 1'b1;
               end
               else begin
                  fifo_error <= 1'b0;
               end
            end

            // Keep track of UP bytes to track where sync bytes should be
            fifo_bit_cnt <= fifo_bit_cnt + 3'b001;
            if (fifo_bit_cnt == 3'b111) begin
               fifo_up_count <= fifo_up_count + 8'h01;
               if(fifo_up_count==(packet_length_bytes-1)) begin
                  fifo_up_count <= 8'h00;
               end
            end
         end // if valid input data
         else begin // else not valid input data
            fifo_in       <= 1'b0; // value doesn't matter
            fifo_wr       <= 1'b0; // don't write to FIFO
            fifo_error    <= 1'b0;
            sync_error    <= 1'b0;
            fifo_up_count <= fifo_up_count;
            fifo_bit_cnt  <= fifo_bit_cnt;
            start_flag    <= start_flag;
         end
      end // else not reset
   end // always loop for input data

   // LFSR for CRC-8 encoder implementation
   always @(negedge clock, posedge reset) begin
      if (reset) begin // if reset
         crc8_lfsr <= 8'h00;
      end // if reset
      else begin // else not reset
         if (lfsr_restore) begin
            crc8_lfsr <= crc8_lfsr_save;
         end
         else if (lfsr_clr) begin
            crc8_lfsr <= 8'h00;
         end
         else begin
            if (lfsr_en) begin
         	   crc8_lfsr <= {crc8_lfsr[7]^(lfsr_in^crc8_lfsr[8]), crc8_lfsr[6]^(lfsr_in^crc8_lfsr[8]), crc8_lfsr[5], crc8_lfsr[4]^(lfsr_in^crc8_lfsr[8]), crc8_lfsr[3], crc8_lfsr[2]^(lfsr_in^crc8_lfsr[8]), crc8_lfsr[1], (lfsr_in^crc8_lfsr[8])};
            end
            else begin
               crc8_lfsr <= crc8_lfsr;
            end
         end
      end //else not reset
   end // always

   // Main functionality
   always @(posedge clock, posedge reset) begin
      if (reset) begin // if reset
         state          <= WAIT_TO_START;
         up_count       <= 8'h00;
         df_count       <= 13'h0000;
         header_count   <= 4'h0;
         bit_out        <= 1'b0;
         valid_out      <= 1'b0;
         SYNCD          <= 16'h0000;
         lfsr_in        <= 1'b0;
         bit_count      <= 3'b000;
         lfsr_clr       <= 1'b0;
         lfsr_en        <= 1'b0;
         temp           =  8'h00;
         first_bit_flag <= 1'b0;
         fifo_empty_reg <= 1'b1;
         fifo_rd        <= 1'b0;
         crc8_lfsr_save <= 8'h00;
         lfsr_restore   <= 1'b0;
      end // if reset
      else begin // else not reset
         fifo_empty_reg <= fifo_empty; // register FIFO empty output

         if (enable) begin // Only operate while enabled
            case (state)
               WAIT_TO_START: begin
                  up_count       <= 8'h00;
                  df_count       <= 13'h0000;
                  header_count   <= 4'h0;
                  bit_out        <= 1'b0;
                  valid_out      <= 1'b0;
                  SYNCD          <= 16'h0000;
                  lfsr_in        <= 1'b0;
                  bit_count      <= 3'b000;
                  lfsr_clr       <= 1'b0;
                  lfsr_en        <= 1'b0;
                  temp           =  8'h00;
                  first_bit_flag <= 1'b0;
                  fifo_empty_reg <= 1'b1;
                  fifo_rd        <= 1'b0;
                  crc8_lfsr_save <= 8'h00;
                  lfsr_restore   <= 1'b0;

                  if (start_flag) begin
                     state <= ADD_HEADER;
                  end
                  else begin
                     state <= WAIT_TO_START;
                  end
               end // WAIT_TO_START state
               ADD_HEADER: begin
                  crc8_lfsr_save <= crc8_lfsr_save;
                  lfsr_restore   <= 1'b0;
                  lfsr_en        <= 1'b1;
                  first_bit_flag <= 1'b0;
                  valid_out      <= 1'b1;
                  lfsr_clr       <= 1'b0;

                  // Don't modify counts of other state
                  up_count <= up_count;
                  df_count <= df_count;

                  // Calculate SYNCD to point to MSB of the CRC
                  if (up_count == 8'h00) begin
                     SYNCD <= 8'h00;
                  end
                  else begin
                     SYNCD <= (packet_length_bytes - up_count) * 8;
                  end

                  // Increment count and stay in state by default
                  bit_count <= bit_count + 3'b001;
                  state     <= ADD_HEADER;

                  // Increment header byte count if bit count reaches 8
                  if (bit_count == 3'b111) begin
                     header_count <= header_count + 4'h1;
                  end
                  else begin
                     header_count <= header_count;
                  end

                  case (header_count) // Output portion of BBHeader and add to LFSR for CRC processing of first 9 BBHEADER bytes
                     4'h0: begin
                        temp    =  MATYPE1;
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h1: begin
                        temp    =  MATYPE2;
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h2: begin
                        temp    =  UPL[15:8];
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h3: begin
                        temp    =  UPL[7:0];
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h4: begin
                        temp    =  DFL[15:8];
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h5: begin
                        temp    =  DFL[7:0];
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h6: begin
                        temp    =  SYNC;
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h7: begin
                        temp    =  SYNCD[15:8];
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h8: begin
                        temp    =  SYNCD[7:0];
                        bit_out <= temp[~bit_count];
                        lfsr_in <= temp[~bit_count];
                     end
                     4'h9: begin
                        // Grab CRC-8 value from first 72 bits (9 bytes) being processed
                        if (bit_count == 3'b000) begin
                           temp = crc8_lfsr; // get CRC from BBHEADER bits
                        end
                        bit_out  <= temp[~bit_count];
                        lfsr_clr <= 1'b1; // clear LFSR (initialize to all 0s) before 1st bit of next sequence enters it

                        // Need to reset LFSR value to the CRC from the previous frame processing since will still be in the same UP (UP spans across two BBFRAMEs)
                        if (SYNCD!=8'h00) begin
                           lfsr_restore <= 1'b1;
                        end
                        else begin
                           lfsr_restore <= 1'b0;
                        end

                        // Done with BBHeader once bits of last byte are done
                        if (bit_count == 3'b111) begin
                           header_count   <= 4'h0; // reset count
                           state          <= PROCESS_PACKET; // done with BBHEADER
                           lfsr_en        <= 1'b0;
                           first_bit_flag <= 1'b0;
                           lfsr_clr       <= 1'b0;
                           lfsr_restore   <= 1'b0;
                           lfsr_in        <= fifo_out;
                           lfsr_en        <= 1'b1;
                        end
                     end
                     default: begin // shouldn't get here
                        bit_out <= 1'b0;
                        lfsr_in <= 1'b0;
                     end
                  endcase // header_count
               end // ADD_HEADER state
               PROCESS_PACKET: begin
                  lfsr_clr     <= 1'b0; // CRC8 encoding being performed on UP (of length UPL-8bits)
                  lfsr_en      <= 1'b0;
                  lfsr_restore <= 1'b0;
                  fifo_rd      <= 1'b0;

                  // stay in state by default
                  state <= PROCESS_PACKET;

                  // SYNC byte (at start of UP) replaced with the current CRC
                  if (up_count==8'h00) begin
                     if (bit_count == 3'b000) begin
                        temp = crc8_lfsr; // grab CRC
                     end

                     bit_out   <= temp[~bit_count];
                     valid_out <= 1'b1;
                     lfsr_clr  <= 1'b1;
                     bit_count <= bit_count + 3'b001; // increment bit counter

                    // Increment byte counts if bit count reaches 8
                     if (bit_count == 3'b111) begin
                        up_count <= up_count + 8'h01;
                        df_count <= df_count + 13'h0001;

                        // Go back to adding BBHEADER if filled up data field
                        if (df_count==(dfl_length_bytes-1)) begin
                           state    <= ADD_HEADER;
                           df_count <= 13'h0000;
                           lfsr_clr <= 1'b1;
                           fifo_rd  <= 1'b0;
                        end
                     end // if bit_count == 3'b111
                    else begin
                        up_count <= up_count;
                        df_count <= df_count;
                     end
                  end // if replacing sync byte with CRC
                  else begin // else pass through the bit of the UP and start computing CRC
                     // Set up FIFO read if it isn't empty
                     if (!fifo_empty) begin
                        fifo_rd <= 1'b1;
                     end
                     else begin
                        fifo_rd <= 1'b0;
                     end

                     valid_out <= 1'b0;
                     if(first_bit_flag) begin
                        first_bit_flag <= first_bit_flag;
                        if (!fifo_empty_reg) begin // check if did a read last cycle and now have valid FIFO output data
                           bit_out   <= fifo_out;
                           valid_out <= 1'b1;
                           lfsr_in   <= fifo_out;
                           lfsr_en   <= 1'b1;
                           bit_count <= bit_count + 3'b001; // increment bit counter

                           // Increment byte counts if bit count reaches 8
                           if (bit_count == 3'b111) begin
                              up_count <= up_count + 8'h01;
                              df_count <= df_count + 13'h0001;

                              if (up_count==(packet_length_bytes-1)) begin
                                 up_count <= 8'h00;
                              end

                              // Go back to adding BBHEADER if filled up data field
                              if (df_count==(dfl_length_bytes-1)) begin
                                 state          <= ADD_HEADER;
                                 df_count       <= 13'h0000;
                                 lfsr_clr       <= 1'b1;
                                 fifo_rd        <= 1'b0;
                                 crc8_lfsr_save <= crc8_lfsr; // save value in case it is needed (if not end of a UP)
                              end
                           end
                           else begin
                              up_count <= up_count;
                              df_count <= df_count;
                           end
                        end // if did read last cycle
                        else begin
                           up_count  <= up_count;
                           df_count  <= df_count;
                           bit_out   <= 1'b0;
                           valid_out <= 1'b0;
                           bit_count <= bit_count;
                           lfsr_in   <= lfsr_in;
                           lfsr_en   <= 1'b0;
                        end
                     end // if first_bit_flag
                     else begin
                        first_bit_flag <= 1'b1;
                     end
                  end // else processing UP bits

                  // don't modify header_count
                  header_count <= header_count;
               end // PROCESS_PACKET state
               default: begin
                  // Shouldn't get here
               end
            endcase // state
         end // if enable
      end // else not reset
   end // always

endmodule // dvbs2_bbheader
