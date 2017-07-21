// Operates on a BBFRAME and works with the LDPC encoder to generator an FECFRAME
// Adds 128 parity bits to the end of BBFRAME
// Configured for normal FECFRAME size and 9/10 FEC code rate

module dvbs2_bchencoder (clock, reset, enable, bit_in, valid_in, bit_out, valid_out, error);
   // Inputs and Outputs
   input  clock;
   input  reset;
   input  enable;
   input  bit_in;
   input  valid_in;
   output bit_out;
   output valid_out;
   output error; // raised if trying to write to a full FIFO

   // Parameters
   parameter kbch      = 58192; // number of bits in BBFRAME for 9/10 code rate and FEC coding with normal FECFRAME size
   parameter nbch      = 58320; // number of bits in BCH coded block BCH for the above case (BBFRAME bits + BCHFEC parity bits)
   parameter bch_bits  = 128; // =nbch - kbch; // number of BCH parity bits (should be 128 for this case)
   parameter kldpc     = nbch; // number of bits in LDPC uncoded block for the above case (same as Nbch)
   parameter nldpc     = 64800; // number of bits in LDPC coded block (in FEC Frame) for the above case
   parameter ldpc_bits = nldpc - kldpc; // number of LDPC parity bits (LDPCFEC)

   parameter input_buffer_length  = bch_bits;//80; // number of bits to buffer at the input 
   parameter output_buffer_length = bch_bits;//80; // number of bits to buffer at the output 

   // States
   parameter [1:0] PROCESS_FRAME   = 2'b00;
   parameter [1:0] ADD_PARITY_BITS = 2'b01;
   parameter [1:0] WAIT_TO_READ    = 2'b10;

   // Internal Signals
   reg [bch_bits-1:0] lfsr; // 128 bit LFSR for BCH Encoding parity bit generation where [bch_bits-1] is first bit of LFSR and [0] is last bit of LFSR
   reg [bch_bits-1:0] temp;
   reg                lfsr_in; // 1 bit input to LFSR
   reg                lfsr_clr; // 1 bit signal to clear LFSR
   reg                lfsr_en; // 1 bit signal to enable operation of the LFSR (shift and XOR)
   reg [1:0]          state; // keep track of current state
   reg [bch_bits-1:0] gen_poly; // generator polynomial
   reg [15:0]         bit_count; // need 2^16 for counting bits in frame
   reg [7:0]          parity_bit_cnt; // need 2^7=128 for counting parity bits
   reg                bit_out; // actual output
   reg                valid_out; // actual output
   reg                error; // error output
   reg                fifo_in; // input to FIFO
   reg                fifo_rd; // read request signal to FIFO
   reg                fifo_wr; // write request signal to FIFO
   wire               fifo_empty; // empty signal from FIFO
   wire               fifo_full; // full signal from FIFO
   wire               fifo_out; // output from FIFO
   wire               clock_not; // inverted version of clock to write to FIFO on negative edge of clock

   assign clock_not = ~clock; // create inverted version of clock

   // Synchronous FIFO for input data
   //    256 words (word = 1 bit) deep
   //    Separate read and write clocks
   //    Data becomes available after 'rdreq' is asserted, acting as a read request
   fifo_1bit_dual_clk_8bit data_in_fifo (
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
   always @(posedge clock) begin
      if (reset) begin // if reset
         fifo_in <= 1'b0;
         fifo_wr <= 1'b0;
         error   <= 1'b0;
      end // if reset
      else begin // else not reset
         if (valid_in) begin // write input bit to FIFO if it is valid
            fifo_in <= bit_in;
            fifo_wr <= 1'b1;

            if (fifo_full) begin // error if trying to write to a full FIFO
               error <= 1'b1;
            end
            else begin
               error <= 1'b0;
            end
         end
         else begin
            fifo_in <= 1'b0; // value doesn't matter
            fifo_wr <= 1'b0; // don't write to FIFO
            error   <= 1'b0;
         end
      end // else not reset
   end // always loop for input data

   // LFSR
   always @(negedge clock) begin
      if (reset) begin // if reset
         temp      = 128'h00000000000000000000000000000000;
         lfsr      <= 128'h00000000000000000000000000000000;
         gen_poly  <= {32'hd4669f20, 32'haeb63f98, 32'hbde9e48e, 32'hfaa4e038}; // generator polynomial where MSB is first bit of LFSR and LSB is last bit in LFSR
      end // if reset
      else begin // else not reset
         gen_poly <= gen_poly;
         if (lfsr_clr) begin
            temp = 128'h00000000000000000000000000000000;
            lfsr <= 128'h00000000000000000000000000000000; // LFSR cleared after each BBFRAME
         end
         else begin
            if (lfsr_en) begin
               temp = {1'b0,lfsr[bch_bits-1:1]}; // shift right
               if (lfsr_in == 1'b1) begin
                  lfsr <= temp ^ gen_poly; // XOR shifted LFSR contents with generator polynomial
               end
         	   else begin
         	      lfsr <= temp; // only shift right
         	   end
         	end
         	else begin
               lfsr <= lfsr;
         	end
         end
      end //else not reset
   end // LFSR always

   // Main functionality
   always @(posedge clock) begin
      if (reset) begin // if reset
         state          <= WAIT_TO_READ;//PROCESS_FRAME;
         bit_count      <= 16'h0000;
         lfsr_in        <= 1'b0;
         lfsr_clr       <= 1'b0;
         lfsr_en        <= 1'b0;
         bit_out        <= 1'b0;
         valid_out      <= 1'b0;
         parity_bit_cnt <= 8'h00;
      end // if reset
      else begin // else not reset
         //fifo_empty_reg <= fifo_empty; // register FIFO empty output

         if (enable) begin // only operate if enabled
            case (state)
               WAIT_TO_READ: begin
                  bit_out        <= 1'b0;
                  valid_out      <= 1'b0;
                  bit_count      <= bit_count;
                  parity_bit_cnt <= parity_bit_cnt;
                  lfsr_in        <= lfsr_in;
                  lfsr_clr       <= lfsr_clr;
                  lfsr_en        <= 1'b0;

                  // Set up FIFO read if it isn't empty
                  if (!fifo_empty) begin
                     fifo_rd <= 1'b1;
                     state   <= PROCESS_FRAME;
                  end
                  else begin
                     fifo_rd <= 1'b0;
                     state   <= WAIT_TO_READ;
                  end

               end // WAIT_TO_READ state
               PROCESS_FRAME: begin // bring bits in, send out, and send them to be processed in LFSR
                  parity_bit_cnt <= 8'h00; // only used in ADD_PARITY_BITS state
                  lfsr_clr       <= 1'b0; // operating on bits for parity bit creation in LFSR
                  bit_out        <= fifo_out;
                  valid_out      <= 1'b1;
                  bit_count      <= bit_count + 16'h0001; // increment counter
                  lfsr_in        <= fifo_out ^ lfsr[0]; // Send input^last bit of LFSR into LFSR
                  lfsr_en        <= 1'b1;

                  if (bit_count == (kbch-1)) begin // check if reached end of BBFRAME bits
                     state   <= ADD_PARITY_BITS;
                     fifo_rd <= 1'b0; // Stop reading from the FIFO
                  end
                  else begin
                     // Set up FIFO read if it isn't empty
                     if (!fifo_empty) begin
                        fifo_rd <= 1'b1;
                        state   <= PROCESS_FRAME;
                     end
                     else begin
                        fifo_rd <= 1'b0;
                        state   <= WAIT_TO_READ;
                     end
                  end
               end // PROCESS_FRAME state
               ADD_PARITY_BITS: begin // send out parity bits once done with frame. shift out bits from the LFSR to get the parity bits.
                  bit_count      <= bit_count + 16'h0001; // increment counter to still count bits in BBFRAME+BCHFEC_bits
                  parity_bit_cnt <= parity_bit_cnt + 8'h01; // increment parity bit counter
                  lfsr_clr       <= 1'b0; // grabbing parity bits from LFSR
                  lfsr_in        <= 1'b0; // value doesn't matter since not used in this state
                  lfsr_en        <= 1'b0;
                  valid_out      <= 1'b1; // parity bits are valid output bits
                  bit_out        <= lfsr[parity_bit_cnt]; // output a parity bit

                 if (parity_bit_cnt == bch_bits) begin
                     lfsr_clr       <= 1'b1; // reset the LFSR
                     state          <= WAIT_TO_READ;//PROCESS_FRAME; // back to frame processing state
                     parity_bit_cnt <= 8'h00;
                     bit_count      <= 16'h0000;
                     valid_out      <= 1'b0;
                     bit_out        <= 1'b0;
                  end
                  else begin // still have parity bits to output
                     state <= ADD_PARITY_BITS; // remain in current state
                  end
               end // ADD_PARITY_BITS state
               default: begin
                  // shouldn't reach
               end
            endcase // state machine
         end // if enabled
      end // else not reset
   end // main always

endmodule // dvbs2_bchencoder
