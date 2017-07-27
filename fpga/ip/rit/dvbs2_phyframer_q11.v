// Physical layer framer

// Slice input symbols from bit mapper into XFECFRAMEs
// Insert PLHEADER before XFECFRAME
// Inserts pilot symbols every 16 slots (pilot block has 36 pilot symbols) [405 pilot symbols] to help with receiver synchronization
// IQ modulated symbols are randomized by a scrambler (PLHEADER is not scrambled)
// Output is a scrambled PLFRAME

// The input and output clocks should be synchronized, with the output clock being twice as fast as the input clock

// For IQ samples, a 'lookup' table has been used to reduce the bits/symbol from 12 to 4 (for resource usage purposes)
// 12'h1 = 0.707 = 0x586
// 12'hfff = -0.707 = 0xa7a
// Reconversion is done in the dvbs2_output_sync block

module dvbs2_phyframer_q11 (clock_in, reset, enable, sym_i_in, sym_q_in, valid_in, clock_out, fifo_switch_performed, sym_i_out, sym_q_out, valid_out, error, done_out, fifo_wr_sel);
   // Inputs and Outputs
   input         clock_in; // Input clock. Write input data into FIFO at this rate.
   input         reset; // Synchronous reset
   input         enable; // Input enable
   input  [11:0] sym_i_in; // I portion of input symbol
   input  [11:0] sym_q_in; // Q portion of input symbol
   input         valid_in; // Raised if input symbol is valid (see if data is present)
   input         clock_out; // Output clock. Internally processing done at this rate.
	input			  fifo_switch_performed;
   output [11:0] sym_i_out; // I portion of output symbol
   output [11:0] sym_q_out; // Q portion of output symbol
   output        valid_out; // Raised if output symbol is valid
   output        error; // Raised if there is a FIFO error
	output		  done_out;
	output		  fifo_wr_sel;
	
   // Parameters
   parameter PILOT_SYMBOL_USE      = 1; // Set to 1 to use pilot symbols or 0 to not use pilot symbols // need more logic and different header values if didn't use pilots*&**************************
   parameter PLHEADER_LENGTH       = 90; // Header has a length of 90 symbols
   parameter NLDPC                 = 64800; // Number of bits in FECFRAME
   parameter NMOD                  = 4; // Number of columns in interleaver
   parameter XFECFRAME_LENGTH      = NLDPC/NMOD; // XFECFRAME length (number of symbols coming in for a frame)
   parameter SYMBOLS_PER_SLOT      = 90; // 90 symbols per slot in XFECFRAME or PLFRAME
   parameter SLOTS_PER_XFECFRAME   = XFECFRAME_LENGTH/90; // Number of slots in an XFECFRAME
   parameter SYMBOLS_BEFORE_PILOTS = SYMBOLS_PER_SLOT*16; // A pilot block is inserted every 16 slots if pilots are active (if PILOT_SYMBOL_USE = 1)

   // States
   parameter [2:0] WAIT_TO_START   = 3'b000;
   parameter [2:0] ADD_HEADER      = 3'b001;
   parameter [2:0] PROCESS_SYMBOLS = 3'b010;
   parameter [2:0] OUTPUT_PILOTS   = 3'b011;
   parameter [2:0] WAIT_TO_READ    = 3'b100;
	parameter [2:0] PROCESS_DONE	  = 3'b101;
	
   // Internal Signals
   reg [11:0] dummy_symbol; // Same symbol for I and Q of dummy symbol or pilot symbol
	reg [11:0] dummy_symbol_not;
   reg [2:0]  state; // Keep track of current state
   reg [6:0]  header_count; // Count to keep track of which symbol of the header the module is generating
   reg [13:0] symbol_count; // Count to keep track of input symbols (XFECFRAME symbols) being processed
   reg [11:0] sym_i_out; // Register the I portion of the output symbol
   reg [11:0] sym_q_out; // Register the Q portion of the output symbol
   reg        valid_out; // Register valid_out output
   reg        error; // Register the error output
   wire       clock_not; // Inverted version of output clock to read from the FIFO on negative edge of clock
   reg [1:0]  scramble_bits; // scramble bits calculated from LFSR for scrambling sequence
   reg        zna, znb; // 1 bit calculations from each LFSR to go toward calculating scramble_bits
   reg [5:0]  pilot_symbol_count; // keep track of how many pilot symbols have been created (36 pilot symbols in a pilot block)
   reg [10:0] pilot_count; // keep track of where to insert a pilot block
   reg        start_flag; // Don't start internal processing of headers and frames until the block starts receiving data

   // LFSR Signals
   reg [17:0] lfsr_x; // 18 bit LFSR for x sequence of PL scrambling
   reg [17:0] lfsr_y; // 18 bit LFSR for y sequence of PL scrambling
   reg        lfsr_en; // 1 bit signal to enable LFSR operation for the current clock cycle
   reg        lfsr_rst; // 1 bit signal to re-initialize the LFSR

   // FIFO Signals (need FIFO for both I input symbol and Q input symbol)
   reg  [31:0] i_sym_fifo_in; // Input to I-symbol FIFO
   reg  [31:0] q_sym_fifo_in; // Input to Q-symbol FIFO
   reg         fifo_rd; // Read request signal to FIFOs. Want to read both FIFOs at the same time for input symbols.
   reg         fifo_wr; // Write request signal to FIFOs. Want to write to both FIFOs at the same time for input symbols.
   wire        i_sym_fifo_empty; // Empty signal from I-symbol FIFO
   wire        q_sym_fifo_empty; // Empty signal from Q-symbol FIFO
   wire        i_sym_fifo_full; // Full signal from I-symbol FIFO
   wire        q_sym_fifo_full; // Full signal from Q-symbol FIFO
   wire [31:0] i_sym_fifo_out; // Output from I-symbol FIFO
   wire [31:0] q_sym_fifo_out; // Output from Q-symbol FIFO

   // Create inverted version of output clock
   assign clock_not = ~clock_out;

   reg done_out;
   reg fifo_switch_performed_mff2;
   reg fifo_switch_performed_mff1;
   reg fifo_wr_sel;
	
   // Synchronous FIFOs for input symbols
   //    2^11=2048 words (word = 32 bits) deep
   //    Separate read and write clocks
   //    Data becomes available after 'rdreq' is asserted, acting as a read request
   fifo_32bit_dual_clk_11bit i_sym_in_fifo (
      .data    (i_sym_fifo_in),
      .rdclk   (clock_not),
      .rdreq   (fifo_rd),
      .wrclk   (clock_in),
      .wrreq   (fifo_wr),
      .q       (i_sym_fifo_out),
      .rdempty (i_sym_fifo_empty), // Empty signal from the read side of the FIFO
      .wrfull  (i_sym_fifo_full) // Full signal from the write side of the FIFO
   );
   fifo_32bit_dual_clk_11bit q_sym_in_fifo (
      .data    (q_sym_fifo_in),
      .rdclk   (clock_not),
      .rdreq   (fifo_rd),
      .wrclk   (clock_in),
      .wrreq   (fifo_wr),
      .q       (q_sym_fifo_out),
      .rdempty (q_sym_fifo_empty), // Empty signal from the read side of the FIFO
      .wrfull  (q_sym_fifo_full) // Full signal from the write side of the FIFO
   );

   // LFSR for PL scrambling
   always @(negedge clock_out, posedge reset) begin
      if (reset) begin // if reset
         lfsr_x <= 18'h00001; // initialize x(0) = 1, x(1)=x(2)=...=x(17)=0
         lfsr_y <= 18'h3FFFF; // initialize y(0)=y(1)=...=y(17)=1
      end // if reset
      else begin // else not reset
         if (lfsr_rst) begin // LFSR should be re-initalized for each frame
            lfsr_x <= 18'h00001; // initialize x(0) = 1, x(1)=x(2)=...=x(17)=0
            lfsr_y <= 18'h3FFFF; // initialize y(0)=y(1)=...=y(17)=1
         end // if lfsr_rst
         else begin
            if (lfsr_en) begin // only operate this clock cycle if LFSR is enabled by state machine
               lfsr_x <= {lfsr_x[7]^lfsr_x[0],lfsr_x[17:1]}; // x^7 + 1
               lfsr_y <= {lfsr_y[10]^lfsr_y[7]^lfsr_y[5]^lfsr_y[0],lfsr_y[17:1]}; // y^10 + y^7 + y^5 + 1
            end // if lfsr_en
            else begin // else keep LFSR contents the same
               lfsr_x <= lfsr_x;
               lfsr_y <= lfsr_y;
            end // else not lfsr_en
         end // else not lfsr_rst
      end // else not reset
   end // LFSR for PL scrambling

   // Deal with input data
   //    Add input data (input symbols) to the FIFOs if they are valid (deal with write side of FIFOs)
   //    Should always get I and Q together, so always write to both FIFOs together
   always @(posedge clock_in, posedge reset) begin
      if (reset) begin // if reset
         i_sym_fifo_in <= 32'h00000000;
         q_sym_fifo_in <= 32'h00000000;
         fifo_wr       <= 1'b0;
         error         <= 1'b0;
         start_flag    <= 1'b0;
      end // if reset
      else begin // else not reset
         if (valid_in) begin // only add input symbols to FIFOs if they are valid
            i_sym_fifo_in <= {20'b0, sym_i_in};
            q_sym_fifo_in <= {20'b0, sym_q_in};
            fifo_wr       <= 1'b1;
            start_flag    <= 1'b1;

            if (i_sym_fifo_full || q_sym_fifo_full) begin // error if trying to write when a FIFO is full
               error <= 1'b1;
            end
            else begin
               error <= 1'b0;
            end
         end // if valid
         else begin // else not valid input data
            i_sym_fifo_in <= 32'h00000000;
            q_sym_fifo_in <= 32'h00000000;
            fifo_wr       <= 1'b0;
            error         <= 1'b0;
            start_flag    <= start_flag;
         end // else not valid
      end // else not reset
   end // input data always block

   // Main Functionality
   always @ (posedge clock_out, posedge reset) begin
      if (reset) begin // if reset
         sym_i_out          <= 12'hB;
         sym_q_out          <= 12'hB;
         dummy_symbol       <= 12'h1; //32'h3f3504f3
			dummy_symbol_not	 <= 12'hfff; //32'hbf3504f3
         state              <= WAIT_TO_START;// any cycle that doesn't have valid output should just sent out dummy signal. still have valid_out for TB checking, but always send out symbol*****
         header_count       <= 7'h00;
         symbol_count       <= 14'h0000;
         lfsr_en            <= 1'b0;
         lfsr_rst           <= 1'b0;
         valid_out          <= 1'b0;
         fifo_rd            <= 1'b0;
         scramble_bits      = 2'b00;
         zna                = 1'b0;
         znb                = 1'b0;
         pilot_count        <= 11'h000;
         pilot_symbol_count <= 6'h00;
			
			done_out <= 1'b0;
         fifo_wr_sel <= 1'b0;
         fifo_switch_performed_mff2 <= 1'b0;
         fifo_switch_performed_mff1 <= 1'b0;
      end // if reset
      else begin // else not reset
         dummy_symbol   <= dummy_symbol; // never changes
			fifo_switch_performed_mff2 <= fifo_switch_performed_mff1;
         fifo_switch_performed_mff1 <= fifo_switch_performed;
			
         if (enable) begin // Only operate while enabled
            case (state)
               WAIT_TO_START: begin // Wait until data is received at input to start
                  sym_i_out          <= 12'hB;
                  sym_q_out          <= 12'hB;
                  header_count       <= 7'h00;
                  symbol_count       <= 14'h0000;
                  lfsr_en            <= 1'b0;
                  lfsr_rst           <= 1'b0;
                  valid_out          <= 1'b0;
                  fifo_rd            <= 1'b0;
                  scramble_bits      = 2'b00;
                  zna                = 1'b0;
                  znb                = 1'b0;
                  pilot_count        <= 11'h000;
                  pilot_symbol_count <= 6'h00;
						
                  if (start_flag) begin
                     state <= ADD_HEADER;
                  end
                  else begin
                     state <= WAIT_TO_START;
                  end
               end // WAIT_TO_START state
               ADD_HEADER: begin
                  symbol_count       <= 14'h0000; // Not used in this state
                  header_count       <= header_count + 7'h01; // increment counter
                  lfsr_en            <= 1'b0; // LFSRs just used during symbol processing
                  lfsr_rst           <= 1'b1; // Re-initialize LFSRs for next frame
                  valid_out          <= 1'b1; // Header symbols are valid outputs
                  fifo_rd            <= 1'b0; // Don't read FIFO data in this state
                  scramble_bits      = 2'b00;
                  zna                = 1'b0;
                  znb                = 1'b0;
                  pilot_count        <= 11'h000;
                  pilot_symbol_count <= 6'h00;

						done_out <= 1'b0;
						
                  // look up header value to output
                  case (header_count)
                     0: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3 // these values are all specific for WITH pilots. Need to run C++ pgrm to calculate w/o pilot ones and have if statmeents in each case*********************
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     1: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     2: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     3: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     4: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     5: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     6: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     7: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     8: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     9: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     10: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     11: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     12: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     13: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     14: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     15: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     16: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     17: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     18: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     19: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     20: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     21: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     22: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     23: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     24: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     25: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     26: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     27: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     28: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     29: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     30: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     31: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     32: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     33: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     34: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     35: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     36: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     37: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     38: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     39: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     40: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     41: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     42: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     43: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     44: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     45: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     46: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     47: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     48: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                    49: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                    50: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     51: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     52: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     53: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     54: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     55: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     56: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     57: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     58: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     59: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     60: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     61: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     62: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     63: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     64: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     65: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     66: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     67: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     68: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     69: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     70: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     71: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     72: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     73: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     74: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     75: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     76: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     77: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     78: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     79: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     80: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     81: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     82: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     83: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     84: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     85: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     86: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     87: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'h1; //32'h3f3504f3
                     end
                     88: begin
                        sym_i_out <= 12'hfff; //32'hbf3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     89: begin
                        sym_i_out <= 12'h1; //32'h3f3504f3
                        sym_q_out <= 12'hfff; //32'hbf3504f3
                     end
                     default: begin
                        sym_i_out <= 12'hB;
                        sym_q_out <= 12'hB;
                     end
                  endcase // header_index case

                  // Check if done with PLHEADER
                  if (header_count == (PLHEADER_LENGTH-1)) begin
                     lfsr_rst     <= 1'b0; // Stop reseting LFSR since it will be used in the PROCESS_SYMBOLS state
                     header_count <= 7'h00;
                     
                     // Set up FIFO readif they aren't empty
                     if (i_sym_fifo_empty == 1'b0 && q_sym_fifo_empty == 1'b0) begin
                        fifo_rd <= 1'b1;
                        state   <= PROCESS_SYMBOLS;
                     end
                     else begin
                        state <= WAIT_TO_READ;
                     end
                  end
               end // ADD_HEADER state
               PROCESS_SYMBOLS: begin
                  header_count       <= 7'h00; // Not used in this state
                  lfsr_rst           <= 1'b0; // Not reseting LFSR since in use in this state
                  pilot_symbol_count <= 6'h00; // Not used in this state

                  // Calculate scramble bits based on LFSR
                  zna = lfsr_x[0]^lfsr_y[0];
                  znb = (lfsr_y[15]^lfsr_y[14]^lfsr_y[13]^lfsr_y[12]^lfsr_y[11]^lfsr_y[10]^lfsr_y[9]^lfsr_y[8]^lfsr_y[6]^lfsr_y[5]) ^ (lfsr_x[15]^lfsr_x[6]^lfsr_x[4]); // 0xFF60 and 0x8050 generator polynomials
                  scramble_bits = {znb,1'b0} + {1'b0,zna}; // rn = 2*znb + zna (shift znb left by 1 to multiply by 2)

                  // Decide how to modify (scramble) input symbol based on scrambling sequence term from LFSR
                  case (scramble_bits)
                     2'b00: begin // No change to input symbol
                        sym_i_out <= i_sym_fifo_out[11:0];
                        sym_q_out <= q_sym_fifo_out[11:0];
                     end
                     2'b01: begin // Swap symbols and change the sign of the Q symbol
                        sym_i_out <= (~q_sym_fifo_out[11:0])+1'b1;
                        sym_q_out <= i_sym_fifo_out[11:0];
                     end
                     2'b10: begin // Change the signs of both symbols
                        sym_i_out <= (~i_sym_fifo_out[11:0])+1'b1;
                        sym_q_out <= (~q_sym_fifo_out[11:0])+1'b1;
                     end
                     2'b11: begin // Swap symbols and change the sign of the I symbol
                        sym_i_out <= q_sym_fifo_out[11:0];
                        sym_q_out <= (~i_sym_fifo_out[11:0])+1'b1;
                     end
                  endcase // scramble_bits case

                  valid_out    <= 1'b1; // Sending out a scrambled symbol
                  lfsr_en      <= 1'b1; // Enable LFSR to continue generating the scrambling sequence bits
                  symbol_count <= symbol_count + 14'h0001; // increment counter
                  fifo_rd      <= 1'b0;


                  if (PILOT_SYMBOL_USE) begin // increment symbol counter to keep track of where to insert pilot block if pilots are in use
                     pilot_count <= pilot_count + 11'h001; // increment counter
                  end
                  else begin
                     pilot_count <= 11'h000;
                  end
                  
                  // Check if need to output a pilot block
                  if ((pilot_count == (SYMBOLS_BEFORE_PILOTS-1)) && PILOT_SYMBOL_USE && (symbol_count < (XFECFRAME_LENGTH-SYMBOLS_PER_SLOT))) begin // if it has been 16 slots and pilots are active
                     fifo_rd <= 1'b0;
                     state   <= OUTPUT_PILOTS; // change state to output a pilot block
                  end
                  else begin // continue with normal symbols
                     state <= PROCESS_SYMBOLS; // stay in current state
                     // Set up FIFO read if they aren't empty
                     if (i_sym_fifo_empty == 1'b0 && q_sym_fifo_empty == 1'b0) begin
                        fifo_rd <= 1'b1;
                     end
                     else begin
                        state <= WAIT_TO_READ;
                     end
                  end

                  // Check if done processing symbols
                  if (symbol_count == (XFECFRAME_LENGTH-1)) begin
                     state        <= PROCESS_DONE;
                     symbol_count <= 14'h0000;
                     fifo_rd      <= 1'b0;
                  end
               end // PROOCESS_SYMBOLS state
               OUTPUT_PILOTS: begin
                  header_count       <= 7'h00; // Not used in this state
                  lfsr_rst           <= 1'b0; // Not reseting LFSR since in use in this state
                  pilot_symbol_count <= pilot_symbol_count + 6'h01; // increment counter
                  symbol_count       <= symbol_count;
                  pilot_count        <= 11'h000; // Reset count for where to put the next pilot block

                  // Calculate scramble bits based on LFSR
                  zna = lfsr_x[0]^lfsr_y[0];
                  znb = (lfsr_y[15]^lfsr_y[14]^lfsr_y[13]^lfsr_y[12]^lfsr_y[11]^lfsr_y[10]^lfsr_y[9]^lfsr_y[8]^lfsr_y[6]^lfsr_y[5]) ^ (lfsr_x[15]^lfsr_x[6]^lfsr_x[4]); // 0xFF60 and 0x8050 generator polynomials
                  scramble_bits = {znb,1'b0} + {1'b0,zna}; // rn = 2*znb + zna (shift znb left by 1 to multiply by 2)

                  // Decide how to modify (scramble) pilot symbol based on scrambling sequence term from LFSR
                  case (scramble_bits)
                     2'b00: begin // No change to input symbol
                        sym_i_out <= dummy_symbol;
                        sym_q_out <= dummy_symbol;
                     end
                     2'b01: begin // Swap symbols and change the sign of the Q symbol
                        sym_i_out <= dummy_symbol_not;
                        sym_q_out <= dummy_symbol;
                     end
                     2'b10: begin // Change the signs of both symbols
                        sym_i_out <= dummy_symbol_not;
                        sym_q_out <= dummy_symbol_not;
                     end
                     2'b11: begin // Swap symbols and change the sign of the I symbol
                        sym_i_out <= dummy_symbol;
                        sym_q_out <= dummy_symbol_not;
                     end
                  endcase // scramble_bits case

                  valid_out    <= 1'b1; // Sending out a scrambled pilot symbol
                  lfsr_en      <= 1'b1; // Enable LFSR to continue generating the scrambling sequence bits
                  fifo_rd      <= 1'b0;

                  // Check if done generating pilot symbols
                  if (pilot_symbol_count == (36-1)) begin
                     pilot_symbol_count <= 6'h00;
                     // Set up FIFO read if they aren't empty
                     if (i_sym_fifo_empty == 1'b0 && q_sym_fifo_empty == 1'b0) begin
                        fifo_rd <= 1'b1;
                        state   <= PROCESS_SYMBOLS;
                     end
                     else begin
                        state <= WAIT_TO_READ;
                     end
                  end // if pilot_symbol_count = 36
                  else begin
                     state <= OUTPUT_PILOTS;
                  end
               end // OUTPUT_PILOTS state
               WAIT_TO_READ: begin // Come here if waiting until able to read from FIFO before going to PROCESS_SYMBOLS
                  sym_i_out          <= 12'hB;
                  sym_q_out          <= 12'hB;
                  header_count       <= 7'h00;
                  symbol_count       <= symbol_count;
                  lfsr_en            <= 1'b0;
                  lfsr_rst           <= 1'b0;
                  valid_out          <= 1'b0;
                  scramble_bits      = 2'b00;
                  zna                = 1'b0;
                  znb                = 1'b0;
                  pilot_count        <= pilot_count;
                  pilot_symbol_count <= 6'h00;
                  
                  // Set up FIFO read if they aren't empty
                  if (i_sym_fifo_empty == 1'b0 && q_sym_fifo_empty == 1'b0) begin
                     fifo_rd <= 1'b1;
                     state   <= PROCESS_SYMBOLS;
                  end
                  else begin
                     fifo_rd <= 1'b0;
                     state   <= WAIT_TO_READ;
                  end
               end // WAIT_TO_READ state
					PROCESS_DONE: begin
						done_out 		    <= 1'b1;
						valid_out 	       <= 1'b0;
						lfsr_en            <= 1'b0;
						lfsr_rst           <= 1'b0;
						valid_out          <= 1'b0;

						// The output portion of the code acknowledged the fifo switch
						if (fifo_switch_performed_mff2 == 1'b1) begin
							state <= ADD_HEADER;
							fifo_wr_sel <= ~fifo_wr_sel;
						end
						else begin
							state <= PROCESS_DONE;
						end
					end
               default: begin
                  // shouldn't get here
               end
            endcase // state
         end // if enabled
      end // else not reset
   end // main functionality

endmodule // dvbs2_phyframer
