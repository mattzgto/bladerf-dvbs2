-- Copyright (c) 2013 Nuand LLC
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

library ieee ;
    use ieee.std_logic_1164.all ;
    use ieee.numeric_std.all ;
    use ieee.math_real.all ;
    use ieee.math_complex.all ;

architecture hosted_bladerf of bladerf is

    attribute noprune   : boolean ;
    attribute keep      : boolean ;

    component nios_system is
      port (
        clk_clk                         :   in  std_logic := 'X'; -- clk
        reset_reset_n                   :   in  std_logic := 'X'; -- reset_n
        dac_MISO                        :   in  std_logic := 'X'; -- MISO
        dac_MOSI                        :   out std_logic;        -- MOSI
        dac_SCLK                        :   out std_logic;        -- SCLK
        dac_SS_n                        :   out std_logic_vector(1 downto 0);        -- SS_n
        spi_MISO                        :   in  std_logic := 'X'; -- MISO
        spi_MOSI                        :   out std_logic;        -- MOSI
        spi_SCLK                        :   out std_logic;        -- SCLK
        spi_SS_n                        :   out std_logic;        -- SS_n
        oc_i2c_scl_pad_o                :   out std_logic;
        oc_i2c_scl_padoen_o             :   out std_logic;
        oc_i2c_sda_pad_i                :   in  std_logic;
        oc_i2c_sda_pad_o                :   out std_logic;
        oc_i2c_sda_padoen_o             :   out std_logic;
        oc_i2c_arst_i                   :   in  std_logic;
        oc_i2c_scl_pad_i                :   in  std_logic;
        gpio_export                     :   out std_logic_vector(31 downto 0);
        xb_gpio_in_port                 :   in  std_logic_vector(31 downto 0) := (others => 'X');
        xb_gpio_out_port                :   out std_logic_vector(31 downto 0);
        xb_gpio_dir_export              :   out std_logic_vector(31 downto 0);
        command_serial_in               :   in  std_logic ;
        command_serial_out              :   out std_logic ;
        correction_rx_phase_gain_export :   out std_logic_vector(31 downto 0);
        correction_tx_phase_gain_export :   out std_logic_vector(31 downto 0);
        rx_tamer_ts_sync_in             :   in  std_logic;
        rx_tamer_ts_sync_out            :   out std_logic ;
        rx_tamer_ts_pps                 :   in  std_logic ;
        rx_tamer_ts_clock               :   in  std_logic ;
        rx_tamer_ts_reset               :   in  std_logic;
        rx_tamer_ts_time                :   out std_logic_vector(63 downto 0) ;
        tx_tamer_ts_sync_in             :   in  std_logic;
        tx_tamer_ts_sync_out            :   out std_logic ;
        tx_tamer_ts_pps                 :   in  std_logic ;
        tx_tamer_ts_clock               :   in  std_logic ;
        tx_tamer_ts_reset               :   in  std_logic;
        tx_tamer_ts_time                :   out std_logic_vector(63 downto 0);
        vctcxo_tamer_tune_ref           :   in  std_logic;
        vctcxo_tamer_vctcxo_clock       :   in  std_logic;
        tx_trigger_ctl_in_port          :   in std_logic_vector(7 downto 0);
        tx_trigger_ctl_out_port         :   out std_logic_vector(7 downto 0);
        rx_trigger_ctl_in_port          :   in std_logic_vector(7 downto 0);
        rx_trigger_ctl_out_port         :   out std_logic_vector(7 downto 0)
      );
    end component;

    alias sys_rst   is fx3_ctl(7) ;
    alias tx_clock  is c4_tx_clock ;
    alias rx_clock  is lms_rx_clock_out ;

	 -- DVB Transmitter signals
    signal dvb_data_in         : std_logic ;
	 signal dvb_valid_in        : std_logic ;
	 signal dvb_96MHz_clock     : std_logic ;
	 signal dvb_16MHz_clock      : std_logic ;
	 signal dvb_4MHz_clock      : std_logic ;
	 signal dvb_error	          : std_logic ;
	 signal dvb_enable		    : std_logic ;
	 signal dvb_full				 : std_logic ;
	 signal dvb_empty				 : std_logic ;
	 
    -- Can be set from libbladeRF using bladerf_set_rx_mux()
    type rx_mux_mode_t is (RX_MUX_NORMAL, RX_MUX_12BIT_COUNTER, RX_MUX_32BIT_COUNTER, RX_MUX_ENTROPY, RX_MUX_DIGITAL_LOOPBACK) ;

    signal rx_mux_sel       : unsigned(2 downto 0) ;
    signal rx_mux_mode      : rx_mux_mode_t ;

    signal \80MHz\          : std_logic ;
    signal \80MHz locked\   : std_logic ;

    signal nios_gpio        : std_logic_vector(31 downto 0) ;
    signal nios_xb_gpio_in  : std_logic_vector(31 downto 0) ;
    signal nios_xb_gpio_out : std_logic_vector(31 downto 0) ;
    signal nios_xb_gpio_dir : std_logic_vector(31 downto 0) ;
    signal xb_gpio_dir      : std_logic_vector(31 downto 0) ;

    signal correction_rx_phase_gain :  std_logic_vector(31 downto 0);
    signal correction_tx_phase_gain :  std_logic_vector(31 downto 0);

    signal i2c_scl_in       : std_logic ;
    signal i2c_scl_out      : std_logic ;
    signal i2c_scl_oen      : std_logic ;

    signal i2c_sda_in       : std_logic ;
    signal i2c_sda_out      : std_logic ;
    signal i2c_sda_oen      : std_logic ;

    type fifo_t is record
        aclr    :   std_logic ;

        wclock  :   std_logic ;
        wdata   :   std_logic_vector(31 downto 0) ;
        wreq    :   std_logic ;
        wempty  :   std_logic ;
        wfull   :   std_logic ;
        wused   :   std_logic_vector(11 downto 0) ;

        rclock  :   std_logic ;
        rdata   :   std_logic_vector(31 downto 0) ;
        rreq    :   std_logic ;
        rempty  :   std_logic ;
        rfull   :   std_logic ;
        rused   :   std_logic_vector(11 downto 0) ;
    end record ;

    signal rx_sample_fifo   : fifo_t ;
    signal tx_sample_fifo   : fifo_t ;
    signal rx_loopback_fifo : fifo_t ;

    type meta_fifo_tx_t is record
        aclr    :   std_logic ;

        wclock  :   std_logic ;
        wdata   :   std_logic_vector(31 downto 0) ;
        wreq    :   std_logic ;
        wempty  :   std_logic ;
        wfull   :   std_logic ;
        wused   :   std_logic_vector(4 downto 0) ;

        rclock  :   std_logic ;
        rdata   :   std_logic_vector(127 downto 0) ;
        rreq    :   std_logic ;
        rempty  :   std_logic ;
        rfull   :   std_logic ;
        rused   :   std_logic_vector(2 downto 0) ;
    end record ;

    signal tx_meta_fifo     : meta_fifo_tx_t ;

    type meta_fifo_rx_t is record
        aclr    :   std_logic ;

        wclock  :   std_logic ;
        wdata   :   std_logic_vector(127 downto 0) ;
        wreq    :   std_logic ;
        wempty  :   std_logic ;
        wfull   :   std_logic ;
        wused   :   std_logic_vector(4 downto 0) ;

        rclock  :   std_logic ;
        rdata   :   std_logic_vector(31 downto 0) ;
        rreq    :   std_logic ;
        rempty  :   std_logic ;
        rfull   :   std_logic ;
        rused   :   std_logic_vector(6 downto 0) ;
    end record ;

    signal rx_meta_fifo     : meta_fifo_rx_t ;

    signal sys_rst_sync     : std_logic ;
    signal sys_rst_80M      : std_logic ;

    signal usb_speed        : std_logic ;
    signal usb_speed_rx     : std_logic ;
    signal usb_speed_tx     : std_logic ;

    signal tx_reset         : std_logic ;
	 signal dvb_reset         : std_logic ;
    signal rx_reset         : std_logic ;

    signal pclk_tx_enable   :   std_logic ;
    signal pclk_rx_enable   :   std_logic ;

    signal tx_enable        : std_logic ;
    signal rx_enable        : std_logic ;

    signal meta_en_tx       : std_logic ;
    signal meta_en_rx       : std_logic ;
    signal meta_en_fx3      : std_logic ;
    signal tx_timestamp     : unsigned(63 downto 0) ;
    signal rx_timestamp     : unsigned(63 downto 0) ;
    signal timestamp_sync   : std_logic ;

    signal rx_sample_i      : signed(15 downto 0) ;
    signal rx_sample_q      : signed(15 downto 0) ;
    signal rx_sample_valid  : std_logic ;

    signal rx_gen_mode      : std_logic ;
    signal rx_gen_i         : signed(15 downto 0) ;
    signal rx_gen_q         : signed(15 downto 0) ;
    signal rx_gen_valid     : std_logic ;

    signal rx_entropy_i     : signed(15 downto 0) := (others =>'0') ;
    signal rx_entropy_q     : signed(15 downto 0) := (others =>'0') ;
    signal rx_entropy_valid : std_logic := '0' ;

    signal rx_loopback_i     : signed(15 downto 0) := (others =>'0') ;
    signal rx_loopback_q     : signed(15 downto 0) := (others =>'0') ;
    signal rx_loopback_valid : std_logic := '0' ;
    signal rx_loopback_enabled : std_logic := '0' ;
    signal tx_loopback_enabled : std_logic := '0' ;

    signal tx_sample_raw_i : signed(15 downto 0);
    signal tx_sample_raw_q : signed(15 downto 0);
    signal tx_sample_raw_valid : std_logic;

    signal tx_sample_i      : signed(15 downto 0) ;
    signal tx_sample_q      : signed(15 downto 0) ;
    signal tx_sample_valid  : std_logic ;

    signal fx3_gpif_in      : std_logic_vector(31 downto 0) ;
    signal fx3_gpif_out     : std_logic_vector(31 downto 0) ;
    signal fx3_gpif_oe      : std_logic ;

    signal fx3_ctl_in       : std_logic_vector(12 downto 0) ;
    signal fx3_ctl_out      : std_logic_vector(12 downto 0) ;
    signal fx3_ctl_oe       : std_logic_vector(12 downto 0) ;

    signal tx_underflow_led     :   std_logic ;
    signal tx_underflow_count   :   unsigned(63 downto 0) ;

    signal rx_overflow_led      :   std_logic ;
    signal rx_overflow_count    :   unsigned(63 downto 0) ;

    signal lms_rx_data_reg      :   signed(11 downto 0) ;
    signal lms_rx_iq_select_reg :   std_logic ;

    signal rx_mux_i             :   signed(15 downto 0) ;
    signal rx_mux_q             :   signed(15 downto 0) ;
    signal rx_mux_valid         :   std_logic ;

    signal rx_sample_corrected_i : signed(15 downto 0);
    signal rx_sample_corrected_q : signed(15 downto 0);
    signal rx_sample_corrected_valid : std_logic;

    signal led2_blink : std_logic;

    signal nios_sdo : std_logic;
    signal nios_sdio : std_logic;
    signal nios_sclk : std_logic;
    signal nios_ss_n : std_logic_vector(1 downto 0);

    signal xb_mode  : std_logic_vector(1 downto 0);

    signal correction_valid : std_logic;

    signal correction_tx_phase :  signed(15 downto 0);--to_signed(integer(round(real(2**Q_SCALE) * PHASE_OFFSET)),DC_WIDTH);
    signal correction_tx_gain  :  signed(15 downto 0);--to_signed(integer(round(real(2**Q_SCALE) * DC_OFFSET_REAL)),DC_WIDTH);
    signal correction_rx_phase :  signed(15 downto 0);--to_signed(integer(round(real(2**Q_SCALE) * PHASE_OFFSET)),DC_WIDTH);
    signal correction_rx_gain  :  signed(15 downto 0);--to_signed(integer(round(real(2**Q_SCALE) * DC_OFFSET_REAL)),DC_WIDTH);

    signal command_serial_in    :   std_logic ;
    signal command_serial_out   :   std_logic ;

    constant FPGA_DC_CORRECTION :  signed(15 downto 0) := to_signed(integer(0), 16);

    signal fx3_pclk_pll     :   std_logic ;
    signal fx3_pll_locked   :   std_logic ;

    signal timestamp_req    :   std_logic ;
    signal timestamp_ack    :   std_logic ;
    signal fx3_timestamp    :   unsigned(63 downto 0) ;

    signal rx_ts_reset      :   std_logic ;
    signal tx_ts_reset      :   std_logic ;

    -- Trigger Control interfaces
    signal rx_trigger_ctl       : std_logic_vector(7 downto 0);
    signal tx_trigger_ctl       : std_logic_vector(7 downto 0);

    -- Trigger Control breakdown
    alias rx_trigger_arm        : std_logic is rx_trigger_ctl(0);
    alias rx_trigger_fire       : std_logic is rx_trigger_ctl(1);
    alias rx_trigger_master     : std_logic is rx_trigger_ctl(2);
    signal rx_trigger_line       : std_logic;

    alias tx_trigger_arm        : std_logic is tx_trigger_ctl(0);
    alias tx_trigger_fire       : std_logic is tx_trigger_ctl(1);
    alias tx_trigger_master     : std_logic is tx_trigger_ctl(2);
    signal tx_trigger_line       : std_logic;

    signal tx_trigger_arm_sync  :   std_logic ;

    -- Trigger Control readback interfaces
    signal rx_trigger_ctl_rb    : std_logic_vector(7 downto 0);
    signal tx_trigger_ctl_rb    : std_logic_vector(7 downto 0);

    -- Trigger Control readback breakdown
    alias rx_trigger_arm_rb         : std_logic is rx_trigger_ctl_rb(0);
    alias rx_trigger_fire_rb        : std_logic is rx_trigger_ctl_rb(1);
    alias rx_trigger_master_rb      : std_logic is rx_trigger_ctl_rb(2);
    alias rx_trigger_line_rb        : std_logic is rx_trigger_ctl_rb(3);

    alias tx_trigger_arm_rb         : std_logic is tx_trigger_ctl_rb(0);
    alias tx_trigger_fire_rb        : std_logic is tx_trigger_ctl_rb(1);
    alias tx_trigger_master_rb      : std_logic is tx_trigger_ctl_rb(2);
    alias tx_trigger_line_rb        : std_logic is tx_trigger_ctl_rb(3);

    -- Trigger Outputs
    signal lms_rx_enable_sig                        : std_logic;
    signal lms_rx_enable_qualified                  : std_logic;
    signal tx_sample_fifo_rempty_untriggered        : std_logic;

	 signal walking_i_sample								 : std_logic;
	 signal save_sample										 : std_logic_vector(15 downto 0);
	 
	 -- Component declaration for 16APSK DVB-S2 Transmitter
    COMPONENT dvbs2_transmitter
      PORT (
        clock_96MHz : IN STD_LOGIC;
        clock_16MHz : IN STD_LOGIC;
        clock_4MHz : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        bit_in : IN STD_LOGIC;
        valid_in : IN STD_LOGIC;
		  output_clock: IN STD_LOGIC;
		  output_reset: IN STD_LOGIC;
        sym_i_out : OUT signed (15 DOWNTO 0);
        sym_q_out : OUT signed (15 DOWNTO 0);
        valid_out : OUT STD_LOGIC;
		  error : OUT STD_LOGIC
     );
    END COMPONENT;

	 -- Component declaration for USB FIFO Reader
	 -- with TS null packet insertion
    COMPONENT dvb_fifo_reader
     PORT (
        clock_data_in : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        in_reset : IN STD_LOGIC;
        empty_in : IN STD_LOGIC;
        data_in : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
        clock_data_out : IN STD_LOGIC;
		  out_reset : IN STD_LOGIC;
        valid_out : OUT STD_LOGIC;
        data_out : OUT STD_LOGIC;
        read_in_ret : OUT STD_LOGIC
     );
    END COMPONENT;
	 
begin

    correction_tx_phase <= signed(correction_tx_phase_gain(31 downto 16));
    correction_tx_gain  <= signed(correction_tx_phase_gain(15 downto 0));
    correction_rx_phase <= signed(correction_rx_phase_gain(31 downto 16));
    correction_rx_gain  <= signed(correction_rx_phase_gain(15 downto 0));
    correction_valid <= '1';

    -- Create 80MHz from 38.4MHz coming from the c4_clock source
	 -- Also create clocks for DVB transmitter
    U_pll : entity work.pll
      port map (
        inclk0              =>  c4_clock,
        c0                  =>  \80MHz\,
		  c1	 					 => dvb_96MHz_clock,
		  c2	 					 => dvb_16MHz_clock,
		  c4						 => dvb_4MHz_clock,
        locked              =>  \80MHz locked\
      ) ;

    U_fx3_pll : entity work.fx3_pll
      port map (
        inclk0              =>  fx3_pclk,
        c0                  =>  fx3_pclk_pll,
        locked              =>  fx3_pll_locked
      ) ;

    -- Cross domain synchronizer chains
    U_usb_speed : entity work.synchronizer
      generic map (
        RESET_LEVEL         =>  '0'
      ) port map (
        reset               =>  '0',
        clock               =>  fx3_pclk_pll,
        async               =>  nios_gpio(7),
        sync                =>  usb_speed
      ) ;

    U_usb_speed_rx : entity work.synchronizer
      generic map (
        RESET_LEVEL         =>  '0'
      ) port map (
        reset               =>  '0',
        clock               =>  rx_clock,
        async               =>  nios_gpio(7),
        sync                =>  usb_speed_rx
      ) ;

    U_usb_speed_tx : entity work.synchronizer
      generic map (
        RESET_LEVEL         =>  '0'
      ) port map (
        reset               =>  '0',
        clock               =>  tx_clock,
        async               =>  nios_gpio(7),
        sync                =>  usb_speed_tx
      ) ;

    generate_mux_sel : for i in rx_mux_sel'range generate
        U_rx_source : entity work.synchronizer
          generic map (
            RESET_LEVEL         =>  '0'
          ) port map (
            reset               =>  '0',
            clock               =>  rx_clock,
            async               =>  nios_gpio(8+i),
            sync                =>  rx_mux_sel(i)
          ) ;
    end generate ;

    U_meta_sync_fx3 : entity work.synchronizer
      generic map (
        RESET_LEVEL         =>  '0'
      ) port map (
        reset               =>  '0',
        clock               =>  fx3_pclk_pll,
        async               =>  nios_gpio(16),
        sync                =>  meta_en_fx3
      ) ;

    U_meta_sync_tx : entity work.synchronizer
      generic map (
        RESET_LEVEL         =>  '0'
      ) port map (
        reset               =>  '0',
        clock               =>  tx_clock,
        async               =>  nios_gpio(16),
        sync                =>  meta_en_tx
      ) ;

    U_meta_sync_rx : entity work.synchronizer
      generic map (
        RESET_LEVEL         =>  '0'
      ) port map (
        reset               =>  '0',
        clock               =>  rx_clock,
        async               =>  nios_gpio(16),
        sync                =>  meta_en_rx
      ) ;

    xb_mode <= nios_gpio(31 downto 30);

    U_sys_reset_sync : entity work.reset_synchronizer
      generic map (
        INPUT_LEVEL         =>  '1',
        OUTPUT_LEVEL        =>  '1'
      ) port map (
        clock               =>  fx3_pclk_pll,
        async               =>  sys_rst,
        sync                =>  sys_rst_sync
      ) ;

    U_80M_reset_sync : entity work.reset_synchronizer
      generic map (
        INPUT_LEVEL         =>  '1',
        OUTPUT_LEVEL        =>  '1'
      ) port map (
        clock               =>  \80MHz\,
        async               =>  sys_rst,
        sync                =>  sys_rst_80M
      ) ;

    U_tx_reset : entity work.reset_synchronizer
      generic map (
        INPUT_LEVEL         =>  '1',
        OUTPUT_LEVEL        =>  '1'
      ) port map (
        clock               =>  c4_tx_clock,
        async               =>  sys_rst_sync,
        sync                =>  tx_reset
      ) ;

	 U_dvb_reset : entity work.reset_synchronizer
      generic map (
        INPUT_LEVEL         =>  '1',
        OUTPUT_LEVEL        =>  '1'
      ) port map (
        clock               =>  dvb_4MHz_clock,
        async               =>  sys_rst_sync,
        sync                =>  dvb_reset
      ) ;
		
    U_rx_clock_reset : entity work.reset_synchronizer
      generic map (
        INPUT_LEVEL         =>  '1',
        OUTPUT_LEVEL        =>  '1'
      ) port map (
        clock               =>  rx_clock,
        async               =>  sys_rst_sync,
        sync                =>  rx_reset
      ) ;

    U_rx_enable_sync : entity work.synchronizer
      generic map (
        RESET_LEVEL =>  '0'
      ) port map (
        reset       =>  rx_reset,
        clock       =>  rx_clock,
        async       =>  pclk_rx_enable,
        sync        =>  rx_enable
      ) ;

    U_tx_enable_sync : entity work.synchronizer
      generic map (
        RESET_LEVEL =>  '0'
      ) port map (
        reset       =>  tx_reset,
        clock       =>  tx_clock,
        async       =>  pclk_tx_enable,
        sync        =>  tx_enable
      ) ;

		U_dvb_enable_sync : entity work.synchronizer
      generic map (
        RESET_LEVEL =>  '0'
      ) port map (
        reset       =>  tx_reset,
        clock       =>  dvb_96MHz_clock,
        async       =>  pclk_tx_enable,
        sync        =>  dvb_enable
      ) ;
		
    -- TX sample fifo
    tx_sample_fifo.aclr <= tx_reset ;
    tx_sample_fifo.wclock <= fx3_pclk_pll ;
    tx_sample_fifo.rclock <= tx_clock ;
    U_tx_sample_fifo : entity work.tx_fifo
      port map (
        aclr                => tx_sample_fifo.aclr,
        data                => tx_sample_fifo.wdata,
        rdclk               => tx_sample_fifo.rclock,
        rdreq               => tx_sample_fifo.rreq,
        wrclk               => tx_sample_fifo.wclock,
        wrreq               => tx_sample_fifo.wreq,
        q                   => tx_sample_fifo.rdata,
        --rdempty             => tx_sample_fifo.rempty,
        rdempty             => tx_sample_fifo_rempty_untriggered,
        rdfull              => tx_sample_fifo.rfull,
        rdusedw             => tx_sample_fifo.rused,
        wrempty             => tx_sample_fifo.wempty,
        wrfull              => tx_sample_fifo.wfull,
        wrusedw             => tx_sample_fifo.wused
      );

    -- TX meta fifo
    tx_meta_fifo.aclr <= tx_reset ;
    tx_meta_fifo.wclock <= fx3_pclk_pll ;
    tx_meta_fifo.rclock <= tx_clock ;
    U_tx_meta_fifo : entity work.tx_meta_fifo
      port map (
        aclr                => tx_meta_fifo.aclr,
        data                => tx_meta_fifo.wdata,
        rdclk               => tx_meta_fifo.rclock,
        rdreq               => tx_meta_fifo.rreq,
        wrclk               => tx_meta_fifo.wclock,
        wrreq               => tx_meta_fifo.wreq,
        q                   => tx_meta_fifo.rdata,
        rdempty             => tx_meta_fifo.rempty,
        rdfull              => tx_meta_fifo.rfull,
        rdusedw             => tx_meta_fifo.rused,
        wrempty             => tx_meta_fifo.wempty,
        wrfull              => tx_meta_fifo.wfull,
        wrusedw             => tx_meta_fifo.wused
      );

    -- FX3 GPIF
    U_fx3_gpif : entity work.fx3_gpif
      port map (
        pclk                =>  fx3_pclk_pll,
        reset               =>  sys_rst_sync,

        usb_speed           =>  usb_speed,

        meta_enable         =>  meta_en_fx3,
        rx_enable           =>  pclk_rx_enable,
        tx_enable           =>  pclk_tx_enable,

        gpif_in             =>  fx3_gpif_in,
        gpif_out            =>  fx3_gpif_out,
        gpif_oe             =>  fx3_gpif_oe,
        ctl_in              =>  fx3_ctl_in,
        ctl_out             =>  fx3_ctl_out,
        ctl_oe              =>  fx3_ctl_oe,

        tx_fifo_write       =>  tx_sample_fifo.wreq,
        tx_fifo_full        =>  tx_sample_fifo.wfull,
        tx_fifo_empty       =>  tx_sample_fifo.wempty,
        tx_fifo_usedw       =>  tx_sample_fifo.wused,
        tx_fifo_data        =>  tx_sample_fifo.wdata,

        tx_timestamp        =>  fx3_timestamp,
        tx_meta_fifo_write  =>  tx_meta_fifo.wreq,
        tx_meta_fifo_full   =>  tx_meta_fifo.wfull,
        tx_meta_fifo_empty  =>  tx_meta_fifo.wempty,
        tx_meta_fifo_usedw  =>  tx_meta_fifo.wused,
        tx_meta_fifo_data   =>  tx_meta_fifo.wdata,


        rx_fifo_read        =>  rx_sample_fifo.rreq,
        rx_fifo_full        =>  rx_sample_fifo.rfull,
        rx_fifo_empty       =>  rx_sample_fifo.rempty,
        rx_fifo_usedw       =>  rx_sample_fifo.rused,
        rx_fifo_data        =>  rx_sample_fifo.rdata,

        rx_meta_fifo_read   =>  rx_meta_fifo.rreq,
        rx_meta_fifo_full   =>  rx_meta_fifo.rfull,
        rx_meta_fifo_empty  =>  rx_meta_fifo.rempty,
        rx_meta_fifo_usedr  =>  rx_meta_fifo.rused,
        rx_meta_fifo_data   =>  rx_meta_fifo.rdata
      ) ;
	 
	 -- Custom FIFO reader than inserts NULL packets
	 fifo_reader : dvb_fifo_reader
      port map (
        clock_data_in        => tx_clock,
        enable               => tx_enable,
		  in_reset				  => tx_reset,
		  
		  empty_in			     => tx_sample_fifo.rempty,
		  data_in		        => tx_sample_fifo.rdata,
		  
		  clock_data_out	     => dvb_16MHz_clock,
		  out_reset			     => dvb_reset,
		  valid_out			     => dvb_valid_in,
		  data_out			     => dvb_data_in,
		  
		  read_in_ret		     => tx_sample_fifo.rreq
      );
		
	 -- DVB-S2 Transmitter
	 -- Double the clock freq
	 my_dvb_tx : dvbs2_transmitter
	   port map (
        clock_96MHz      => dvb_96MHz_clock,
        clock_16MHz       => dvb_16MHz_clock,
		  clock_4MHz		 => dvb_4MHz_clock,
		  
		  reset 			    => (dvb_reset or (not \80MHz locked\)),
		  enable			    => dvb_enable,
		  
		  bit_in			    => dvb_data_in,
		  valid_in	     	 => dvb_valid_in,
		  output_clock	    => tx_clock,
		  output_reset	    => tx_reset,
		  sym_i_out			 => tx_sample_raw_i,
		  sym_q_out			 => tx_sample_raw_q,
		  
		  valid_out			 => tx_sample_raw_valid,
		  error 				 => dvb_error
      );
		
    U_tx_iq_correction : entity work.iq_correction(tx)
      generic map (
        INPUT_WIDTH         => tx_sample_raw_i'length
      ) port map (
        reset               => tx_reset,
        clock               => tx_clock,

        in_real             => tx_sample_raw_i,
        in_imag             => tx_sample_raw_q,
        in_valid            => tx_sample_raw_valid,

        out_real            => tx_sample_i,
        out_imag            => tx_sample_q,
        out_valid           => tx_sample_valid,

        dc_real             => FPGA_DC_CORRECTION,
        dc_imag             => FPGA_DC_CORRECTION,
        gain                => correction_tx_gain,
        phase               => correction_tx_phase,
        correction_valid    => correction_valid
      );

    -- TX Trigger
    U_tx_arm_sync : entity work.reset_synchronizer
      generic map (
        INPUT_LEVEL     =>  '0',
        OUTPUT_LEVEL    =>  '0'
      ) port map (
        clock           =>  tx_clock,
        async           =>  tx_trigger_arm,
        sync            =>  tx_trigger_arm_sync
      ) ;

    txtrig : entity work.trigger(async)
      generic map (
        DEFAULT_OUTPUT  => '1'
      ) port map (
        armed           => tx_trigger_arm_sync,
        fired           => tx_trigger_fire,
        master          => tx_trigger_master,
        trigger_in      => tx_trigger_line,
        trigger_out     => tx_trigger_line,
        signal_in       => tx_sample_fifo_rempty_untriggered,
        signal_out      => tx_sample_fifo.rempty
      );

    tx_trigger_arm_rb    <= tx_trigger_arm;
    tx_trigger_fire_rb   <= tx_trigger_fire;
    tx_trigger_master_rb <= tx_trigger_master;
    tx_trigger_line_rb   <= tx_trigger_line;

    -- LMS6002D IQ interface
    U_lms6002d : entity work.lms6002d
      port map (
        rx_clock            =>  rx_clock,
        rx_reset            =>  rx_reset,
        rx_enable           =>  rx_enable,

        rx_lms_data         =>  lms_rx_data_reg,
        rx_lms_iq_sel       =>  lms_rx_iq_select_reg,
        rx_lms_enable       =>  open,

        rx_sample_i         =>  rx_sample_i(11 downto 0),
        rx_sample_q         =>  rx_sample_q(11 downto 0),
        rx_sample_valid     =>  rx_sample_valid,

        tx_clock            =>  tx_clock,
        tx_reset            =>  tx_reset,
        tx_enable           =>  tx_enable,

        tx_sample_i         =>  tx_sample_i(11 downto 0),
        tx_sample_q         =>  tx_sample_q(11 downto 0),
        tx_sample_valid     =>  tx_sample_valid,

        tx_lms_data         =>  lms_tx_data,
        tx_lms_iq_sel       =>  lms_tx_iq_select,
        tx_lms_enable       =>  open
      ) ;

    -- Register the inputs immediately
    lms_rx_data_reg         <= lms_rx_data when rising_edge(rx_clock) ;
    lms_rx_iq_select_reg    <= lms_rx_iq_select when rising_edge(rx_clock) ;

    -- FX3 GPIF bidirectional signals
    register_gpif : process(sys_rst_sync, fx3_pclk_pll)
    begin
        if( sys_rst_sync = '1' ) then
            fx3_gpif <= (others =>'Z') ;
            fx3_gpif_in <= (others =>'0') ;
        elsif( rising_edge(fx3_pclk_pll) ) then
            fx3_gpif_in <= fx3_gpif ;
            if( fx3_gpif_oe = '1' ) then
                fx3_gpif <= fx3_gpif_out ;
            else
                fx3_gpif <= (others =>'Z') ;
            end if ;
        end if ;
    end process ;

    generate_ctl : for i in fx3_ctl'range generate
        fx3_ctl(i) <= fx3_ctl_out(i) when fx3_ctl_oe(i) = '1' else 'Z';
    end generate ;

    fx3_ctl_in <= fx3_ctl ;

    command_serial_in <= fx3_uart_txd when sys_rst_80M = '0' else '1' ;
    fx3_uart_rxd <= command_serial_out when sys_rst_80M = '0' else 'Z' ;

    -- NIOS control system for si5338, vctcxo trim and lms control
    U_nios_system : component nios_system
      port map (
        clk_clk                         => \80MHz\,
        reset_reset_n                   => '1',
        dac_MISO                        => nios_sdo,
        dac_MOSI                        => nios_sdio,
        dac_SCLK                        => nios_sclk,
        dac_SS_n                        => nios_ss_n,
        spi_MISO                        => lms_sdo,
        spi_MOSI                        => lms_sdio,
        spi_SCLK                        => lms_sclk,
        spi_SS_n                        => lms_sen,
        gpio_export                     => nios_gpio,
        xb_gpio_in_port                 => nios_xb_gpio_in,
        xb_gpio_out_port                => nios_xb_gpio_out,
        xb_gpio_dir_export              => nios_xb_gpio_dir,
        command_serial_in               => command_serial_in,
        command_serial_out              => command_serial_out,
        correction_tx_phase_gain_export => correction_tx_phase_gain,
        correction_rx_phase_gain_export => correction_rx_phase_gain,
        oc_i2c_scl_pad_o                => i2c_scl_out,
        oc_i2c_scl_padoen_o             => i2c_scl_oen,
        oc_i2c_sda_pad_i                => i2c_sda_in,
        oc_i2c_sda_pad_o                => i2c_sda_out,
        oc_i2c_sda_padoen_o             => i2c_sda_oen,
        oc_i2c_arst_i                   => '0',
        oc_i2c_scl_pad_i                => i2c_scl_in,
        rx_tamer_ts_sync_in             => '0',
        rx_tamer_ts_sync_out            => open,
        rx_tamer_ts_pps                 => '0',
        rx_tamer_ts_clock               => rx_clock,
        rx_tamer_ts_reset               => rx_ts_reset,
        unsigned(rx_tamer_ts_time)      => rx_timestamp,
        tx_tamer_ts_sync_in             => '0',
        tx_tamer_ts_sync_out            => open,
        tx_tamer_ts_pps                 => '0',
        tx_tamer_ts_clock               => tx_clock,
        tx_tamer_ts_reset               => tx_ts_reset,
        unsigned(tx_tamer_ts_time)      => tx_timestamp,
        vctcxo_tamer_tune_ref           => ref_vctcxo_tune,
        vctcxo_tamer_vctcxo_clock       => c4_clock,
        rx_trigger_ctl_out_port         => rx_trigger_ctl,
        tx_trigger_ctl_out_port         => tx_trigger_ctl,
        rx_trigger_ctl_in_port          => rx_trigger_ctl_rb,
        tx_trigger_ctl_in_port          => tx_trigger_ctl_rb
      ) ;

    xb_gpio_direction : process(all)
    begin
        for i in 0 to 31 loop
            if (xb_gpio_dir(i) = '1') then
                nios_xb_gpio_in(i) <= nios_xb_gpio_out(i);
                if (xb_mode = "10" and i + 1 = 2) then
                    exp_gpio(i+1) <= nios_ss_n(1);
                elsif (i + 1 /= 1) then
                    exp_gpio(i+1) <= nios_xb_gpio_out(i);
                end if;
            else
                if (i + 1 = 1) then
                    nios_xb_gpio_in(i) <= exp_clock_in;
                else
                    nios_xb_gpio_in(i) <= exp_gpio(i + 1);
                    exp_gpio(i + 1) <= 'Z';
                end if;
            end if;
        end loop ;
    end process ;

    nios_gpio(20 downto 19) <= nios_ss_n;
    nios_gpio(22 downto 21) <= xb_mode;

    dac_cs_selection : process(all)
    begin
        dac_sclk <= nios_sclk ;
        dac_sdi <= nios_sdio ;
        nios_sdo <= dac_sdo ;
        if( xb_mode = "00" ) then
            xb_gpio_dir <= nios_xb_gpio_dir(31 downto 0);
            dac_csx <= nios_ss_n(0);
        elsif( xb_mode = "10" ) then
            xb_gpio_dir <= nios_xb_gpio_dir(31 downto 0);
            if (nios_ss_n(1 downto 0) = "10") then --
                dac_csx <= '0';
            elsif (nios_ss_n(1 downto 0) = "01") then
                dac_csx <= '1';
            else
                dac_csx <= '1';
            end if;
        else
            xb_gpio_dir <= nios_xb_gpio_dir(31 downto 0)  ;
            dac_csx <= nios_ss_n(0) ;
        end if;
    end process;

    -- IO for NIOS
    si_scl <= i2c_scl_out when i2c_scl_oen = '0' else 'Z' ;
    si_sda <= i2c_sda_out when i2c_sda_oen = '0' else 'Z' ;

    i2c_scl_in <= si_scl ;
    i2c_sda_in <= si_sda ;

	 -- Generates a heartbeat for the DVB transmitter
    toggle_led2 : process(dvb_16MHz_clock)
        variable count : natural range 0 to 10_000_000 := 2_000_000 ;
    begin
        if( rising_edge(dvb_16MHz_clock) ) then
            count := count - 1 ;
            if( count = 0 ) then
                count := 2_000_000 ;
                led2_blink <= not led2_blink;
            end if ;
        end if ;
    end process ;

	 tx_view_data : process(tx_reset, dvb_16MHz_clock)
		  variable number_sent : natural range 0 to 30 := 0; 
    begin
        if( tx_reset = '1' ) then
            walking_i_sample <= '0';
        elsif( rising_edge(dvb_16MHz_clock) ) then
				if (number_sent = 30) then
					save_sample <= std_logic_vector(tx_sample_raw_i);
					number_sent := 0;
					walking_i_sample <= tx_sample_raw_i(0);
				elsif (number_sent < 11) then
					number_sent := number_sent + 1;
					walking_i_sample <= save_sample(number_sent);
				else
					number_sent := number_sent + 1;
					walking_i_sample <= '1';
				end if;
        end if ;
    end process ;
	 
	 -- LED 1 on the board (numbering got flipped somewhere)
	 -- If lit, indicates error in DVB
    led(2) <= not dvb_error;
	 
	 -- LED 2 on the board
	 -- Heartbeat for DVB
    led(1) <= led2_blink;
	 
	 -- LED 3 on board
	 -- Always on
    led(3) <= '0';
	 
    lms_reset               <= nios_gpio(0) ;

    lms_rx_enable_sig       <= nios_gpio(1) ;
    lms_rx_enable           <= nios_gpio(1) ;
    lms_tx_enable           <= nios_gpio(2) ;

    lms_tx_v                <= nios_gpio(4 downto 3) ;
    lms_rx_v                <= nios_gpio(6 downto 5) ;

    -- CTS and the SPI CSx are tied to the same signal.  When we are in reset, allow for SPI accesses
    fx3_uart_cts            <= '1' when sys_rst_sync = '0' else 'Z'  ;

    exp_spi_clock           <= nios_sclk when ( nios_ss_n(1 downto 0) = "01" ) else '0' ;
    exp_spi_mosi            <= nios_sdio when ( nios_ss_n(1 downto 0) = "01" ) else '0' ;

	 -- Debugging header
	 -- Outputs samples 'bit serially' and valid samples
    mini_exp1    				 <= walking_i_sample;
    mini_exp2               <= tx_sample_raw_valid;

    set_tx_ts_reset : process(tx_clock, tx_reset)
    begin
        if( tx_reset = '1' ) then
            tx_ts_reset <= '1' ;
        elsif( rising_edge(tx_clock) ) then
            if( meta_en_tx = '1' ) then
                tx_ts_reset <= '0' ;
            else
                tx_ts_reset <= '1' ;
            end if ;
        end if ;
    end process ;

    set_rx_ts_reset : process(rx_clock, rx_reset)
    begin
        if( rx_reset = '1' ) then
            rx_ts_reset <= '1' ;
        elsif( rising_edge(rx_clock) ) then
            if( meta_en_rx = '1' ) then
                rx_ts_reset <= '0' ;
            else
                rx_ts_reset <= '1' ;
            end if ;
        end if ;
    end process ;

    drive_handshake : process(fx3_pclk_pll, sys_rst_sync)
    begin
        if( sys_rst_sync = '1' ) then
            timestamp_req <= '0' ;
        elsif( rising_edge(fx3_pclk_pll) ) then
            if( meta_en_fx3 = '0' ) then
                timestamp_req <= '0' ;
            else
                if( timestamp_ack = '0' ) then
                    timestamp_req <= '1' ;
                elsif( timestamp_ack = '1' ) then
                    timestamp_req <= '0' ;
                end if ;
            end if ;
        end if ;
    end process ;

    U_timestamp_handshake : entity work.handshake
      generic map (
        DATA_WIDTH          =>  tx_timestamp'length
      ) port map (
        source_clock        =>  tx_clock,
        source_reset        =>  tx_reset,
        source_data         =>  std_logic_vector(tx_timestamp),

        dest_clock          =>  fx3_pclk_pll,
        dest_reset          =>  sys_rst_sync,
        unsigned(dest_data) =>  fx3_timestamp,
        dest_req            =>  timestamp_req,
        dest_ack            =>  timestamp_ack
      ) ;

end architecture ; -- arch

