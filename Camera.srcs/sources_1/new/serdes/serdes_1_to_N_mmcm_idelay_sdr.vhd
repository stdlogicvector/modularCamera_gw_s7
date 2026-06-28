library IEEE, UNISIM;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use UNISIM.vcomponents.all;

entity serdes_1_to_N_mmcm_idelay_sdr is
generic (
	N						: integer := 7;					-- Serdes Factor
	D 						: integer := 8;					-- Set the number of inputs
	SAMPL_CLOCK 			: string := "BUFIO";   			-- Parameter to set sampling clock buffer type, BUFIO, BUF_H, BUF_G
	PIXEL_CLOCK 			: string := "BUF_R";      		-- Parameter to set pixel clock buffer type, BUFR, BUF_H, BUF_G
	USE_PLL     			: boolean := FALSE;          	-- Parameter to enable PLL use rather than MMCM use, note, PLL does not support BUFIO and BUFR
	CLKIN_PERIOD			: real := 6.000;				-- clock period (ns) of input clock on clkin_p
	HIGH_PERFORMANCE_MODE 	: string := "FALSE";			-- Parameter to set HIGH_PERFORMANCE_MODE of input delays to reduce jitter
	MMCM_MODE				: integer := 1;					-- Parameter to set multiplier for MMCM to get VCO in correct operating range. 1 multiplies input clock by 7, 2 multiplies clock by 14, etc
	DIFF_TERM				: boolean := FALSE;				-- Enable or disable internal differential termination
	DATA_FORMAT 			: string := "PER_CLOCK";			-- Used to determine method for mapping input parallel word to output serial words
	CLK_PATTERN_0			: std_logic_vector(N-1 downto 0);
	CLK_PATTERN_1			: std_logic_vector(N-1 downto 0);
	INVERT_CLK				: boolean := FALSE;
	INVERT_DATA 			: std_logic_vector(D-1 downto 0) := (others => '0')	-- pinswap mask for input data bits (0 = no swap (default), 1 = swap). Allows inputs to be connected the wrong way round to ease PCB routing.
);
port 	(
	clkin_p					:  in std_logic;						-- Input from LVDS clock pin
	clkin_n					:  in std_logic;						-- Input from LVDS clock pin
	datain_p				:  in std_logic_vector(D-1 downto 0);	-- Input from LVDS receiver pin
	datain_n				:  in std_logic_vector(D-1 downto 0);	-- Input from LVDS receiver pin
	enable_phase_detector	:  in std_logic;						-- Enables the phase detector logic when high
	enable_monitor			:  in std_logic;						-- Enables the monitor logic when high, note time-shared with phase detector function
	reset					:  in std_logic;						-- Reset line
	idelay_rdy				:  in std_logic;						-- input delays are ready
	rxclk					: out std_logic;						-- Global/BUFIO rx clock network
	rxclk_div				: out std_logic;						-- Global/Regional clock output
	rx_mmcm_lckd			: out std_logic;						-- MMCM locked, synchronous to rxclk_div
	rx_mmcm_lckdps			: out std_logic;						-- MMCM locked and phase shifting finished, synchronous to rxclk_div
	rx_mmcm_lckdpsbs		: out std_logic;						-- MMCM locked and phase shifting finished and bitslipping finished, synchronous to rxclk_div
	clk_data				: out std_logic_vector(N-1 downto 0);  	-- received clock data
	rx_data					: out std_logic_vector((N*D)-1 downto 0);-- Output data
	bit_rate_value			:  in std_logic_vector(15 downto 0);	-- Bit rate in Mbps, eg X"0585
	bit_time_value			: out std_logic_vector(4 downto 0);		-- Calculated bit time value for slave devices
	status					: out std_logic_vector(6 downto 0);		-- Status bus
	eye_info				: out std_logic_vector(32*D-1 downto 0);-- Eye info
	m_delay_1hot			: out std_logic_vector(32*D-1 downto 0);-- Master delay control value as a one-hot vector
	rst_iserdes				: out std_logic;						-- reset serdes output
	debug					: out std_logic_vector(10*D+5 downto 0));-- Debug bus

end serdes_1_to_N_mmcm_idelay_sdr;

architecture arch_serdes_1_to_N_mmcm_idelay_sdr of serdes_1_to_N_mmcm_idelay_sdr is

signal	m_delay_val_in		: std_logic_vector(5*D-1 downto 0);
signal	s_delay_val_in		: std_logic_vector(5*D-1 downto 0);
signal	rx_clk_in_p			: std_logic;
signal	rx_clk_in_n			: std_logic;
signal	rx_clk_p			: std_logic;
signal	rx_clk_n			: std_logic;
signal	not_rx_clk_in_n		: std_logic;
signal	bsstate				: std_logic;
signal	bslip				: std_logic;
signal	bcount				: std_logic_vector(3 downto 0);
signal	clk_iserdes_data	: std_logic_vector(7 downto 0);
signal	clk_iserdes_data_d	: std_logic_vector(7 downto 0);
signal	enable				: std_logic;
signal	flag1				: std_logic;
signal	flag2				: std_logic;
signal	state2				: integer range 0 to 4;
signal	state2_count		: std_logic_vector(4 downto 0);
signal	scount				: std_logic_vector(5 downto 0);
signal	locked_out			: std_logic;
signal	chfound				: std_logic;
signal	chfoundc			: std_logic;
signal	rx_mmcm_lckd_int	: std_logic;
signal	c_delay_in			: std_logic_vector(4 downto 0);
signal	c_delay_in_target	: std_logic_vector(4 downto 0);
signal	c_delay_in_ud		: std_logic;
signal	rx_data_in_p		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_n		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_m		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_s		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_md		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_sd		: std_logic_vector(D-1 downto 0);
signal	mdataout			: std_logic_vector(8*D-1 downto 0);
signal	mdataoutd			: std_logic_vector(8*D-1 downto 0);
signal	sdataout			: std_logic_vector(8*D-1 downto 0);
signal	data_different		: std_logic;
signal	bs_finished			: std_logic;
signal	not_bs_finished		: std_logic;
signal	bt_val 				: std_logic_vector(4 downto 0);
signal 	rxclk_div_int		: std_logic;
signal 	rxclk_int			: std_logic;
signal 	not_rxclk			: std_logic;
signal 	not_rx_mmcm_lckd_int: std_logic;
signal 	mmcm_locked			: std_logic;
signal 	rx_clkin_p_d		: std_logic;
signal 	rx_clkin_n_d		: std_logic;
signal 	rx_mmcmout_xs		: std_logic;
signal 	rx_mmcmout_x1		: std_logic;
signal 	no_clock			: std_logic;
signal	bt_val_d2			: std_logic_vector(4 downto 0);
signal	c_loop_cnt			: std_logic_vector(1 downto 0);
signal	rstcserdes			: std_logic;
signal	rst_iserdes_int		: std_logic;

begin

clk_data			<= clk_iserdes_data(7 downto 8-N);
debug				<= s_delay_val_in & m_delay_val_in & bslip & c_delay_in;
rx_mmcm_lckdpsbs	<= bs_finished and mmcm_locked;
rx_mmcm_lckd		<= rx_mmcm_lckd_int and mmcm_locked;
rx_mmcm_lckdps		<= rx_mmcm_lckd_int and locked_out and mmcm_locked;
bit_time_value		<= bt_val;
rxclk_div			<= rxclk_div_int;
rxclk				<= rxclk_int;
not_bs_finished		<= not bs_finished;
bt_val_d2			<= '0' & bt_val(4 downto 1);
rst_iserdes			<= rst_iserdes_int;

-- Generate tap number to be used for input bit rate

bt_val <= "01100" when bit_rate_value > X"1068" else
          "01101" when bit_rate_value > X"0986" else
          "01110" when bit_rate_value > X"0916" else
          "01111" when bit_rate_value > X"0855" else
          "10000" when bit_rate_value > X"0801" else
          "10001" when bit_rate_value > X"0754" else
          "10010" when bit_rate_value > X"0712" else
          "10011" when bit_rate_value > X"0675" else
          "10100" when bit_rate_value > X"0641" else
          "10101" when bit_rate_value > X"0611" else
          "10110" when bit_rate_value > X"0583" else
          "10111" when bit_rate_value > X"0557" else
          "11000" when bit_rate_value > X"0534" else
          "11001" when bit_rate_value > X"0513" else
          "11010" when bit_rate_value > X"0493" else
          "11011" when bit_rate_value > X"0475" else
          "11100" when bit_rate_value > X"0458" else
          "11101" when bit_rate_value > X"0442" else
          "11110" when bit_rate_value > X"0427" else
          "11111";
          
-- Bitslip state machine

process (rxclk_div_int)
begin
	if rising_edge(rxclk_div_int) then
		if locked_out = '0' then
			bslip <= '0';
			bsstate <= '1';
			enable <= '0';
			bcount <= X"0";
			bs_finished <= '0';
		else
			enable <= '1';

			if enable = '1' then
				if clk_iserdes_data(7 downto 8-N) /= CLK_PATTERN_0 then flag1 <= '1'; else flag1 <= '0'; end if;
				if clk_iserdes_data(7 downto 8-N) /= CLK_PATTERN_1 then flag2 <= '1'; else flag2 <= '0'; end if;

				if bsstate = '0' then
					if flag1 = '1' and flag2 = '1' then
						bslip <= '1';						-- bitslip needed
						bsstate <= '1';
					else
						bs_finished <= '1';					-- bitslip done
					end if;
				elsif bsstate = '1' then						-- wait for bitslip ack from other clock domain
					bslip <= '0';
					bcount <= bcount + 1;
					
					if bcount = "1111" then
						bsstate <= '0';
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

-- Clock input

iob_clk_in : IBUFGDS_DIFF_OUT
generic map (
	DIFF_TERM 		=> DIFF_TERM,
	IOSTANDARD		=> "LVDS_25"
)
port map (
	I    			=> clkin_p,
	IB       		=> clkin_n,
	O         		=> rx_clk_in_p,
	OB         		=> rx_clk_in_n
);

rx_clk_p <= rx_clk_in_p when INVERT_CLK = FALSE else rx_clk_in_n;
rx_clk_n <= rx_clk_in_n when INVERT_CLK = FALSE else rx_clk_in_p;

idelay_cm : IDELAYE2
generic map (
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 1,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map(
	DATAOUT			=> rx_clkin_p_d,
	C				=> rxclk_div_int,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> rx_clk_in_p,
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> c_delay_in,
	CNTVALUEOUT		=> open
);

not_rx_clk_in_n <= not rx_clk_in_n;

idelay_cs : IDELAYE2
generic map (
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 1,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map (
	DATAOUT			=> rx_clkin_n_d,
	C				=> rxclk_div_int,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> not_rx_clk_in_n,
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> bt_val_d2,
	CNTVALUEOUT		=> open
);

not_rxclk <= not rxclk_int;
not_rx_mmcm_lckd_int <= not rx_mmcm_lckd_int;

iserdes_cs : ISERDESE2
generic map (
	DATA_WIDTH     	=> N,
	DATA_RATE      	=> "SDR",
--	SERDES_MODE    	=> "MASTER",
	IOBDELAY	    => "IFD",
	INTERFACE_TYPE 	=> "NETWORKING"
)
port map (
	D       		=> '0',
	DDLY     		=> rx_clkin_n_d,
	CE1     		=> '1',
	CE2     		=> '1',
	CLK    			=> rxclk_int,
	CLKB    		=> not_rxclk,
	RST     		=> rstcserdes,
	CLKDIV  		=> rxclk_div_int,
	CLKDIVP  		=> '0',
	OCLK    		=> '0',
	OCLKB    		=> '0',
	DYNCLKSEL    	=> '0',
	DYNCLKDIVSEL  	=> '0',
	SHIFTIN1 		=> '0',
	SHIFTIN2 		=> '0',
	BITSLIP 		=> bslip,
	O	 			=> open,
	Q8 				=> clk_iserdes_data(0),
	Q7 				=> clk_iserdes_data(1),
	Q6 				=> clk_iserdes_data(2),
	Q5 				=> clk_iserdes_data(3),
	Q4 				=> clk_iserdes_data(4),
	Q3 				=> clk_iserdes_data(5),
	Q2 				=> clk_iserdes_data(6),
	Q1 				=> clk_iserdes_data(7),
	OFB 			=> '0',
	SHIFTOUT1 		=> open,
	SHIFTOUT2 		=> open
);

status(3 downto 2) <= "00";

loop8 : if USE_PLL = FALSE generate				-- use an MMCM

status(6) <= '1';

rx_mmcm_adv_inst : MMCME2_ADV
generic map (
	BANDWIDTH			=> "OPTIMIZED",
	CLKFBOUT_MULT_F		=> real(N) * MMCM_MODE,
	CLKFBOUT_PHASE		=> 0.0,
	CLKIN1_PERIOD		=> CLKIN_PERIOD,
	CLKIN2_PERIOD		=> CLKIN_PERIOD,
	CLKOUT0_DIVIDE_F	=> 1.000 * MMCM_MODE,
	CLKOUT0_DUTY_CYCLE	=> 0.5,
	CLKOUT0_PHASE		=> 0.0,
	CLKOUT0_USE_FINE_PS	=> FALSE,
	CLKOUT1_DIVIDE		=> N * MMCM_MODE,
	CLKOUT1_DUTY_CYCLE	=> 0.5,
	CLKOUT1_PHASE		=> 22.5,
	CLKOUT1_USE_FINE_PS	=> FALSE,
	CLKOUT2_DIVIDE		=> N * MMCM_MODE,
	CLKOUT2_DUTY_CYCLE	=> 0.5,
	CLKOUT2_PHASE		=> 0.0,
	CLKOUT2_USE_FINE_PS	=> FALSE,
	CLKOUT3_DIVIDE		=> N,
	CLKOUT3_DUTY_CYCLE	=> 0.5,
	CLKOUT3_PHASE		=> 0.0,
	CLKOUT4_DIVIDE		=> N,
	CLKOUT4_DUTY_CYCLE	=> 0.5,
	CLKOUT4_PHASE		=> 0.0,
	CLKOUT5_DIVIDE		=> N,
	CLKOUT5_DUTY_CYCLE	=> 0.5,
	CLKOUT5_PHASE		=> 0.0,
	COMPENSATION		=> "ZHOLD",
	DIVCLK_DIVIDE		=> 1,
	REF_JITTER1			=> 0.100
)
port map (
	CLKFBOUT		=> rx_mmcmout_x1,
	CLKFBOUTB		=> open,
	CLKFBSTOPPED	=> open,
	CLKINSTOPPED	=> open,
	CLKOUT0			=> rx_mmcmout_xs,
	CLKOUT0B		=> open,
	CLKOUT1			=> open,
	CLKOUT1B		=> open,
	CLKOUT2			=> open,
	CLKOUT2B		=> open,
	CLKOUT3			=> open,
	CLKOUT3B		=> open,
	CLKOUT4			=> open,
	CLKOUT5			=> open,
	CLKOUT6			=> open,
	DO				=> open,
	DRDY			=> open,
	PSDONE			=> open,
	PSCLK			=> '0',
	PSEN			=> '0',
	PSINCDEC		=> '0',
	PWRDWN			=> '0',
	LOCKED			=> mmcm_locked,
	CLKFBIN			=> rxclk_div_int,
	CLKIN1			=> rx_clkin_p_d,
	CLKIN2			=> '0',
	CLKINSEL		=> '1',
	DADDR			=> "0000000",
	DCLK			=> '0',
	DEN				=> '0',
	DI				=> X"0000",
	DWE				=> '0',
	RST				=> reset
);

  loop6 : if PIXEL_CLOCK = "BUF_G" generate
     bufg_mmcm_x1 : BUFG	port map (I => rx_mmcmout_x1, O => rxclk_div_int);
     status(1 downto 0) <= "00";
  end generate;
  
  loop6a : if PIXEL_CLOCK = "BUF_R" generate
     bufr_mmcm_x1 : BUFR
     generic map (
     	BUFR_DIVIDE => "1",
     	SIM_DEVICE => "7SERIES"
     )
     port map (
     	I	=> rx_mmcmout_x1,
     	CE	=> '1',
     	O	=> rxclk_div_int,CLR => '0'
     );
     status(1 downto 0) <= "01";
  end generate;
  
  loop6b : if PIXEL_CLOCK = "BUF_H" generate
     bufh_mmcm_x1 : BUFH	port map (I => rx_mmcmout_x1, O => rxclk_div_int);
     status(1 downto 0) <= "10";
  end generate;
  
  loop9 : if SAMPL_CLOCK = "BUF_G" generate
     bufg_mmcm_xn : BUFG port map(I => rx_mmcmout_xs, O => rxclk_int);
     status(5 downto 4) <= "00";
  end generate;
  
  loop9a : if SAMPL_CLOCK = "BUFIO" generate
     bufio_mmcm_xn : BUFIO port map (I => rx_mmcmout_xs, O => rxclk_int);
     status(5 downto 4) <= "11";
  end generate;
 
  loop9b : if SAMPL_CLOCK = "BUF_H" generate
     bufh_mmcm_xn : BUFH port map(I => rx_mmcmout_xs, O => rxclk_int);
     status(5 downto 4) <= "10";
  end generate;
end generate;

loop2 : if USE_PLL = TRUE generate				-- use an MMCM

status(6) <= '0';

rx_mmcm_adv_inst : PLLE2_ADV
generic map (
	BANDWIDTH			=> "OPTIMIZED",
	CLKFBOUT_MULT		=> N * MMCM_MODE,
	CLKFBOUT_PHASE		=> 0.0,
	CLKIN1_PERIOD		=> CLKIN_PERIOD,
	CLKIN2_PERIOD		=> CLKIN_PERIOD,
	CLKOUT0_DIVIDE		=> 1 * MMCM_MODE,
	CLKOUT0_DUTY_CYCLE	=> 0.5,
	CLKOUT0_PHASE		=> 0.0,
	CLKOUT1_DIVIDE		=> N * MMCM_MODE,
	CLKOUT1_DUTY_CYCLE	=> 0.5,
	CLKOUT1_PHASE		=> 22.5,
	CLKOUT2_DIVIDE		=> N * MMCM_MODE,
	CLKOUT2_DUTY_CYCLE	=> 0.5,
	CLKOUT2_PHASE		=> 0.0,
	CLKOUT3_DIVIDE		=> N,
	CLKOUT3_DUTY_CYCLE	=> 0.5,
	CLKOUT3_PHASE		=> 0.0,
	CLKOUT4_DIVIDE		=> N,
	CLKOUT4_DUTY_CYCLE	=> 0.5,
	CLKOUT4_PHASE		=> 0.0,
	CLKOUT5_DIVIDE		=> N,
	CLKOUT5_DUTY_CYCLE	=> 0.5,
	CLKOUT5_PHASE		=> 0.0,
	COMPENSATION		=> "ZHOLD",
	DIVCLK_DIVIDE		=> 1,
	REF_JITTER1			=> 0.100
)
port map (
	CLKFBOUT		=> rx_mmcmout_x1,
	CLKOUT0			=> rx_mmcmout_xs,
	CLKOUT1			=> open,
	CLKOUT2			=> open,
	CLKOUT3			=> open,
	CLKOUT4			=> open,
	CLKOUT5			=> open,
	DO				=> open,
	DRDY			=> open,
	PWRDWN			=> '0',
	LOCKED			=> mmcm_locked,
	CLKFBIN			=> rxclk_div_int,
	CLKIN1			=> rx_clkin_p_d,
	CLKIN2			=> '0',
	CLKINSEL		=> '1',
	DADDR			=> "0000000",
	DCLK			=> '0',
	DEN				=> '0',
	DI				=> X"0000",
	DWE				=> '0',
	RST				=> reset
);

  loop4 : if PIXEL_CLOCK = "BUF_G" generate
     bufg_pll_x1 : BUFG	port map (I => rx_mmcmout_x1, O => rxclk_div_int);
     status(1 downto 0) <= "00";
  end generate;
  
  loop4a : if PIXEL_CLOCK = "BUF_R" generate
     bufr_pll_x1 : BUFR
     generic map (
     	BUFR_DIVIDE => "1",
     	SIM_DEVICE => "7SERIES"
     )
     port map (
     	I	=> rx_mmcmout_x1,
     	CE	=> '1',
     	O 	=> rxclk_div_int,
     	CLR => '0'
     );
     status(1 downto 0) <= "01";
  end generate;
  
  loop4b : if PIXEL_CLOCK = "BUF_H" generate
     bufh_pll_x1 : BUFH	port map (I => rx_mmcmout_x1, O => rxclk_div_int);
     status(1 downto 0) <= "10";
  end generate;
  
  loop10 : if SAMPL_CLOCK = "BUF_G" generate
     bufg_pll_xn : BUFG port map(I => rx_mmcmout_xs, O => rxclk_int);
     status(5 downto 4) <= "00";
  end generate;
  
  loop10a : if SAMPL_CLOCK = "BUFIO" generate
     bufio_pll_xn : BUFIO port map (I => rx_mmcmout_xs, O => rxclk_int);
     status(5 downto 4) <= "11";
  end generate;
  
  loop10b : if SAMPL_CLOCK = "BUF_H" generate
     bufh_pll_xn : BUFH port map(I => rx_mmcmout_xs, O => rxclk_int);
     status(5 downto 4) <= "10";
  end generate;
end generate;

process (rxclk_div_int)
begin
	if rising_edge(rxclk_div_int) then
		clk_iserdes_data_d <= clk_iserdes_data;

		if clk_iserdes_data(7 downto 8-N) /= clk_iserdes_data_d(7 downto 8-N) and or(clk_iserdes_data(7 downto 8-N)) /= '0'  and and(clk_iserdes_data(7 downto 8-N)) /= '1' then
			data_different <= '1';
		else
			data_different <= '0';
		end if;

		if or(clk_iserdes_data(7 downto 8-N)) = '0' or and(clk_iserdes_data(7 downto 8-N)) = '1' then
			no_clock <= '1';
		else
			no_clock <= '0';
		end if;
	end if;
end process;

process (rxclk_div_int)
begin
	if rising_edge(rxclk_div_int) then					-- clock delay shift state machine
		rx_mmcm_lckd_int <= mmcm_locked and idelay_rdy;
		rstcserdes <= not mmcm_locked or rst_iserdes_int;
		
		if rx_mmcm_lckd_int = '0' then
			scount <= "000000";
			state2 <= 0;
			state2_count <= "00000";
			locked_out <= '0';
			chfoundc <= '1';
			c_delay_in <= bt_val;							-- Start the delay line at the current bit period
			rst_iserdes_int <= '0';
			c_loop_cnt <= "00";
		else
			if scount(5) = '0' then
				scount <= scount + 1;
			end if;

			state2_count <= state2_count + 1;

			if chfoundc = '1' then
				chfound <= '0';
			elsif chfound = '0' and data_different = '1' then
				chfound <= '1';
			end if;

			if (state2_count = "11111" and scount(5) = '1') then
				case (state2) is
				when 0	=>							-- decrement delay and look for a change
					  if chfound = '1' or (c_loop_cnt = "11" and c_delay_in = "00000") then  -- quit loop if we've been around a few times
						chfoundc <= '1';
						state2 <= 1;
					  else
						chfoundc <= '0';
						if c_delay_in /= "00000" then			-- check for underflow
							c_delay_in <= c_delay_in - 1;
						else
							c_delay_in <= bt_val;
							c_loop_cnt <= c_loop_cnt + 1;
						end if;
					  end if;
				when 1	=>							-- add or subtract half a bit period using input information
					  state2 <= 2;						-- choose the lowest delay value to minimise jitter
					  if c_delay_in < '0' & bt_val(4 downto 1) then
						c_delay_in_target <= c_delay_in + ('0' & bt_val(4 downto 1));
						c_delay_in_ud <= '1';
					  else
						c_delay_in_target <= c_delay_in - ('0' & bt_val(4 downto 1));
						c_delay_in_ud <= '0';
					  end if;
				when 2 	=> if c_delay_in = c_delay_in_target then
						state2 <= 3;
					   else
						if c_delay_in_ud = '1' then				-- move gently to end position to stop MMCM unlocking
							c_delay_in <= c_delay_in + 1;
						else
							c_delay_in <= c_delay_in - 1;
						end if;
					   end if;
				when 3 	=> rst_iserdes_int <= '1'; state2 <= 4;
				when others =>							-- issue locked out signal and wait for a manual command (if required)
					  rst_iserdes_int <= '0';  locked_out <= '1';
				end case;
			end   if;
		end if;
	end if;
end process;

loop3 : for i in 0 to D-1 generate

dc_inst : entity work.delay_controller_wrap
generic map (
	S => N
)
port map (
	m_datain				=> mdataout(8*(i+1)-1 downto 8*(i+1)-N),
	s_datain				=> sdataout(8*(i+1)-1 downto 8*(i+1)-N),
	enable_phase_detector	=> enable_phase_detector,
	enable_monitor			=> enable_monitor,
	reset					=> not_bs_finished,
	clk						=> rxclk_div_int,
	c_delay_in				=> bt_val_d2,
	m_delay_out				=> m_delay_val_in(5*i+4 downto 5*i),
	s_delay_out				=> s_delay_val_in(5*i+4 downto 5*i),
	data_out				=> mdataoutd(N*(i+1)-1 downto N*i),
	bt_val					=> bt_val,
	del_mech				=> '0',
	m_delay_1hot			=> m_delay_1hot(32*i+31 downto 32*i),
	results					=> eye_info(32*i+31 downto 32*i)
);

end generate;

-- Data bit Receivers

loop0 : for i in 0 to D-1 generate
loop1 : for j in 0 to N-1 generate			-- Assign data bits to correct serdes according to required format
	loop1a : if DATA_FORMAT = "PER_CLOCK" generate
		rx_data(D*j+i) <= mdataoutd(N*i+j);
	end generate;

	loop1b : if DATA_FORMAT = "PER_CHANL" generate
		rx_data(N*i+j) <= mdataoutd(N*i+j);
	end generate;
end generate;

data_in : IBUFDS_DIFF_OUT
generic map (
	DIFF_TERM 		=> DIFF_TERM,
	IOSTANDARD		=> "LVDS_25"
)
port map (
	I    			=> datain_p(i),
	IB       		=> datain_n(i),
	O         		=> rx_data_in_p(i),
	OB         		=> rx_data_in_n(i)
);

rx_data_in_m(i) <= rx_data_in_p(i) xor INVERT_DATA(i);
rx_data_in_s(i) <= not rx_data_in_n(i) xor INVERT_DATA(i);

idelay_m : IDELAYE2
generic map (
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE	=> 0,
	DELAY_SRC		=> "IDATAIN",
	IDELAY_TYPE		=> "VAR_LOAD"
)
port map(
	DATAOUT			=> rx_data_in_md(i),
	C				=> rxclk_div_int,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> rx_data_in_m(i),
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> m_delay_val_in(5*i+4 downto 5*i),
	CNTVALUEOUT		=> open
);

iserdes_m : ISERDESE2
generic map (
	DATA_WIDTH		=> N,
	DATA_RATE		=> "SDR",
	SERDES_MODE		=> "MASTER",
	IOBDELAY		=> "IFD",
	INTERFACE_TYPE	=> "NETWORKING"
)
port map (
	D       		=> '0',
	DDLY     		=> rx_data_in_md(i),
	CE1     		=> '1',
	CE2     		=> '1',
	CLK	   			=> rxclk_int,
	CLKB    		=> not_rxclk,
	RST     		=> rst_iserdes_int,
	CLKDIV  		=> rxclk_div_int,
	CLKDIVP  		=> '0',
	OCLK    		=> '0',
	OCLKB    		=> '0',
	DYNCLKSEL    	=> '0',
	DYNCLKDIVSEL  	=> '0',
	SHIFTIN1 		=> '0',
	SHIFTIN2 		=> '0',
	BITSLIP 		=> bslip,
	O	 			=> open,
	Q8  			=> mdataout(8*i+0),
	Q7  			=> mdataout(8*i+1),
	Q6  			=> mdataout(8*i+2),
	Q5  			=> mdataout(8*i+3),
	Q4  			=> mdataout(8*i+4),
	Q3  			=> mdataout(8*i+5),
	Q2  			=> mdataout(8*i+6),
	Q1  			=> mdataout(8*i+7),
	OFB 			=> '0',
	SHIFTOUT1		=> open,
	SHIFTOUT2 		=> open
);

idelay_s : IDELAYE2
generic map (
	HIGH_PERFORMANCE_MODE	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 0,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map (
	DATAOUT			=> rx_data_in_sd(i),
	C				=> rxclk_div_int,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> rx_data_in_s(i),
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> s_delay_val_in(5*i+4 downto 5*i),
	CNTVALUEOUT		=> open
);

iserdes_s : ISERDESE2
generic map (
	DATA_WIDTH     	=> N,
	DATA_RATE      	=> "SDR",
--	SERDES_MODE    	=> "MASTER",
	IOBDELAY	    => "IFD",
	INTERFACE_TYPE 	=> "NETWORKING"
)
port map (
	D       		=> '0',
	DDLY     		=> rx_data_in_sd(i),
	CE1     		=> '1',
	CE2     		=> '1',
	CLK	   			=> rxclk_int,
	CLKB    		=> not_rxclk,
	RST     		=> rst_iserdes_int,
	CLKDIV  		=> rxclk_div_int,
	CLKDIVP  		=> '0',
	OCLK    		=> '0',
	OCLKB    		=> '0',
	DYNCLKSEL    	=> '0',
	DYNCLKDIVSEL  	=> '0',
	SHIFTIN1 		=> '0',
	SHIFTIN2 		=> '0',
	BITSLIP 		=> bslip,
	O	 			=> open,
	Q8  			=> sdataout(8*i+0),
	Q7  			=> sdataout(8*i+1),
	Q6  			=> sdataout(8*i+2),
	Q5  			=> sdataout(8*i+3),
	Q4  			=> sdataout(8*i+4),
	Q3  			=> sdataout(8*i+5),
	Q2  			=> sdataout(8*i+6),
	Q1  			=> sdataout(8*i+7),
	OFB 			=> '0',
	SHIFTOUT1		=> open,
	SHIFTOUT2 		=> open
);

end generate;

end arch_serdes_1_to_N_mmcm_idelay_sdr;