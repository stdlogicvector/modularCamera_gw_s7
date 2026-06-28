library IEEE, UNISIM;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use UNISIM.vcomponents.all;

entity serdes_1_to_N_slave_idelay_sdr is
generic (
	N						: integer := 7;							-- Set the Serdes Factor
	D 						: integer := 8;							-- Set the number of inputs
 	HIGH_PERFORMANCE_MODE 	: string := "FALSE";					-- Parameter to set HIGH_PERFORMANCE_MODE of input delays to reduce jitter
	DIFF_TERM				: boolean := FALSE;						-- Enable or disable internal differential termination
	DATA_FORMAT 			: string := "PER_CLOCK";				-- Used to determine method for mapping input parallel word to output serial words
	CLK_PATTERN_0			: std_logic_vector(N-1 downto 0);
	CLK_PATTERN_1			: std_logic_vector(N-1 downto 0);
	INVERT_CLK				: boolean := FALSE;
	INVERT_DATA 			: std_logic_vector(D-1 downto 0) := (others => '0')	-- pinswap mask for input data bits (0 = no swap (default), 1 = swap). Allows inputs to be connected the wrong way round to ease PCB routing.
);
port (
	clkin_p					:  in std_logic;						-- Input from LVDS clock pin
	clkin_n					:  in std_logic;						-- Input from LVDS clock pin
	datain_p				:  in std_logic_vector(D-1 downto 0);	-- Input from LVDS receiver pin
	datain_n				:  in std_logic_vector(D-1 downto 0);	-- Input from LVDS receiver pin
	enable_phase_detector	:  in std_logic;						-- Enables the phase detector logic when high
	enable_monitor			:  in std_logic;						-- Enables the monitor logic when high, note time-shared with phase detector function
	reset					:  in std_logic;						-- Reset line
	idelay_rdy				:  in std_logic;						-- input delays are ready
	rxclk					:  in std_logic;						-- Global/BUFIO rx clock network
	rxclk_div				:  in std_logic;						-- Global/Regional clock output
	bitslip_finished		: out std_logic;						-- bitslipping finished, synchronous to rxclk_div
	clk_data				: out std_logic_vector(6 downto 0);  	-- received clock data
	rx_data					: out std_logic_vector((N*D)-1 downto 0);-- Output data
	bit_time_value			:  in std_logic_vector(4 downto 0);		-- Calculated bit time value for slave devices
	rst_iserdes				:  in std_logic;						-- reset serdes input
	eye_info				: out std_logic_vector(32*D-1 downto 0);-- Eye info
	m_delay_1hot			: out std_logic_vector(32*D-1 downto 0);-- Master delay control value as a one-hot vector
	debug					: out std_logic_vector(10*D+5 downto 0) -- Debug bus
);

end serdes_1_to_N_slave_idelay_sdr;

architecture arch_serdes_1_to_N_slave_idelay_sdr of serdes_1_to_N_slave_idelay_sdr is

signal	m_delay_val_in		: std_logic_vector(5*D-1 downto 0);
signal	s_delay_val_in		: std_logic_vector(5*D-1 downto 0);
signal	rx_clk_in			: std_logic;
signal  rx_clk				: std_logic;
signal	bsstate				: integer range 0 to 3;
signal	bslip				: std_logic;
signal	bcount				: std_logic_vector(3 downto 0);
signal	clk_iserdes_data	: std_logic_vector(7 downto 0);
signal	clk_iserdes_data_d	: std_logic_vector(7 downto 0);
signal	enable				: std_logic;
signal	flag1				: std_logic;
signal	flag2				: std_logic;
signal	state2				: integer range 0 to 3;
signal	state2_count		: std_logic_vector(3 downto 0);
signal	scount				: std_logic_vector(5 downto 0);
signal	locked_out			: std_logic;
signal	chfound				: std_logic;
signal	chfoundc			: std_logic;
signal	c_delay_in			: std_logic_vector(4 downto 0);
signal	rx_data_in_p		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_n		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_m		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_s		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_md		: std_logic_vector(D-1 downto 0);
signal	rx_data_in_sd		: std_logic_vector(D-1 downto 0);
signal	mdataout			: std_logic_vector(8*D-1 downto 0);
signal	mdataoutd			: std_logic_vector(8*D-1 downto 0);
signal	sdataout			: std_logic_vector(8*D-1 downto 0);
signal	dataout				: std_logic_vector(8*D-1 downto 0);
signal	data_different		: std_logic;
signal	bs_finished			: std_logic;
signal	not_bs_finished		: std_logic;
signal 	not_rxclk			: std_logic;
signal 	rx_clk_in_d			: std_logic;
signal 	local_reset			: std_logic;
signal	bt_val	 			: std_logic_vector(4 downto 0);
signal 	no_clock			: std_logic;
signal	c_loop_cnt			: std_logic_vector(1 downto 0);

begin

clk_data <= clk_iserdes_data(7 downto 8-N);
debug <= s_delay_val_in & m_delay_val_in & bslip & c_delay_in;
bitslip_finished <= bs_finished and not reset;
bt_val <= bit_time_value;
not_bs_finished <= not bs_finished;

process (rxclk_div, reset) begin				-- generate local reset
	if reset = '1' then
		local_reset <= '1';
	elsif rising_edge(rxclk_div) then
		if idelay_rdy = '0' then
			local_reset <= '1';
		else
			local_reset <= '0';
		end if;
	end if;
end process;

-- Bitslip state machine, split over two clock domains

process (rxclk_div)
begin
	if rising_edge(rxclk_div) then
		if locked_out = '0' then
			bslip <= '0';
			bsstate <= 1;
			enable <= '0';
			bcount <= X"0";
			bs_finished <= '0';
		else
			enable <= '1';

			if enable = '1' then
				if clk_iserdes_data(7 downto 8-N) /= CLK_PATTERN_0 then flag1 <= '1'; else flag1 <= '0'; end if;
				if clk_iserdes_data(7 downto 8-N) /= CLK_PATTERN_1 then flag2 <= '1'; else flag2 <= '0'; end if;

				if bsstate = 0 then
					if flag1 = '1' and flag2 = '1' then
						bslip <= '1';						-- bitslip needed
						bsstate <= 1;
					else
						bs_finished <= '1';					-- bitslip done
					end if;
				elsif bsstate = 1 then							-- wait for bitslip ack from other clock domain
					bslip <= '0';
					bcount <= bcount + 1;
					if bcount = "1111" then
						bsstate <= 0;
					end if;
			   end if;
			end if;
		end if;
	end if;
end process;

-- Clock input

iob_clk_in : IBUFGDS
generic map (
	DIFF_TERM 		=> DIFF_TERM
)
port map (
	I    			=> clkin_p,
	IB       		=> clkin_n,
	O         		=> rx_clk_in
);

rx_clk	<= rx_clk_in when INVERT_CLK = FALSE else not rx_clk_in;

idelay_cm : IDELAYE2
generic map(
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 1,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map (
	DATAOUT			=> rx_clk_in_d,
	C				=> rxclk_div,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> rx_clk,
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> c_delay_in,
	CNTVALUEOUT		=> open
);

not_rxclk <= not rxclk;

iserdes_cm : ISERDESE2
generic map (
	DATA_WIDTH     		=> N,
	DATA_RATE      		=> "SDR",
	SERDES_MODE    		=> "MASTER",
	IOBDELAY	    	=> "IFD",
	INTERFACE_TYPE 		=> "NETWORKING"
)
port map (
	D       		=> rx_clk,
	DDLY     		=> rx_clk_in_d,
	CE1     		=> '1',
	CE2     		=> '1',
	CLK    			=> rxclk,
	CLKB    		=> not_rxclk,
	RST     		=> local_reset,
	CLKDIV  		=> rxclk_div,
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

process (rxclk_div)
begin
	if rising_edge(rxclk_div) then					-- retiming
		clk_iserdes_data_d <= clk_iserdes_data;

		if (clk_iserdes_data(7 downto 8-N) /= clk_iserdes_data_d(7 downto 8-N)) and or(clk_iserdes_data(7 downto 8-N)) /= '0' and and(clk_iserdes_data(7 downto 8-N)) /= '1' then
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

process (rxclk_div)
begin
	if rising_edge(rxclk_div) then					-- clock delay shift state machine
		if local_reset = '1' then
			scount <= "000000";
			state2 <= 0;
			state2_count <= X"0";
			locked_out <= '0';
			chfoundc <= '1';
			c_delay_in <= bt_val;							-- Start the delay line at the current bit period
			c_loop_cnt <= "00";
		else
			if scount(5) = '0' then
				if no_clock = '0' then
					scount <= scount + 1;
				else
					scount <= "000000";
				end if;
			end if;

			state2_count <= state2_count + 1;

			if chfoundc = '1' then
				chfound <= '0';
			elsif chfound = '0' and data_different = '1' then
				chfound <= '1';
			end if;

			if (state2_count = "1111" and scount(5) = '1') then
				case (state2) is
				when 0	=>							-- decrement delay and look for a change
					  if chfound = '1' or (c_loop_cnt = "11" and c_delay_in = "00000") then  -- quit loop if we've been around a few times
						chfoundc <= '1';
						state2 <= 1;
					  else
						chfoundc <= '0';
						c_delay_in <= c_delay_in - 1;
						if c_delay_in /= "00000" then			-- check for underflow
							c_delay_in <= c_delay_in - 1;
						else
							c_delay_in <= bt_val;
							c_loop_cnt <= c_loop_cnt + 1;
						end if;
					  end if;
				when 1	=>							-- add half a bit period using input information
					  state2 <= 2;						-- choose the lowest delay value to minimise jitter
					  if c_delay_in < '0' & bt_val(4 downto 1) then
						c_delay_in <= c_delay_in + ('0' & bt_val(4 downto 1));
					  else
						c_delay_in <= c_delay_in - ('0' & bt_val(4 downto 1));
					  end if;
				when others =>							-- issue locked out signal and wait for a manual command (if required)
					  locked_out <= '1';
				end case;
			end   if;
		end if;
	end if;
end process;

loop3 : for i in 0 to D-1 generate

dc_inst : entity work.delay_controller_wrap
generic map (
	S 	=> N
)
port map (
	m_datain				=> mdataout(8*(i+1)-1 downto 8*(i+1)-N),
	s_datain				=> sdataout(8*(i+1)-1 downto 8*(i+1)-N),
	enable_phase_detector	=> enable_phase_detector,
	enable_monitor			=> enable_monitor,
	reset					=> not_bs_finished,
	clk						=> rxclk_div,
	c_delay_in				=> c_delay_in,
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
	DIFF_TERM 		=> DIFF_TERM
)
port map (
	I    			=> datain_p(i),
	IB       		=> datain_n(i),
	O         		=> rx_data_in_p(i),
	OB         		=> rx_data_in_n(i)
);

rx_data_in_m(i) <= rx_data_in_p(i)  xor INVERT_DATA(i);
rx_data_in_s(i) <= not rx_data_in_n(i) xor INVERT_DATA(i);

idelay_m : IDELAYE2
generic map (
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 0,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map (
	DATAOUT			=> rx_data_in_md(i),
	C				=> rxclk_div,
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
	DATA_WIDTH     		=> N,
	DATA_RATE      		=> "SDR",
	SERDES_MODE    		=> "MASTER",
	IOBDELAY	    	=> "IFD",
	INTERFACE_TYPE 		=> "NETWORKING"
)
port map (
	D       		=> '0',
	DDLY     		=> rx_data_in_md(i),
	CE1     		=> '1',
	CE2     		=> '1',
	CLK	   			=> rxclk,
	CLKB    		=> not_rxclk,
	RST     		=> rst_iserdes,
	CLKDIV  		=> rxclk_div,
	CLKDIVP  		=> '0',
	OCLK    		=> '0',
	OCLKB    		=> '0',
	DYNCLKSEL    	=> '0',
	DYNCLKDIVSEL 	=> '0',
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
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 0,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map (
	DATAOUT			=> rx_data_in_sd(i),
	C				=> rxclk_div,
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
	DATA_WIDTH     		=> N,
	DATA_RATE      		=> "SDR",
--	SERDES_MODE    		=> "MASTER",
	IOBDELAY	    	=> "IFD",
	INTERFACE_TYPE 		=> "NETWORKING"
)
port map (
	D       		=> '0',
	DDLY     		=> rx_data_in_sd(i),
	CE1     		=> '1',
	CE2     		=> '1',
	CLK	   			=> rxclk,
	CLKB    		=> not_rxclk,
	RST     		=> rst_iserdes,
	CLKDIV  		=> rxclk_div,
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

end arch_serdes_1_to_N_slave_idelay_sdr;