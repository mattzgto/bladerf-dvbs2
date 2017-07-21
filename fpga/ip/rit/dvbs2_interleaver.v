// Re-arranges input FECFRAME

module dvbs2_interleaver (clock, reset, enable, bit_in, valid_in, bit_out, valid_out);
   // Inputs and Outputs
   input  clock;
   input  reset;
   input  enable;
   input  bit_in;
   input  valid_in;
   output bit_out;
   output valid_out;

   // Registers for outputs
   reg valid_out; // previous valid_out_reg value

   // Parameters
   parameter NLDPC = 64800; // Number of bits in FECFRAME
   parameter NMOD = 4; // Number of columns in interleaver
   parameter ROWS = NLDPC/NMOD; // Number of rows in interleaver

   // Internal signals
   reg mem_num; // 0=write to mem1 and read from mem2, 1=write to mem2 and read from mem1
   reg mem_num_reg; // Register before mem_num

   // Internal signals for writing to memory
   reg [15:0] write_address; // Address for the memory that is being written to
   reg [15:0] write_bit_count; // Counter to keep track of progress through the FECFRAME that is being written to memory
   wire       mem1_wren; // Write enable to memory 1
   wire       mem2_wren; // Write enable to memory 2
   reg        mem_wren_reg; // Register before mem_wren
   reg        mem_in_reg; // Input to memory being written to
   reg        first_write; // Flag for first write ever

   // Internal signals for reading from memory
   reg [15:0] read_address; // Address for the memory that is being read from
   reg [15:0] read_bit_count; // Counter to keep track of progress through the FECFRAME that is being read from memory
   reg [1:0]  read_column_count; // Counter to keep track of where in the "matrix columns" of the interleaver to read from
   reg [13:0] read_row_count; // Counter to keep track of where in the "matrix columns" of the interleaver to read from. Need to count up to ROWS
   reg        valid_out_reg2; // Register before valid_out
   reg        valid_out_reg1; // Register before valid_out_reg2
   reg        read_valid; // Flag to not read after the first time writing to mem #1
   reg        out_sel; // Select which memory the output bit is from
   reg        out_sel_reg; // Register before out_sel

   // Other memory signals
   wire [15:0] mem1_address; // Address for the first memory
   wire [15:0] mem2_address; // Address for the second memory
   wire        mem1_out; // Output of first memory
   wire        mem2_out; // Output of second memory

   // Two memories. Switch between which one is writing and which is reading for a frame
   ram_16bits memory_one (
      .address (mem1_address),
      .clock   (clock),
      .data    (mem_in_reg),
      .wren    (mem1_wren),
      .q       (mem1_out)
   );
   ram_16bits memory_two (
      .address (mem2_address),
      .clock   (clock),
      .data    (mem_in_reg),
      .wren    (mem2_wren),
      .q       (mem2_out)
   );

   // Pick which memory the output bit is from
   assign bit_out = out_sel ? mem1_out : mem2_out;

   // Assign memory addresses
   assign mem1_address = mem_num ? read_address : write_address;
   assign mem2_address = mem_num ? write_address : read_address;

   // Pick which memory to write to
   assign mem1_wren = mem_num ? 1'b0 : mem_wren_reg;
   assign mem2_wren = mem_num ? mem_wren_reg : 1'b0;

   // Write to memory functionality
   always @ (posedge clock) begin
      if (reset) begin // if reset
         write_bit_count <= 16'h0000;
         write_address   <= 16'h0000;
         mem_in_reg      <= 1'b0;
         mem_num         <= 1'b0;
         mem_num_reg     <= 1'b0;
         mem_wren_reg    <= 1'b0;
         read_valid      <= 1'b0; // Default to not reading from memory while writing the first frame
         first_write     <= 1'b0;
      end // if reset
      else begin // else not reset
         if (enable) begin // if enabled
            write_address <= write_bit_count;
            mem_num       <= mem_num_reg;
            read_valid    <= read_valid;
            first_write   <= first_write;
            mem_num_reg   <= mem_num_reg;

            if (valid_in) begin
               write_bit_count <= write_bit_count + 16'h0001; // increment counter
               mem_in_reg      <= bit_in;
               mem_wren_reg    <= 1'b1;

               if (first_write) begin
                  read_valid <= 1'b1;
               end

               // Check if reached end of FECFRAME
               if (write_bit_count == (NLDPC-1)) begin
                  write_bit_count <= 16'h0000;
                  mem_num_reg     <= ~mem_num_reg; // Switch which memories are reading and writing
                  first_write     <= 1'b1;
                  read_valid      <= 1'b1;
               end
            end // if valid_in
            else begin
               write_bit_count <= write_bit_count;
               mem_in_reg      <= 1'b0;
               mem_wren_reg    <= 1'b0;
               read_valid      <= 1'b0;
            end
         end // if enabled
      end // else not reset
   end // write always block

   // Read from memory functionality
   always @ (posedge clock) begin
      if (reset) begin // if reset
         read_bit_count    <= 16'h0000;
         read_address      <= 16'h0000;
         read_column_count <= 2'b00;
         read_row_count    <= 14'h0000;
         valid_out         <= 1'b0;
         valid_out_reg2    <= 1'b0;
         valid_out_reg1    <= 1'b0;
         out_sel           <= 1'b0;
         out_sel_reg       <= 1'b0;
      end // if reset
      else begin // else not reset
         if (enable) begin // if enabled
            out_sel        <= out_sel_reg;
            out_sel_reg    <= mem_num;
            valid_out      <= valid_out_reg2;
            valid_out_reg2 <= valid_out_reg1;

            if (read_valid) begin // if actually reading
               valid_out_reg1 <= 1'b1; // Output will be valid in 2 clock cycles
               case (read_column_count)
                  2'b00: read_address <= 0+read_row_count;
                  2'b01: read_address <= 16200+read_row_count;
                  2'b10: read_address <= 32400+read_row_count;
                  2'b11: read_address <= 48600+read_row_count;
               endcase // read_column_count case

               read_bit_count    <= read_bit_count + 16'h0001; // increment counter
               read_column_count <= read_column_count + 2'b01; // increment counter

               if (read_column_count == 2'b11) begin
                  read_row_count <= read_row_count + 14'h0001; // increment counter

                  if (read_row_count == (ROWS-1)) begin // check if reached end of rows
                     read_row_count <= 14'h0000; // Reset counter
                  end
               end
               else begin
                  read_row_count <= read_row_count;
               end

               // Check if reached end of FECFRAME
               if (read_bit_count == (NLDPC-1)) begin
                  read_bit_count <= 16'h0000;
              end
            end // if actually reading
            else begin
               valid_out_reg1 <= 1'b0;
               read_address   <= read_address;
               read_bit_count <= read_bit_count;
            end
         end // if enabled
      end // else not reset
   end // read always block

endmodule // dvbs2_interleaver
