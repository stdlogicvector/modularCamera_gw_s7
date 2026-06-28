library IEEE, UNISIM;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use UNISIM.vcomponents.all;

entity n_x_serdes_1_to_N_mmcm_idelay_sdr is
generic (
	N						: integer := 7;							-- Set the Serdes Factor
	C 						: integer := 1;							-- Set the number of channels
	D 						: integer := 4;							-- Set the number of inputs
	SAMPL_CLOCK 			: string := "BUFIO";   					-- Parameter to set sampling clock buffer type, BUFIO, BUF_H, BUF_G
	PIXEL_CLOCK 			: string := "BUF_R";      				-- Parameter to set pixel clock buffer type, BUFR, BUF_H, BUF_G
	USE_PLL     			: boolean := FALSE;          			-- Parameter to enable PLL use rather than MMCM use, note, PLL does not support BUFIO and BUFR
	CLKIN_PERIOD			: real := 6.000;						-- clock period (ns) of input clock on clkin_p
	HIGH_PERFORMANCE_MODE 	: string := "FALSE";					-- Parameter to set HIGH_PERFORMANCE_MODE of input delays to reduce jitter
	MMCM_MODE				: integer := 1;							-- Parameter to set multiplier for MMCM to get VCO in correct operating range. 1 multiplies input clock by 7, 2 multiplies clock by 14, etc
	DIFF_TERM				: boolean := FALSE;						-- Enable or disable internal differential termination
	DATA_FORMAT 			: string := "PER_CLOCK";				-- Used to determine method for mapping input parallel word to output serial words
	CLK_PATTERN_0			: std_logic_vector(N-1 downto 0);
	CLK_PATTERN_1			: std_logic_vector(N-1 downto 0);
	INVERT_CLK				: boolean := FALSE;
	INVERT_DATA 			: std_logic_vector(D*C-1 downto 0) := (others => '0')	-- pinswap mask for input data bits (0 = no swap (default), 1 = swap). Allows inputs to be connected the wrong way round to ease PCB routing.
);
port (
	clkin_p					:  in std_logic_vector(C-1 downto 0);	-- Input from LVDS clock pin
	clkin_n					:  in std_logic_vector(C-1 downto 0);	-- Input from LVDS clock pin
	datain_p				:  in std_logic_vector(D*C-1 downto 0);	-- Input from LVDS receiver pin
	datain_n				:  in std_logic_vector(D*C-1 downto 0);	-- Input from LVDS receiver pin
	enable_phase_detector	:  in std_logic;						-- Enables the phase detector logic when high
	enable_monitor			:  in std_logic;						-- Enables the monitor logic when high, note time-shared with phase detector function
	reset					:  in std_logic;						-- Reset line
	idelay_rdy				:  in std_logic;						-- input delays are ready
	rxclk					: out std_logic;						-- Global/BUFIO rx clock network
	rxclk_div				: out std_logic;						-- Global/Regional clock output
	rx_mmcm_lckd			: out std_logic;						-- MMCM locked, synchronous to rxclk_div
	rx_mmcm_lckdps			: out std_logic;						-- MMCM locked and phase shifting finished, synchronous to rxclk_div
	rx_mmcm_lckdpsbs		: out std_logic_vector(C-1 downto 0);	-- MMCM locked and phase shifting finished and bitslipping finished, synchronous to rxclk_div
	clk_data				: out std_logic_vector(N*C-1 downto 0); -- received clock data
	rx_data					: out std_logic_vector((N*C*D)-1 downto 0);  	-- Output data
	bit_rate_value			:  in std_logic_vector(15 downto 0);	-- Bit rate in Mbps, eg 16'h0585
	bit_time_value			: out std_logic_vector(4 downto 0);		-- Calculated bit time value for slave devices
	status					: out std_logic_vector(6 downto 0);		-- Status bus
	eye_info				: out std_logic_vector(32*D*C-1 downto 0);  	-- Eye info
	m_delay_1hot			: out std_logic_vector(32*D*C-1 downto 0);  	-- Master delay control value as a one-hot vector
	debug					: out std_logic_vector((10*D+6)*C-1 downto 0) -- Debug bus
);
end n_x_serdes_1_to_N_mmcm_idelay_sdr;
		
architecture arch_n_x_serdes_1_to_N_mmcm_idelay_sdr of n_x_serdes_1_to_N_mmcm_idelay_sdr is
                                        	
signal	rxclk_int	 		: std_logic;
signal	not_rx_mmcm_lckdps 	: std_logic;
signal	rxclk_div_int	 	: std_logic;
signal	rx_mmcm_lckdps_int 	: std_logic;
signal	bit_time_value_int	: std_logic_vector(4 downto 0);
signal	rst_iserdes	 		: std_logic;

begin

rxclk <= rxclk_int;
rxclk_div <= rxclk_div_int;
rx_mmcm_lckdps <= rx_mmcm_lckdps_int;
bit_time_value <= bit_time_value_int;

rx0 : entity work.serdes_1_to_N_mmcm_idelay_sdr
generic map (
	N						=> N,
	D						=> D,
	SAMPL_CLOCK				=> SAMPL_CLOCK,
	PIXEL_CLOCK				=> PIXEL_CLOCK,
	USE_PLL					=> USE_PLL,
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	CLKIN_PERIOD			=> CLKIN_PERIOD,		
	MMCM_MODE				=> MMCM_MODE,				
	DIFF_TERM				=> DIFF_TERM,
	DATA_FORMAT 			=> DATA_FORMAT,
	CLK_PATTERN_0			=> CLK_PATTERN_0,
	CLK_PATTERN_1			=> CLK_PATTERN_1,
	INVERT_CLK				=> INVERT_CLK,
	INVERT_DATA				=> INVERT_DATA(D-1 downto 0)
)
port map (                      
	clkin_p   				=> clkin_p(0),
	clkin_n   				=> clkin_n(0),
	datain_p     			=> datain_p(D-1 downto 0),
	datain_n     			=> datain_n(D-1 downto 0),
	enable_phase_detector	=> enable_phase_detector,
	enable_monitor			=> enable_monitor,
	rxclk    				=> rxclk_int,
	idelay_rdy				=> idelay_rdy,
	rxclk_div				=> rxclk_div_int,
	reset     				=> reset,
	rx_mmcm_lckd			=> rx_mmcm_lckd,
	rx_mmcm_lckdps			=> rx_mmcm_lckdps_int,
	rx_mmcm_lckdpsbs		=> rx_mmcm_lckdpsbs(0),
	clk_data  				=> clk_data(N-1 downto 0),
	rx_data					=> rx_data(N*D-1 downto 0),
	bit_rate_value			=> bit_rate_value,
	bit_time_value			=> bit_time_value_int,
	rst_iserdes				=> rst_iserdes,
	status					=> status,
	eye_info				=> eye_info(32*D-1 downto 0),
	m_delay_1hot			=> m_delay_1hot(32*D-1 downto 0),
	debug					=> debug(10*D+5 downto 0)
);

not_rx_mmcm_lckdps <= not rx_mmcm_lckdps_int;

loop1 : if (C > 1) generate begin
loop0 : for i in 1 to C-1 generate begin

rxn : entity work.serdes_1_to_N_slave_idelay_sdr
generic map (
	N						=> N,
	D						=> D,				-- Number of data lines
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	DIFF_TERM				=> DIFF_TERM,
	DATA_FORMAT 			=> DATA_FORMAT,
	CLK_PATTERN_0			=> CLK_PATTERN_0,
	CLK_PATTERN_1			=> CLK_PATTERN_1,
	INVERT_DATA				=> INVERT_DATA(D*(i+1)-1 downto D*i)
)
port map (                      
	clkin_p   				=> clkin_p(i),
	clkin_n   				=> clkin_n(i),
	datain_p     			=> datain_p(D*(i+1)-1 downto D*i),
	datain_n     			=> datain_n(D*(i+1)-1 downto D*i),
	enable_phase_detector	=> enable_phase_detector,
	enable_monitor			=> enable_monitor,
	rxclk    				=> rxclk_int,
	idelay_rdy				=> idelay_rdy,
	rxclk_div				=> rxclk_div_int,
	reset     				=> not_rx_mmcm_lckdps,
	bitslip_finished		=> rx_mmcm_lckdpsbs(i),
	clk_data  				=> clk_data(N*(i+1)-1 downto N*i),
	rx_data					=> rx_data((D*(i+1)*N)-1 downto D*i*N),
	bit_time_value			=> bit_time_value_int,
	rst_iserdes				=> rst_iserdes,
	eye_info				=> eye_info(32*D*(i+1)-1 downto 32*D*i),
	m_delay_1hot			=> m_delay_1hot((32*D)*(i+1)-1 downto (32*D)*i),
	debug					=> debug((10*D+6)*(i+1)-1 downto (10*D+6)*i)
);
	
end generate;
end generate;

end arch_n_x_serdes_1_to_N_mmcm_idelay_sdr;
