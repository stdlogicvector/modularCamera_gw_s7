------------------------------------------------------------------------------
-- Copyright (c) 2012 Xilinx, Inc.
-- This design is confidential and proprietary of Xilinx, All Rights Reserved.
------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /   Vendor:                Xilinx
-- \   \   \/    Version:               1.0
--  \   \        Filename:              serdes_1_to_468_idelay_ddr.v
--  /   /        Date Last Modified:    Mar 30, 2016
-- /___/   /\    Date Created:          Mar 5, 2011
-- \   \  /  \
--  \___\/\___\
-- 
--Device: 	7 Series
--Purpose:  	1 to 4 DDR data receiver.
--		Data formatting is set by the DATA_FORMAT parameter. 
--		PER_CLOCK (default) format receives bits for 0, 1, 2 .. on the same sample edge
--		PER_CHANL format receives bits for 0, 4, 8 ..  on the same sample edge
--
--Reference:	
--    
--Revision History:
--    Rev 1.0 - First created (nicks)
--
------------------------------------------------------------------------------
--
--  Disclaimer: 
--
--		This disclaimer is not a license and does not grant any rights to the materials 
--              distributed herewith. Except as otherwise provided in a valid license issued to you 
--              by Xilinx, and to the maximum extent permitted by applicable law: 
--              (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, 
--              AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, 
--              INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR 
--              FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable (whether in contract 
--              or tort, including negligence, or under any other theory of liability) for any loss or damage 
--              of any kind or nature related to, arising under or in connection with these materials, 
--              including for any direct, or any indirect, special, incidental, or consequential loss 
--              or damage (including loss of data, profits, goodwill, or any type of loss or damage suffered 
--              as a result of any action brought by a third party) even if such damage or loss was 
--              reasonably foreseeable or Xilinx had been advised of the possibility of the same.
--
--  Critical Applications:
--
--		Xilinx products are not designed or intended to be fail-safe, or for use in any application 
--		requiring fail-safe performance, such as life-support or safety devices or systems, 
--		Class III medical devices, nuclear facilities, applications related to the deployment of airbags,
--		or any other applications that could lead to death, personal injury, or severe property or 
--		environmental damage (individually and collectively, "Critical Applications"). Customer assumes 
--		the sole risk and liability of any use of Xilinx products in Critical Applications, subject only 
--		to applicable laws and regulations governing limitations on product liability.
--
--  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
--
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

entity serdes_1_to_468_idelay_ddr is
generic (
	S 						: integer := 8;								-- Set the serdes factor to 4, 6 or 8
	D 						: integer := 8;								-- Set the number of inputs
 	BITRATE					: integer := 320;
 	DCD_CORRECT				: boolean := false;
	REF_FREQ 				: real := 200.0;   							-- Parameter to set reference frequency used by idelay controller
 	HIGH_PERFORMANCE_MODE 	: string := "FALSE";						-- Parameter to set HIGH_PERFORMANCE_MODE of input delays to reduce jitter
 	MSB_FIRST				: boolean := false;
	DATA_FORMAT 			: string := "PER_CLOCK";					-- Used to determine method for mapping input parallel word to output serial words
	IOSTANDARD				: string := "LVDS_25";
	DIFF_TERM				: boolean := false;
	INVERT_CLK				: boolean := false;							-- Invert clock
	RX_SWAP_MASK 			: std_logic_vector(D-1 downto 0) := (others => '0')	-- pinswap mask for input data bits (0 = no swap (default), 1 = swap). Allows inputs to be connected the wrong way round to ease PCB routing.
);
port (
	clkin_p					: in  std_logic;							-- Input from LVDS clock pin
	clkin_n					: in  std_logic;							-- Input from LVDS clock pin
	datain_p				: in  std_logic_vector(D-1 downto 0);		-- Input from LVDS receiver pin
	datain_n				: in  std_logic_vector(D-1 downto 0);		-- Input from LVDS receiver pin
	enable_phase_detector	: in  std_logic;							-- Enables the phase detector logic when high
	enable_monitor			: in  std_logic;							-- Enables the monitor logic when high, note time-shared with phase detector function
	reset					: in  std_logic;							-- Reset line
	bitslip					: in  std_logic_vector(D-1 downto 0);		-- bitslip 
	idelay_rdy				: in  std_logic;							-- input delays are ready
	rxclk					: out std_logic;							-- Global/BUFIO rx clock network
	system_clk				: out std_logic;							-- Global/Regional clock output
	system_clk_2x			: out std_logic;							-- Global/Regional clock output
	rx_lckd					: out std_logic;							-- 
	rx_data					: out std_logic_vector((S*D)-1 downto 0);	-- Output data
	bit_time_value			: out std_logic_vector(4 downto 0);			-- Calculated bit time value for slave devices
	debug					: out std_logic_vector(10*D+18 downto 0); 	-- Debug bus
	eye_info				: out std_logic_vector(32*D-1 downto 0);  	-- Eye info
	m_delay_1hot			: out std_logic_vector(32*D-1 downto 0);  	-- Master delay control value as a one-hot vector
	clock_sweep				: out std_logic_vector(31 downto 0)  		-- clock Eye info
);
		
end serdes_1_to_468_idelay_ddr;

architecture arch_serdes_1_to_468_idelay_ddr of serdes_1_to_468_idelay_ddr is

signal	m_delay_val_in		: std_logic_vector(5*D-1 downto 0);
signal	s_delay_val_in		: std_logic_vector(5*D-1 downto 0);
signal	m_delay_val_out		: std_logic_vector(5*D-1 downto 0);
signal	s_delay_val_out		: std_logic_vector(5*D-1 downto 0);
signal	cdataout			: std_logic_vector(3 downto 0);
signal	clk_iserdes_data_d	: std_logic_vector(3 downto 0);
signal	state2_count		: std_logic_vector(4 downto 0) := "00000";
signal	rx_lckd_intd4		: std_logic;
signal	not_rx_lckd_intd4	: std_logic;
signal	rx_data_in_p		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_n		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_m		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_s		: std_logic_vector(D-1 downto 0);		
signal	rx_data_in_md		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_sd		: std_logic_vector(D-1 downto 0);
signal	mdataout			: std_logic_vector(S*D-1 downto 0);			
signal	mdataoutd			: std_logic_vector(S*D-1 downto 0);			
signal	sdataout			: std_logic_vector(S*D-1 downto 0);			
signal	s_serdes			: std_logic_vector(8*D-1 downto 0);			
signal	m_serdes			: std_logic_vector(8*D-1 downto 0);			
signal	system_clk_int		: std_logic;
signal	system_clk_int_2x	: std_logic;
signal	data_different		: std_logic;
signal	bt_val				: std_logic_vector(4 downto 0);
signal	su_locked			: std_logic;
signal	m_count				: std_logic_vector(5 downto 0);
signal	c_sweep_delay		: std_logic_vector(4 downto 0) := "00000";
signal	temp_shift			: std_logic_vector(31 downto 0);
signal	rx_clk_in_p			: std_logic;
signal	rx_clk_in_pc		: std_logic;
signal	rx_clk_in_pd		: std_logic;
signal	rxclk_int			: std_logic;
signal	rst_iserdes			: std_logic;
signal	not_rxclk			: std_logic;
signal	clock_sweep_int		: std_logic_vector(31 downto 0);
signal	zflag				: std_logic;
signal	del_mech			: std_logic;
signal	bt_val_d2			: std_logic_vector(4 downto 0);
signal	del_debug			: std_logic_vector(2*D-1 downto 0);
signal	initial_delay		: std_logic_vector(4 downto 0);

begin

debug			<= "0000000" & del_debug(1 downto 0) & cdataout & s_delay_val_out & m_delay_val_out & or(bitslip) & initial_delay;
rx_lckd			<= not not_rx_lckd_intd4 and su_locked;
bit_time_value	<= bt_val;
system_clk		<= system_clk_int;
system_clk_2x	<= system_clk_int_2x;
not_rxclk		<= not rxclk_int;
clock_sweep 	<= clock_sweep_int;
rxclk			<= rxclk_int;
bt_val_d2		<= '0' & bt_val(4 downto 1);

loop11a : if REF_FREQ <= 210.0 generate				-- Generate tap number to be used for input bit rate (200 MHz ref clock)
bt_val <= "00111" when BITRATE > 1984 else
          "01000" when BITRATE > 1717 else
          "01001" when BITRATE > 1514 else
          "01010" when BITRATE > 1353 else
          "01011" when BITRATE > 1224 else
          "01100" when BITRATE > 1117 else
          "01101" when BITRATE > 1027 else
          "01110" when BITRATE > 951 else
          "01111" when BITRATE > 885 else
          "10000" when BITRATE > 828 else
          "10001" when BITRATE > 778 else
          "10010" when BITRATE > 733 else
          "10011" when BITRATE > 694 else
          "10100" when BITRATE > 658 else
          "10101" when BITRATE > 626 else
          "10110" when BITRATE > 597 else
          "10111" when BITRATE > 570 else
          "11000" when BITRATE > 546 else
          "11001" when BITRATE > 524 else
          "11010" when BITRATE > 503 else
          "11011" when BITRATE > 484 else
          "11100" when BITRATE > 466 else
          "11101" when BITRATE > 450 else
          "11110" when BITRATE > 435 else  
          "11111";     					-- min bit rate 420 Mbps

del_mech <= '1' when bt_val < "10110" else '0'; 		-- adjust delay mechanism when tap values are low enough 

end generate;

loop11b : if REF_FREQ > 210.0 generate				-- Generate tap number to be used for input bit rate (300 MHz ref clock) 
bt_val <= "01010" when (DCD_CORRECT = false and BITRATE > 2030) or (DCD_CORRECT = true and BITRATE > 1845)else
          "01011" when (DCD_CORRECT = false and BITRATE > 1836) or (DCD_CORRECT = true and BITRATE > 1669)else
          "01100" when (DCD_CORRECT = false and BITRATE > 1675) or (DCD_CORRECT = true and BITRATE > 1523)else
          "01101" when (DCD_CORRECT = false and BITRATE > 1541) or (DCD_CORRECT = true and BITRATE > 1401)else
          "01110" when (DCD_CORRECT = false and BITRATE > 1426) or (DCD_CORRECT = true and BITRATE > 1297)else
          "01111" when (DCD_CORRECT = false and BITRATE > 1328) or (DCD_CORRECT = true and BITRATE > 1207)else
          "10000" when (DCD_CORRECT = false and BITRATE > 1242) or (DCD_CORRECT = true and BITRATE > 1129)else
          "10001" when (DCD_CORRECT = false and BITRATE > 1167) or (DCD_CORRECT = true and BITRATE > 1061)else
          "10010" when (DCD_CORRECT = false and BITRATE > 1100) or (DCD_CORRECT = true and BITRATE >  999)else
          "10011" when (DCD_CORRECT = false and BITRATE > 1040) or (DCD_CORRECT = true and BITRATE >  946)else
          "10100" when (DCD_CORRECT = false and BITRATE >  987) or (DCD_CORRECT = true and BITRATE >  897)else
          "10101" when (DCD_CORRECT = false and BITRATE >  939) or (DCD_CORRECT = true and BITRATE >  853)else
          "10110" when (DCD_CORRECT = false and BITRATE >  895) or (DCD_CORRECT = true and BITRATE >  814)else
          "10111" when (DCD_CORRECT = false and BITRATE >  855) or (DCD_CORRECT = true and BITRATE >  777)else
          "11000" when (DCD_CORRECT = false and BITRATE >  819) or (DCD_CORRECT = true and BITRATE >  744)else
          "11001" when (DCD_CORRECT = false and BITRATE >  785) or (DCD_CORRECT = true and BITRATE >  714)else
          "11010" when (DCD_CORRECT = false and BITRATE >  754) or (DCD_CORRECT = true and BITRATE >  0686)else
          "11011" when (DCD_CORRECT = false and BITRATE >  726) or (DCD_CORRECT = true and BITRATE >  660)else
          "11100" when (DCD_CORRECT = false and BITRATE >  700) or (DCD_CORRECT = true and BITRATE >  636)else
          "11101" when (DCD_CORRECT = false and BITRATE >  675) or (DCD_CORRECT = true and BITRATE >  614)else
          "11110" when (DCD_CORRECT = false and BITRATE >  652) or (DCD_CORRECT = true and BITRATE >  593)else
          "11111";     					-- min bit rate 631 Mbps

del_mech <= '1' when bt_val < "10110" else '0';  		-- adjust delay mechanism when tap values are low enough 

end generate;

-- Clock input 

iob_clk_in : IBUFGDS
generic map (
	IBUF_LOW_PWR	=> FALSE,
	IOSTANDARD		=> IOSTANDARD,
	DIFF_TERM		=> DIFF_TERM
)
port map (                     
	I    			=> clkin_p,
	IB       		=> clkin_n,
	O         		=> rx_clk_in_p
);

idelay_cm : IDELAYE2
generic map (
	REFCLK_FREQUENCY 		=> REF_FREQ,
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 1,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map(                
	DATAOUT			=> rx_clk_in_pd,
	C				=> system_clk_int,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> rx_clk_in_p when INVERT_CLK = false else not rx_clk_in_p,
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> "00000", --c_sweep_delay,
	CNTVALUEOUT		=> open
);
		
iserdes_cm : ISERDESE2
generic map (
	DATA_WIDTH     	=> S, 			
	DATA_RATE      	=> "DDR", 		
	SERDES_MODE    	=> "MASTER", 		
	IOBDELAY	    => "IFD", 		
	INTERFACE_TYPE 	=> "NETWORKING"
) 	
port map (                      
	D       		=> rx_clk_in_p,
	DDLY     		=> rx_clk_in_pd,
	CE1     		=> '1',
	CE2     		=> '1',
	CLK	   			=> rxclk_int,
	CLKB    		=> not_rxclk,
	RST     		=> rst_iserdes,
	CLKDIV  		=> system_clk_int,
	CLKDIVP  		=> '0',
	OCLK    		=> '0',
	OCLKB    		=> '0',
	DYNCLKSEL    	=> '0',
	DYNCLKDIVSEL  	=> '0',
	SHIFTIN1 		=> '0',
	SHIFTIN2 		=> '0',
	BITSLIP 		=> '0',
	O	 			=> rx_clk_in_pc,
	Q8  			=> open,
	Q7  			=> open,
	Q6  			=> open,
	Q5  			=> open,
	Q4  			=> cdataout(0),
	Q3  			=> cdataout(1),
	Q2  			=> cdataout(2),
	Q1  			=> cdataout(3),
	OFB 			=> '0',
	SHIFTOUT1		=> open,
	SHIFTOUT2 		=> open
);  	
      
bufio_mmcm_xn : BUFIO
port map (
	I => rx_clk_in_pc,
	O => rxclk_int
);

-- instantiate BUFR with correct division ratio
	
loop2a : if S = 4 generate
bufr_d : BUFR
	generic map (
		BUFR_DIVIDE	=> "2",
		SIM_DEVICE	=> "7SERIES"
	)
	port map (
		I	=> rx_clk_in_pc,
		CE	=> '1',
		O	=> system_clk_int,
		CLR => '0'
	);
end generate;

loop2b : if S = 6 generate
bufr_d : BUFR
	generic map (
		BUFR_DIVIDE	=> "3",
		SIM_DEVICE	=> "7SERIES"
	)
	port map (
		I	=> rx_clk_in_pc,
		CE	=> '1',
		O	=> system_clk_int,
		CLR => '0'
	);
end generate;

loop2c : if S = 8 generate
bufr_d_2x : BUFR
	generic map (
		BUFR_DIVIDE	=> "2",
		SIM_DEVICE	=> "7SERIES"
	)
	port map (
		I	=> rx_clk_in_pc,
		CE	=> '1',
		O	=> system_clk_int_2x,
		CLR => '0'
	);

bufr_d : BUFR
	generic map (
		BUFR_DIVIDE	=> "4",
		SIM_DEVICE	=> "7SERIES"
	)
	port map (
		I	=> rx_clk_in_pc,
		CE	=> '1',
		O	=> system_clk_int,
		CLR => '0'
	);
end generate;
  
process (system_clk_int, reset, idelay_rdy)
begin
	if reset = '1' or idelay_rdy = '0' then
		su_locked <= '0';
		m_count <= "000000";
		rst_iserdes <= '1';
	elsif rising_edge(system_clk_int) then			-- startup delay
		if m_count = "111100" then
			rst_iserdes <= '0';
			m_count <= m_count + 1;
		elsif m_count = "111111" then
			su_locked <= '1';
		else 
			m_count <= m_count + 1;
		end if;
	end if;
end process;
  
 
process (system_clk_int)
begin
	if rising_edge(system_clk_int) then
		if su_locked = '0' then
			c_sweep_delay <= "00000";
			temp_shift <= (0 => '1', others => '0');
			clock_sweep_int <= (others => '0');
			zflag <= '0';
			not_rx_lckd_intd4 <= '1';
			rx_lckd_intd4 <= '0';
			initial_delay <= "00000";
		else 
			not_rx_lckd_intd4 <= not rx_lckd_intd4;
			
			if state2_count = "11111" then
				if c_sweep_delay /= bt_val then
					if zflag = '0' then
						c_sweep_delay <= c_sweep_delay + 1;
						temp_shift <= temp_shift(30 downto 0) & temp_shift(31);
					else
						zflag <= '0';
					end if;
				else 
					c_sweep_delay <= "00000"; 
					zflag <= '1';					-- need to check tap 0 twice bacause of wraparound
					temp_shift <= (0 => '1', others => '0');
				end if;
				
				if zflag = '0' then
					if data_different = '1' then
						clock_sweep_int <= clock_sweep_int and not temp_shift;
						
						if initial_delay = "00000" then
							rx_lckd_intd4 <= '1';
							if c_sweep_delay < '0' & bt_val(4 downto 1) then		-- choose the lowest delay value to minimise jitter
								initial_delay <= c_sweep_delay + ('0' & bt_val(4 downto 1));
							else 
								initial_delay <= c_sweep_delay - ('0' & bt_val(4 downto 1));
							end if;
						end if;
					else 
						clock_sweep_int <= clock_sweep_int or temp_shift;
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

process (system_clk_int) begin							-- sweep data
	if rising_edge(system_clk_int) then
		if su_locked = '0' then
			state2_count <= "00000";	
		else
			state2_count <= state2_count + 1;
			if state2_count = "00000" then
				clk_iserdes_data_d <= cdataout;
			elsif state2_count <= "01000" then
				data_different <= '0';
			elsif cdataout /= clk_iserdes_data_d then
				data_different <= '1';
			end if;
		end if;
	end if;
end process;
	
loop3 : for i in 0 to D-1 generate

dc_inst : entity work.delay_controller_wrap
generic map (
	S 						=> S
)
port map (                       
	m_datain				=> mdataout(S*i+S-1 downto S*i),
	s_datain				=> sdataout(S*i+S-1 downto S*i),
	enable_phase_detector	=> enable_phase_detector,
	enable_monitor			=> enable_monitor,
	reset					=> not_rx_lckd_intd4,
	clk						=> system_clk_int,
	c_delay_in				=> initial_delay,
	m_delay_out				=> m_delay_val_in(5*i+4 downto 5*i),
	s_delay_out				=> s_delay_val_in(5*i+4 downto 5*i),
	data_out				=> mdataoutd(S*i+S-1 downto S*i),
	bt_val					=> bt_val,
	del_mech				=> del_mech,
	debug					=> del_debug(i*2+1 downto i*2),
	m_delay_1hot			=> m_delay_1hot(32*i+31 downto 32*i),
	results					=> eye_info(32*i+31 downto 32*i)
);

end generate;
	
-- Data bit Receivers 

loop0 : for i in 0 to D-1 generate

	loop1 : for j in 0 to S-1 generate			-- Assign data bits to correct serdes according to required format
		
		msb : if MSB_FIRST = false generate
			loop1a : if DATA_FORMAT = "PER_CLOCK" generate
				rx_data(D*j+i) <= mdataoutd(S*i+j);
			end generate;
			
			loop1b : if DATA_FORMAT = "PER_CHANL" generate
				rx_data(S*i+j) <= mdataoutd(S*i+j);
			end generate;
		else generate
			loop1a : if DATA_FORMAT = "PER_CLOCK" generate
				rx_data(D*j+i) <= mdataoutd(S*i+S-j-1);
			end generate;
			
			loop1b : if DATA_FORMAT = "PER_CHANL" generate
				rx_data(S*i+j) <= mdataoutd(S*i+S-j-1);
			end generate;
		end generate;
	end generate;
	
data_in : IBUFDS_DIFF_OUT
generic map (
	IBUF_LOW_PWR	=> FALSE,
	IOSTANDARD		=> IOSTANDARD,
	DIFF_TERM		=> DIFF_TERM
)
port map (                      
	I    			=> datain_p(i),
	IB       		=> datain_n(i),
	O         		=> rx_data_in_p(i),
	OB         		=> rx_data_in_n(i));

rx_data_in_m(i) <= rx_data_in_p(i) xor RX_SWAP_MASK(i);
rx_data_in_s(i) <= rx_data_in_n(i) xor RX_SWAP_MASK(i);

idelay_m : IDELAYE2
generic map (
	REFCLK_FREQUENCY 		=> REF_FREQ,
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 0,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map (                
	DATAOUT			=> rx_data_in_md(i),
	C				=> system_clk_int,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> rx_data_in_m(i),
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> m_delay_val_in(5*i+4 downto 5*i),
	CNTVALUEOUT		=> m_delay_val_out(5*i+4 downto 5*i));

iserdes_m : ISERDESE2
generic map (
	DATA_WIDTH     	=> S, 			
	DATA_RATE      	=> "DDR", 		
	SERDES_MODE    	=> "MASTER", 		
	IOBDELAY	    => "IFD",
	DYN_CLK_INV_EN	=> "FALSE", 		
	INTERFACE_TYPE 	=> "NETWORKING"
) 	
port map (                      
	D       		=> '0',
	DDLY     		=> rx_data_in_md(i),
	CE1     		=> '1',
	CE2     		=> '1',
	CLK	   			=> rxclk_int,
	CLKB    		=> not_rxclk,
	RST     		=> rst_iserdes,
	CLKDIV  		=> system_clk_int,
	CLKDIVP  		=> '0',
	OCLK    		=> '0',
	OCLKB    		=> '0',
	DYNCLKSEL    	=> '0',
	DYNCLKDIVSEL  	=> '0',
	SHIFTIN1 		=> '0',
	SHIFTIN2 		=> '0',
	BITSLIP 		=> bitslip(i),
	O	 			=> open,
	Q8  			=> m_serdes(8*i+0),
	Q7  			=> m_serdes(8*i+1),
	Q6  			=> m_serdes(8*i+2),
	Q5  			=> m_serdes(8*i+3),
	Q4  			=> m_serdes(8*i+4),
	Q3  			=> m_serdes(8*i+5),
	Q2  			=> m_serdes(8*i+6),
	Q1  			=> m_serdes(8*i+7),
	OFB 			=> '0',
	SHIFTOUT1		=> open,
	SHIFTOUT2 		=> open
);

idelay_s : IDELAYE2
generic map (
	REFCLK_FREQUENCY 		=> REF_FREQ,
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 0,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map(                
	DATAOUT			=> rx_data_in_sd(i),
	C				=> system_clk_int,
	CE				=> '0',
	INC				=> '0',
	DATAIN			=> '0',
	IDATAIN			=> rx_data_in_s(i),
	LD				=> '1',
	LDPIPEEN		=> '0',
	REGRST			=> '0',
	CINVCTRL		=> '0',
	CNTVALUEIN		=> s_delay_val_in(5*i+4 downto 5*i),
	CNTVALUEOUT		=> s_delay_val_out(5*i+4 downto 5*i)
);

iserdes_s : ISERDESE2
generic map (
	DATA_WIDTH     	=> S, 			
	DATA_RATE      	=> "DDR", 		
--	SERDES_MODE    	=> "MASTER", 		
	IOBDELAY	    => "IFD", 		
	DYN_CLK_INV_EN	=> "FALSE", 		
	INTERFACE_TYPE 	=> "NETWORKING"
) 	
port map (                      
	D       		=> '0',
	DDLY     		=> rx_data_in_sd(i),
	CE1     		=> '1',
	CE2     		=> '1',
	CLK	   			=> rxclk_int,
	CLKB    		=> not_rxclk,
	RST     		=> rst_iserdes,
	CLKDIV  		=> system_clk_int,
	CLKDIVP  		=> '0',
	OCLK    		=> '0',
	OCLKB    		=> '0',
	DYNCLKSEL    	=> '0',
	DYNCLKDIVSEL  	=> '0',
	SHIFTIN1 		=> '0',
	SHIFTIN2 		=> '0',
	BITSLIP 		=> bitslip(i),
	O	 			=> open,
	Q8  			=> s_serdes(8*i+0),
	Q7  			=> s_serdes(8*i+1),
	Q6  			=> s_serdes(8*i+2),
	Q5  			=> s_serdes(8*i+3),
	Q4  			=> s_serdes(8*i+4),
	Q3  			=> s_serdes(8*i+5),
	Q2  			=> s_serdes(8*i+6),
	Q1  			=> s_serdes(8*i+7),
	OFB 			=> '0',
	SHIFTOUT1		=> open,
	SHIFTOUT2 		=> open
);

-- sort out necessary bits from iserdes
	
loop0a : if S = 4 generate
	mdataout(4*i+3 downto 4*i) <= m_serdes(8*i+7 downto 8*i+4);	
	sdataout(4*i+3 downto 4*i) <= not s_serdes(8*i+7 downto 8*i+4);
end generate;

loop0b : if S = 6 generate
	mdataout(6*i+5 downto 6*i) <= m_serdes(8*i+7 downto 8*i+2);	
	sdataout(6*i+5 downto 6*i) <= not s_serdes(8*i+7 downto 8*i+2);
end generate;

loop0c : if S = 8 generate
	mdataout(8*i+7 downto 8*i) <= m_serdes(8*i+7 downto 8*i);	
	sdataout(8*i+7 downto 8*i) <= not s_serdes(8*i+7 downto 8*i);
end generate;
  
end generate;

end arch_serdes_1_to_468_idelay_ddr;
