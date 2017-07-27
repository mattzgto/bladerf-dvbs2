// Scramble input data stream with pseudo-random sequence
// Receives BBFRAMEs from dvbs2_bbheader
// Synchronous with BBFRAME, starting from MSB and ending after Kbch bits

module dvbs2_bbscrambler (clock, reset, enable, bit_in, valid_in, bit_out, valid_out);
   // Inputs and Outputs
   input  clock;
   input  reset;
   input  enable;
   input  bit_in;
   input  valid_in;
   output bit_out;
   output valid_out;

   // Registers for outputs
   reg bit_out;
   reg valid_out;

   // LFSR for scrambling
   //    Initialized to polynomial at the start of every BBFRAME
   reg       [14:0] shift_register;
   parameter [14:0] init_value = 15'b100101010000000; // generator polynomial is 1+x^14+x^15

   // Number of bits in BBFRAME
   parameter kbch = 58192; // for 9/10 code rate and FEC Coding with normal FECFRAME size

   // Counter to keep track of progress through BBFRAME
   reg [15:0] bit_count; // need 2^16 to count up to kbch

   // Main functionality
   always @(posedge clock, posedge reset) begin
      if (reset) begin // if reset
         shift_register <= init_value;
         bit_count      <= 16'h0000;
         bit_out        <= 1'b0;
         valid_out      <= 1'b0;
      end // if reset
      else begin // else not reset
         if (enable) begin // if enabled
            if(valid_in) begin // Only operate if input data is valid
               shift_register <= {shift_register[1]^shift_register[0],shift_register[14:1]}; // X^15+X^14+1 pseudo random binary sequence generator
               bit_out        <= bit_in ^ (shift_register[1]^shift_register[0]);
               bit_count      <= bit_count + 16'h0001;
               valid_out      <= 1'b1;

               if (bit_count == (kbch-1)) begin // clear count and reset LFSR if reached end of BBFRAME
                  bit_count      <= 16'h0000;
                  shift_register <= init_value;
               end
            end // if valid_in
            else begin // else not valid
               shift_register <= shift_register;
               bit_out        <= 1'b0;
               valid_out      <= 1'b0;
               bit_count      <= bit_count;
            end // else not valid
         end // if enable
      end // else not reset
   end // always

endmodule // dvbs2_bbscrambler
