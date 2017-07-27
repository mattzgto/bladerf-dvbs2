// Operates on a BBFRAME+BCH Parity Bits (BBFRAME+BCHFEC) to generate an FECFRAME
// Adds 6480 parity bits to the end of BBFRAME+BCHFEC
// Configured for normal FECFRAME size and 9/10 FEC code rate

module dvbs2_ldpcencoder (clock_16MHz, clock_96MHz, reset, enable, bit_in, valid_in, bit_out, valid_out, error);
   // Inputs and Outputs
   input  clock_16MHz;
   input  clock_96MHz;
   input  reset;
   input  enable;
   input  bit_in;
   input  valid_in;
   output bit_out;
   output valid_out;
   output error; // Raised if trying to write to a full FIFO

   // Parameters
   parameter kldpc     = 58320; // Number of bits in LDPC uncoded block for 9/10 code rate and FEC coding with normal FECFRAME size (same as Nbch)
   parameter nldpc     = 64800; // Number of bits in LDPC coded block (in FEC Frame) for the above case
   parameter ldpc_bits = nldpc - kldpc; // Number of LDPC parity bits (LDPCFEC)
   parameter q_val     = 18; // q=18 for the above case

   // Parity bit addresses
   reg  [12:0] current_addresses [0:3]; // 3-4 parity bit addresses being used for the current input bits
   reg  [7:0]  parity_mem1_address; // Address to read from parity bit base addresses memory 1
   wire [12:0] parity_mem1_out; // Output parity bit base address from parity bit base addresses memory 1
   reg  [7:0]  parity_mem2_address; // Address to read from parity bit base addresses memory 2
   wire [12:0] parity_mem2_out; // Output parity bit base address from parity bit base addresses memory 2
   reg  [7:0]  parity_mem3_address; // Address to read from parity bit base addresses memory 3
   wire [12:0] parity_mem3_out; // Output parity bit base address from parity bit base addresses memory 3
   reg  [7:0]  parity_mem4_address; // Address to read from parity bit base addresses memory 4
   wire [12:0] parity_mem4_out; // Output parity bit base address from parity bit base addresses memory 4

   // States for main state machine
   parameter [1:0] PROCESS_FRAME     = 2'b00;
   parameter [1:0] ADD_PARITY_BITS   = 2'b01;
   parameter [1:0] WAIT_TO_READ      = 2'b10;
   parameter [1:0] PARITY_WAIT       = 2'b11;

   // States for parity bit state machine
   parameter [3:0] MAIN_WAIT             = 4'h0;
   parameter [3:0] FIRST_SETUP           = 4'h1;
   parameter [3:0] FIRST_READ_AND_WRITE  = 4'h2;
   parameter [3:0] SECOND_SETUP          = 4'h3;
   parameter [3:0] SECOND_READ_AND_WRITE = 4'h4;
   parameter [3:0] PRE_MAIN_WAIT         = 4'h5;
   parameter [3:0] FINAL_WAIT            = 4'h6;
   parameter [3:0] FINAL_SETUP           = 4'h7;
   parameter [3:0] FINAL_READ_AND_WRITE  = 4'h8;
   parameter [3:0] PRE_FINAL_WAIT        = 4'h9;
   parameter [3:0] FINAL_FIRST_BIT_OUT   = 4'hA;
   parameter [3:0] FINAL_FIRST_BIT_WAIT  = 4'hB;

   // Internal Signals
   reg [1:0]           state; // Keep track of current state for the main state machine
   reg [15:0]          bit_count; // Need 2^16 for counting bits in frame
   reg [12:0]          parity_bit_count; // Need 2^13 for counting parity bits
   reg                 bit_out; // Register actual output bit
   reg                 valid_out; // Register actual valid output
   reg                 error; // Register error output
   reg [7:0]           group_count; // Need 2^8 to count the 162 groups of 360 bits from input frame (used for addressing the parity bit address memories)
   reg [8:0]           group_bit_count; // Count individual input bits (360 total) in a single group
   reg [12:0]          parity_bit_address1_reg; // Register current_addresses[0] in the 48MHz domain
   reg [12:0]          parity_bit_address1; // Double register current_addresses[0] in the 48MHz domain
   reg [12:0]          parity_bit_address2_reg; // Register current_addresses[1] in the 48MHz domain
   reg [12:0]          parity_bit_address2; // Double register current_addresses[1] in the 48MHz domain
   reg [12:0]          parity_bit_address3_reg; // Register current_addresses[2] in the 48MHz domain
   reg [12:0]          parity_bit_address3; // Double register current_addresses[2] in the 48MHz domain
   reg [12:0]          parity_bit_address4_reg; // Register current_addresses[3] in the 48MHz domain
   reg [12:0]          parity_bit_address4; // Double register current_addresses[3] in the 48MHz domain
   reg                 bit_in_reg; // Registered input bit from the input FIFO
   reg                 bit_in_reg1; // Register bit_in_reg in the 48MHz domain
   reg                 bit_in_reg2; // Double register bit_in_reg in the 48MHz domain
   reg [3:0]           parity_bit_state; // Keep track of the current state of the parity bit memory state machine
   reg                 parity_bit_enable; // Flag from the 8MHz domain that the address and data from it to the 48MHz domain is good
   reg                 parity_bit_enable_reg; // Register parity_bit_enable in the 48MHz domain
   reg                 parity_bit_enable_reg2; // Dobule register parity_bit_enable in the 48MHz domain
   reg                 final_parity_flag; // Flag from the 8MHz domain that the final parity bit processing and outputting is ready
   reg                 final_parity_flag_reg; // Register final_parity_flag in the 48MHz domain
   reg                 final_parity_flag_reg2; // Double register final_parity_flag in the 48MHz domain
   reg                 final_pass_begin; // flag for first pit of final parity processing pass
   reg                 final_parity_bit_out; // Final parity bit value to be output from the block
   reg                 final_parity_bit_out_valid; // Valid flag for the above
   reg [1:0]           final_parity_wait_count; // Need to stay in PRE_FINAL_WAIT for 3 cycles
   reg                 add_parity_bit_wait; // Count to keep track of how long to stay in PARITY_WAIT
   reg [12:0]          parity_bit_count2; // Parity bit count for 48MHz state machine
   reg [1:0]           first_parity_bit_count; // Count to keep track of how long to stay in FINAL_FIRST_BIT_WAIT

   // FIFO Signals
   reg                 fifo_in; // Input to FIFO
   reg                 fifo_rd; // Read request signal to FIFO
   reg                 fifo_wr; // Write request signal to FIFO
   wire                fifo_empty; // Empty signal from FIFO
   wire                fifo_full; // Full signal from FIFO
   wire                fifo_out; // Output from FIFO
   wire                clock_16MHz_not; // Inverted version of clock to write to FIFO on negative edge of clock

   // For the parity bit memory
   reg  [12:0]         parity_bit_address_a; // Address for Port A of parity bit memory
   reg  [12:0]         parity_bit_address_b; // Address for Port B of parity bit memory
   reg  [1:0]          parity_bit_mem_in_a; // Input for writing to Port A of the parity bit memory
   reg  [1:0]          parity_bit_mem_in_b; // Input for writing to Port B of the parity bit memory
   reg                 parity_bit_mem_wr_a; // Control input for writing to Port A of the parity bit memory
   reg                 parity_bit_mem_wr_b; // Control input for writing to Port B of the parity bit memory
   wire [1:0]          parity_bit_mem_out_a; // Output from Port A of the parity bit memory
   wire [1:0]          parity_bit_mem_out_b; // Output from Port B of the parity bit memory
   wire                clock_96MHz_not; // Inverted version of faster parity bit memory clock

   assign clock_16MHz_not  = ~clock_16MHz; // create inverted version of clock
   assign clock_96MHz_not = ~clock_96MHz; // create inverted version of clock

   // Synchronous FIFO for input data
   //    8,192 (2^13) words (word = 1 bit) deep
   //    Separate read and write clocks
   //    Data becomes available after 'rdreq' is asserted, acting as a read request
   fifo_1bit_dual_clk_13bit data_in_fifo (
      .data    (fifo_in), 
      .rdclk   (clock_16MHz_not),
      .rdreq   (fifo_rd),
      .wrclk   (clock_16MHz),
      .wrreq   (fifo_wr),
      .q       (fifo_out),
      .rdempty (fifo_empty), // Empty signal from the read side of the FIFO
      .wrfull  (fifo_full) // Full signal from the write side of the FIFO
   );

   // Address with the base parity bit addresses of which parity bits to modify
   //    These addresses are used at the start of a 360 bit group of input data and are used to calculate the addresses to modify for the rest of the bits in a group
   parity_mem1 address_mem1 (
      .address (parity_mem1_address),
      .clock   (clock_16MHz_not),
      .q       (parity_mem1_out)
   );
   parity_mem2 address_mem2 (
      .address (parity_mem2_address),
      .clock   (clock_16MHz_not),
      .q       (parity_mem2_out)
   );
   parity_mem3 address_mem3 (
      .address (parity_mem3_address),
      .clock   (clock_16MHz_not),
      .q       (parity_mem3_out)
   );
   parity_mem4 address_mem4 (
      .address (parity_mem4_address),
      .clock   (clock_16MHz_not),
      .q       (parity_mem4_out)
   );

   // Dual Port memory (RAM) to store the 6480 parity bits
   //    Dual port so 2 addresses can be read from or written to each clock cycle.
   //    2 bit memory contents. The lower bit is the actual parity bit value. The upper bit is '0' if the lower bit is valid or '1' if it isn't.
   //    Parity bits are invalid at the end of a frame. Set upper bit to '1' after read parity bits in the final parity operation of Pi=Pi^Pi-1.
   //    If read parity bit mem to modify a value and upper bit is '1' then use 0 as teh value and write back '0' to the upper bit and the new value in the lower bit.
   //    Need to read from and write to 3-4 spots per output clock (8Mhz) cycle when processing an input frame. With 2 reads/writes per cycle here, need 4 clock cycles of faster clock in the same time.
   //    A 48 MHz clock (6 times faster than the 8MHz output clock of the block) will be used.
   parity_bit_dualport_ram parity_bit_mem (
      .address_a (parity_bit_address_a),
      .address_b (parity_bit_address_b),
      .clock     (clock_96MHz_not),
      .data_a    (parity_bit_mem_in_a),
      .data_b    (parity_bit_mem_in_b),
      .wren_a    (parity_bit_mem_wr_a),
      .wren_b    (parity_bit_mem_wr_b),
      .q_a       (parity_bit_mem_out_a),
      .q_b       (parity_bit_mem_out_b)
   );

   // Deal with input data
   //    Add input data to FIFO if it is valid (deal with write side of FIFO)
   //    Set inputs to FIFO at positive edge of clock and FIFO will grab them at the negative edge of clock
   always @(posedge clock_16MHz, posedge reset) begin
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

   // Deal with the parity bit memory
   //    Need to modify 3-4 values of the memory every 8MHz clock cycle of input frame processing (so use a faster 48MHz clock)
   //    Need to double register values (like the addresses to modify) from the main state machine since the values corss clock domains
   always @(posedge clock_96MHz, posedge reset) begin
      if (reset) begin // if reset
         parity_bit_address_a       <= 13'h0000;
         parity_bit_address_b       <= 13'h0000;
         parity_bit_mem_in_a        <= 2'b00;
         parity_bit_mem_in_b        <= 2'b00;
         parity_bit_mem_wr_a        <= 1'b0;
         parity_bit_mem_wr_b        <= 1'b0;
         parity_bit_address1_reg    <= 13'h0000;
         parity_bit_address1        <= 13'h0000;
         parity_bit_address2_reg    <= 13'h0000;
         parity_bit_address2        <= 13'h0000;
         parity_bit_address3_reg    <= 13'h0000;
         parity_bit_address3        <= 13'h0000;
         parity_bit_address4_reg    <= 13'h0000;
         parity_bit_address4        <= 13'h0000;
         bit_in_reg1                <= 1'b0;
         bit_in_reg2                <= 1'b0;
         parity_bit_state           <= MAIN_WAIT;
         parity_bit_enable_reg      <= 1'b0;
         parity_bit_enable_reg2     <= 1'b0;
         final_parity_flag_reg      <= 1'b0;
         final_parity_flag_reg2     <= 1'b0;
         final_parity_bit_out       <= 1'b0;
         final_pass_begin           <= 1'b1;
         final_parity_bit_out_valid <= 1'b0;
         final_parity_wait_count    <= 2'b00;
         parity_bit_count2          <= 13'h0000;
         first_parity_bit_count     <= 2'b00;
      end // if reset
      else begin // else not reset
         if (enable) begin // only operate if enabled
            // Double register the signals from the 8MHz clock domain
            parity_bit_address1_reg <= current_addresses[0];
            parity_bit_address1     <= parity_bit_address1_reg;
            parity_bit_address2_reg <= current_addresses[1];
            parity_bit_address2     <= parity_bit_address2_reg;
            parity_bit_address3_reg <= current_addresses[2];
            parity_bit_address3     <= parity_bit_address3_reg;
            parity_bit_address4_reg <= current_addresses[3];
            parity_bit_address4     <= parity_bit_address4_reg;
            bit_in_reg1             <= bit_in_reg;
            bit_in_reg2             <= bit_in_reg1;
            parity_bit_enable_reg   <= parity_bit_enable;
            parity_bit_enable_reg2  <= parity_bit_enable_reg;
            final_parity_flag_reg   <= final_parity_flag;
            final_parity_flag_reg2  <= final_parity_flag_reg;

            // By default:
            parity_bit_address_a       <= parity_bit_address_a;
            parity_bit_address_b       <= parity_bit_address_b;
            parity_bit_mem_in_a        <= 2'b00;
            parity_bit_mem_in_b        <= 2'b00;
            parity_bit_mem_wr_a        <= 1'b0;
            parity_bit_mem_wr_b        <= 1'b0;
            final_parity_bit_out       <= final_parity_bit_out;
            final_pass_begin           <= final_pass_begin;
            final_parity_bit_out_valid <= final_parity_bit_out_valid;
            final_parity_wait_count    <= final_parity_wait_count;
            parity_bit_count2          <= parity_bit_count2;
            first_parity_bit_count     <= first_parity_bit_count;

            // State machine cases
            case (parity_bit_state)
               MAIN_WAIT: begin
                  if (parity_bit_enable_reg2) begin
                     parity_bit_state <= FIRST_SETUP;
                  end
                  else if (final_parity_flag_reg2) begin
                     parity_bit_state     <= FINAL_WAIT;
                     parity_bit_address_a <= 13'h0000;
                  end
                  else begin
                     parity_bit_state <= MAIN_WAIT;
                  end

                  final_parity_bit_out_valid <= 1'b0;
                  final_pass_begin           <= 1'b1;
               end // WAIT state
               FIRST_SETUP: begin
                  parity_bit_address_a <= parity_bit_address1;
                  parity_bit_address_b <= parity_bit_address2;
                  parity_bit_state     <= FIRST_READ_AND_WRITE;
               end // FIRST_SETUP state
               FIRST_READ_AND_WRITE: begin
                  parity_bit_address_a <= parity_bit_address_a;
                  parity_bit_address_b <= parity_bit_address_b;

                  // Check upper bit of memory to make the parity bit value is valid
                  if (parity_bit_mem_out_a[1]) begin // not valid
                     parity_bit_mem_in_a <= {1'b0,bit_in_reg2}; // 0^bit_in
                  end
                  else begin // valid
                     parity_bit_mem_in_a <= {1'b0,parity_bit_mem_out_a[0] ^ bit_in_reg2};
                  end
                  if (parity_bit_mem_out_b[1]) begin // not valid
                     parity_bit_mem_in_b <= {1'b0,bit_in_reg2};
                  end
                  else begin // valid
                     parity_bit_mem_in_b <= {1'b0,parity_bit_mem_out_b[0] ^ bit_in_reg2};
                  end

                  parity_bit_mem_wr_a <= 1'b1;
                  parity_bit_mem_wr_b <= 1'b1;
                  parity_bit_state    <= SECOND_SETUP;
               end // FIRST_READ_AND_WRITE
               SECOND_SETUP: begin
                  parity_bit_address_a <= parity_bit_address3;
                  parity_bit_address_b <= parity_bit_address4;
                  parity_bit_state     <= SECOND_READ_AND_WRITE;
               end // SECOND_SETUP state
               SECOND_READ_AND_WRITE: begin
                  parity_bit_address_a <= parity_bit_address_a;
                  parity_bit_address_b <= parity_bit_address_b;

                  // Check upper bit of memory to make the parity bit value is valid
                  if (parity_bit_mem_out_a[1]) begin // not valid
                     parity_bit_mem_in_a <= {1'b0,bit_in_reg2}; // 0^bit_in
                  end
                  else begin // valid
                     parity_bit_mem_in_a <= {1'b0,parity_bit_mem_out_a[0] ^ bit_in_reg2};
                  end
                  if (parity_bit_mem_out_b[1]) begin // not valid
                     parity_bit_mem_in_b <= {1'b0,bit_in_reg2};
                  end
                  else begin // valid
                     parity_bit_mem_in_b <= {1'b0,parity_bit_mem_out_b[0] ^ bit_in_reg2};
                  end

                  parity_bit_mem_wr_a <= 1'b1;
                  parity_bit_mem_wr_b <= 1'b1;
                  parity_bit_state    <= PRE_MAIN_WAIT;
               end // SECOND_READ_AND_WRITE state
               PRE_MAIN_WAIT: begin // Dummy state so the first series of states takes 6 clock cycles
                  parity_bit_state <= MAIN_WAIT;
               end // PRE_MAIN_WAIT state
               FINAL_WAIT: begin
                  parity_bit_count2 <= parity_bit_count2 + 13'h0001; // increment counter

                  if (parity_bit_count2 == (ldpc_bits)) begin
                     parity_bit_count2 <= 13'h0000; // reset counter
                     parity_bit_state  <= MAIN_WAIT;
                  end
                  else if (final_pass_begin) begin
                     parity_bit_state <= FINAL_FIRST_BIT_OUT;
                     final_pass_begin <= 1'b0;
                  end
                  else begin
                     parity_bit_state <= FINAL_SETUP;
                  end
               end // FINAL_WAIT state
               FINAL_SETUP: begin
                  parity_bit_address_a       <= parity_bit_address1; // previous parity bit
                  parity_bit_address_b       <= parity_bit_address2; // current parity bit
                  parity_bit_state           <= FINAL_READ_AND_WRITE;
               end // FINAL_SETUP state
               FINAL_READ_AND_WRITE: begin
                  parity_bit_address_a       <= parity_bit_address_a;
                  parity_bit_address_b       <= parity_bit_address_b;
                  final_parity_bit_out       <= parity_bit_mem_out_a[0] ^ parity_bit_mem_out_b[0]; // Pi=Pi-1^Pi
                  final_parity_bit_out_valid <= 1'b1;
                  parity_bit_mem_in_b        <= {1'b1,parity_bit_mem_out_a[0] ^ parity_bit_mem_out_b[0]}; // Pi=Pi-1^Pi
                  parity_bit_mem_wr_b        <= 1'b1;
                  parity_bit_state           <= PRE_FINAL_WAIT;
               end // FINAL_READ_AND_WRITE state
               PRE_FINAL_WAIT: begin // need to be in this state for 3 cycles so this second series of states takes 6 clock cycles
                  final_parity_wait_count <= final_parity_wait_count + 2'b01; // increment counter

                  if (final_parity_wait_count == 2'b10) begin // if been here 3 clock cycles
                     final_parity_wait_count <= 2'b00;
                     parity_bit_state        <= FINAL_WAIT;
                  end
                  else begin
                     parity_bit_state <= PRE_FINAL_WAIT;
                  end
               end // PRE_FINAL_WAIT state
               FINAL_FIRST_BIT_OUT: begin
                  final_parity_bit_out       <= parity_bit_mem_out_a[0];
                  parity_bit_mem_in_a        <= {1'b1,parity_bit_mem_out_a[0]};
                  parity_bit_mem_wr_a        <= 1'b1;
                  final_parity_bit_out_valid <= 1'b1;
                  parity_bit_state           <= FINAL_FIRST_BIT_WAIT;
               end // FINAL_FIRST_BIT_OUT state
               FINAL_FIRST_BIT_WAIT: begin
                  first_parity_bit_count <= first_parity_bit_count + 2'b01; // increment counter

                  if (first_parity_bit_count == 2'b10) begin // if been here 3 clock cycles
                     first_parity_bit_count <= 2'b00;
                     parity_bit_state       <= FINAL_WAIT;
                  end
                  else begin
                     parity_bit_state <= FINAL_FIRST_BIT_WAIT;
                  end
               end // FINAL_FIRST_BIT_WAIT state
               default: begin
                  // shouldn't reach this statemt
               end
            endcase // parity_bit_state
         end // if enabled
      end // else not reset
   end // parity bit memory always

   // Main Functionality
   always @(posedge clock_16MHz, posedge reset) begin
      if (reset) begin // if reset
         state                <= WAIT_TO_READ;
         bit_count            <= 16'h0000;
         parity_bit_count     <= 13'h0000;
         bit_out              <= 1'b0;
         valid_out            <= 1'b0;
         fifo_rd              <= 1'b0;
         current_addresses[0] = 13'h0000;
         current_addresses[1] = 13'h0000;
         current_addresses[2] = 13'h0000;
         current_addresses[3] = 13'h0000;
         group_count          <= 8'h00;
         group_bit_count      <= 9'h000;
         parity_mem1_address  <= 8'h00;
         parity_mem2_address  <= 8'h00;
         parity_mem3_address  <= 8'h00;
         parity_mem4_address  <= 8'h00;
         bit_in_reg           <= 1'b0;
         parity_bit_enable    <= 1'b0;
         final_parity_flag    <= 1'b0;
         add_parity_bit_wait  <= 1'b0;
      end // if reset
      else begin // else not reset
         if (enable) begin // Only operate if enabled
            case (state)
               WAIT_TO_READ: begin
                  bit_out              <= 1'b0;
                  valid_out            <= 1'b0;
                  bit_count            <= bit_count;
                  parity_bit_count     <= parity_bit_count;
                  current_addresses[0] = current_addresses[0];
                  current_addresses[1] = current_addresses[1];
                  current_addresses[2] = current_addresses[2];
                  current_addresses[3] = current_addresses[3];
                  group_count          <= group_count;
                  group_bit_count      <= group_bit_count;
                  parity_mem1_address  <= parity_mem1_address;
                  parity_mem2_address  <= parity_mem2_address;
                  parity_mem3_address  <= parity_mem3_address;
                  parity_mem4_address  <= parity_mem4_address;
                  bit_in_reg           <= 1'b0;
                  parity_bit_enable    <= 1'b0;
                  final_parity_flag    <= 1'b0;
                  add_parity_bit_wait  <= 1'b0;

                  // If FIFO isn't empty:
                  //    Set up FIFO read
                  //    Change state to process the input data
                  if (!fifo_empty) begin
                     fifo_rd <= 1'b1;
                     state   <= PROCESS_FRAME;
                  end
                  else begin
                     fifo_rd <= 1'b0;
                     state   <= WAIT_TO_READ;
                  end
               end // WAIT_TO_READ state
               PROCESS_FRAME: begin
                  parity_bit_count    <= 13'h0000; // not used in this state
                  bit_count           <= bit_count + 16'h0001; // increment counter
                  group_bit_count     <= group_bit_count + 9'h001; // increment counter
                  bit_out             <= fifo_out;
                  valid_out           <= 1'b1;
                  group_count         <= group_count; // keep the same by default
                  parity_mem1_address <= parity_mem1_address;
                  parity_mem2_address <= parity_mem2_address;
                  parity_mem3_address <= parity_mem3_address;
                  parity_mem4_address <= parity_mem4_address;
                  add_parity_bit_wait <= 1'b0;

                  // Use base parity bit addresses if first bit of group
                  if (group_bit_count == 0) begin
                     // Get the addresses of the parity bits to be modified
                     current_addresses[0] = parity_mem1_out;
                     current_addresses[1] = parity_mem2_out;
                     current_addresses[2] = parity_mem3_out;

                     // First 18 groups (group=360 bits) of input bits affect 4 parity bits, while later ones just affect 3
                     if (group_count<18) begin
                        current_addresses[3] = parity_mem4_out;
                     end
                     else begin
                        current_addresses[3] = 13'h1950; // 6480 (address not in the relevant portion of the parity bit memory)
                     end
                  end // if group_bit_count == 0
                  else begin // if input bit isn't the first in a group (group=360 bits), need to calculate the parity bit addresses to be modified
                     // Calculate parity bit addresses to be modified
                     current_addresses[0] = current_addresses[0] + q_val;
                     current_addresses[1] = current_addresses[1] + q_val;
                     current_addresses[2] = current_addresses[2] + q_val;

                     // Make sure the addresses aren't larger than 6480
                     if (current_addresses[0] > ldpc_bits-1) begin
                        current_addresses[0] = current_addresses[0] - ldpc_bits;
                     end
                     if (current_addresses[1] > ldpc_bits-1) begin
                        current_addresses[1] = current_addresses[1] - ldpc_bits;
                     end
                     if (current_addresses[2] > ldpc_bits-1) begin
                        current_addresses[2] = current_addresses[2] - ldpc_bits;
                     end

                     // First 18 groups (group=360 bits) of input bits affect 4 parity bits, while later ones just affect 3
                     if (group_count<18) begin
                        current_addresses[3] = current_addresses[3] + q_val;
                        if (current_addresses[3] > ldpc_bits-1) begin
                           current_addresses[3] = current_addresses[3] - ldpc_bits;
                        end
                     end
                     else begin
                        current_addresses[3] = 13'h1950; // 6480 (address not iin the relevant portion of the parity bit memory)
                     end
                  end // else group_bit_count != 0

                  bit_in_reg        <= fifo_out;
                  parity_bit_enable <= 1'b1;
                  final_parity_flag <= 1'b0;

                  // Check if reached end of group of 360 input bits
                  //    Want to increment group counter early so that memory output for base parity addresses for that group is ready
                  if (group_bit_count == 358) begin
                     parity_mem1_address <= parity_mem1_address + 8'h01;
                     parity_mem2_address <= parity_mem2_address + 8'h01;
                     parity_mem3_address <= parity_mem3_address + 8'h01;
                     parity_mem4_address <= parity_mem4_address + 8'h01;
                  end
                  else if (group_bit_count == 359) begin
                     group_count     <= group_count + 8'h01; // increment group counter
                     group_bit_count <= 9'h000; // clear/reset group bit counter
                  end

                  // Check if done processing input bits for a frame
                  if (bit_count == (kldpc-1)) begin
                     state            <= PARITY_WAIT;
                     parity_bit_count <= 13'h0000;
                     bit_count        <= 16'h0000;
                     fifo_rd          <= 1'b0; // Stop reading from the FIFO
                  end
                  else begin // continue processing input data
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
               ADD_PARITY_BITS: begin
                  bit_count            <= 16'h0000; // not used in this state
                  fifo_rd              <= 1'b0;
                  current_addresses[2] = 13'h0000;
                  current_addresses[3] = 13'h0000;
                  parity_mem1_address  <= 8'h00;
                  parity_mem2_address  <= 8'h00;
                  parity_mem3_address  <= 8'h00;
                  parity_mem4_address  <= 8'h00;
                  group_count          <= 8'h00;
                  group_bit_count      <= 9'h000;
                  state                <= ADD_PARITY_BITS; // Stay in this state by default
                  bit_in_reg           <= 1'b0;
                  parity_bit_enable    <= 1'b0;
                  final_parity_flag    <= 1'b1;
                  current_addresses[0] = parity_bit_count;
                  current_addresses[1] = parity_bit_count + 13'h0001;

                  if (final_parity_bit_out_valid) begin
                     bit_out          <= final_parity_bit_out;
                     valid_out        <= 1'b1;
                     parity_bit_count <= parity_bit_count + 13'h0001; // increment counter

                     if (parity_bit_count == (ldpc_bits-1)) begin // check if done outputting parity bits
                        state            <= WAIT_TO_READ; // Get ready to start processing the next frame
                        parity_bit_count <= 13'h0000;
                        final_parity_flag <= 1'b0; // added this*******************************************************************
                     end
                  end
               end // ADD_PARITY_BITS state
               PARITY_WAIT: begin
                  bit_out              <= 1'b0;
                  valid_out            <= 1'b0;
                  bit_count            <= bit_count;
                  parity_bit_count     <= parity_bit_count;
                  current_addresses[0] = current_addresses[0];
                  current_addresses[1] = current_addresses[1];
                  current_addresses[2] = current_addresses[2];
                  current_addresses[3] = current_addresses[3];
                  group_count          <= group_count;
                  group_bit_count      <= group_bit_count;
                  parity_mem1_address  <= parity_mem1_address;
                  parity_mem2_address  <= parity_mem2_address;
                  parity_mem3_address  <= parity_mem3_address;
                  parity_mem4_address  <= parity_mem4_address;
                  bit_in_reg           <= 1'b0;
                  parity_bit_enable    <= 1'b0;
                  final_parity_flag    <= 1'b0;
                  fifo_rd              <= 1'b0;
                  add_parity_bit_wait  <= add_parity_bit_wait + 1'b1;

                  if (add_parity_bit_wait) begin
                     state <= ADD_PARITY_BITS;
                  end
                  else begin
                     state <= PARITY_WAIT;
                  end
               end // PARITY_WAIT
               default: begin
                  // Shouldn't get here
               end
            endcase // state
         end // if enable
      end // else not reset
   end // main functionality always

endmodule // dvbs2_ldpcencoder
