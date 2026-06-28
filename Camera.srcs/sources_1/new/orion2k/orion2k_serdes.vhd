library IEEE, UNISIM;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use unisim.vcomponents.all;

entity orion2k_serdes is
generic (
	S 						: integer := 8;								-- Set the serdes factor to 4, 6 or 8
	D 						: integer := 8;								-- Set the number of inputs
	REF_FREQ 				: real := 200.0;
 	HIGH_PERFORMANCE_MODE 	: string := "FALSE";
 	MSB_FIRST				: boolean := false;
	DATA_FORMAT 			: string := "PER_CLOCK";
	DATA_RATE				: string := "DDR";
	IOSTANDARD				: string := "LVDS_25";
	DIFF_TERM				: boolean := false;
	EXT_CLK					: boolean := true;
	INVERT_CLK				: boolean := false;							
	INVERT_DATA 			: std_logic_vector(D-1 downto 0) := (others => '0')
);
port (
	REFCLK_I				: in  std_logic;
	RST_I					: in  std_logic;
	
	CLKp_I					: in  std_logic;
	CLKn_I					: in  std_logic;
	DATAp_I					: in  std_logic_vector(D-1 downto 0);
	DATAn_I					: in  std_logic_vector(D-1 downto 0);
	
	BITSLIP_I				: in  std_logic_vector(D-1 downto 0);
	SYSCLK_O				: out std_logic;
	SYSCLKx2_O				: out std_logic;
	LOCKED_O				: out std_logic;
	DATA_O					: out std_logic_vector((S*D)-1 downto 0)
);
end orion2k_serdes;

architecture Behavioral of orion2k_serdes is

signal dly_ready			: std_logic;
signal refclkintbufg		: std_logic;

signal	c_delay_val_in		: std_logic_vector(5*1-1 downto 0) := (others => '0');
signal	m_delay_val_in		: std_logic_vector(5*D-1 downto 0) := (others => '0');
signal	s_delay_val_in		: std_logic_vector(5*D-1 downto 0) := (others => '0');

signal	rx_data_in_p		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_n		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_m		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_s		: std_logic_vector(D-1 downto 0);		
signal	rx_data_in_md		: std_logic_vector(D-1 downto 0);			
signal	rx_data_in_sd		: std_logic_vector(D-1 downto 0);

signal	s_serdes			: std_logic_vector(8*D-1 downto 0);			
signal	m_serdes			: std_logic_vector(8*D-1 downto 0);			

signal	cdataout			: std_logic_vector(3 downto 0);
signal	mdataout			: std_logic_vector(S*D-1 downto 0);			
signal	sdataout			: std_logic_vector(S*D-1 downto 0);			

signal	system_clk_int		: std_logic;
signal	system_clk_int_2x	: std_logic;

signal	rst_count			: std_logic_vector(5 downto 0);

signal	rx_clk_in_p			: std_logic;
signal	rx_clk_in_pc		: std_logic;
signal	rx_clk_in_pd		: std_logic;
signal	rxclk_int			: std_logic;
signal	reset				: std_logic;

begin

bufg_ref : BUFG
port map (
	I	=> REFCLK_I, 
	O	=> refclkintbufg
);
	
delayctrl : IDELAYCTRL
port map (
	REFCLK	=> refclkintbufg,
	RST		=> RST_I,
	RDY		=> dly_ready
);

SYSCLK_O	<= system_clk_int;
SYSCLKx2_O	<= system_clk_int_2x;

-- Clock input 

clk_src : IF EXT_CLK = TRUE generate

iob_clk_in : IBUFGDS
generic map (
	IBUF_LOW_PWR	=> FALSE,
	IOSTANDARD		=> IOSTANDARD,
	DIFF_TERM		=> DIFF_TERM
)
port map (                     
	I    			=> CLKp_I,
	IB       		=> CLKn_I,
	O         		=> rx_clk_in_p
);

idelay_cm : IDELAYE2
generic map (
	REFCLK_FREQUENCY 		=> REF_FREQ,
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 0,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map(                
	DATAOUT					=> rx_clk_in_pd,
	C						=> system_clk_int,
	CE						=> '0',
	INC						=> '0',
	DATAIN					=> '0',
	IDATAIN					=> rx_clk_in_p when INVERT_CLK = false else not rx_clk_in_p,
	LD						=> '1',
	LDPIPEEN				=> '0',
	REGRST					=> '0',
	CINVCTRL				=> '0',
	CNTVALUEIN				=> c_delay_val_in,
	CNTVALUEOUT				=> open
);
		
iserdes_cm : ISERDESE2
generic map (
	DATA_WIDTH     			=> S, 			
	DATA_RATE      			=> DATA_RATE, 		
	SERDES_MODE    			=> "MASTER", 		
	IOBDELAY	    		=> "IFD", 		
	INTERFACE_TYPE 			=> "NETWORKING"
) 	
port map (                      
	D       				=> rx_clk_in_p,
	DDLY     				=> rx_clk_in_pd,
	CE1     				=> '1',
	CE2     				=> '1',
	CLK	   					=> rxclk_int,
	CLKB    				=> not rxclk_int,
	RST     				=> reset,
	CLKDIV  				=> system_clk_int,
	CLKDIVP  				=> '0',
	OCLK    				=> '0',
	OCLKB    				=> '0',
	DYNCLKSEL    			=> '0',
	DYNCLKDIVSEL  			=> '0',
	SHIFTIN1 				=> '0',
	SHIFTIN2 				=> '0',
	BITSLIP 				=> '0',
	O	 					=> rx_clk_in_pc,
	Q8  					=> open,
	Q7  					=> open,
	Q6  					=> open,
	Q5  					=> open,
	Q4  					=> cdataout(0),
	Q3  					=> cdataout(1),
	Q2  					=> cdataout(2),
	Q1  					=> cdataout(3),
	OFB 					=> '0',
	SHIFTOUT1				=> open,
	SHIFTOUT2 				=> open
);  	
      
bufio_mmcm_xn : BUFIO
port map (
	I => rx_clk_in_pc,
	O => rxclk_int
);

else generate

rxclk_int 		<= CLKp_I;
rx_clk_in_pc	<= CLKp_I;

end generate;

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
  
process(RST_I, system_clk_int, dly_ready)
begin
	if RST_I = '1' or dly_ready = '0' then
		LOCKED_O	<= '0';
		rst_count	<= "000000";
		reset 		<= '1';
	elsif rising_edge(system_clk_int) then			-- startup delay
		if rst_count = "111100" then
			reset 		<= '0';
			rst_count	<= rst_count + 1;
		elsif rst_count = "111111" then
			LOCKED_O	<= '1';
		else 
			rst_count	<= rst_count + 1;
		end if;
	end if;
end process;
  
-- Data bit Receivers 

data : for i in 0 to D-1 generate
	
data_in : IBUFDS_DIFF_OUT
generic map (
	IBUF_LOW_PWR	=> FALSE,
	IOSTANDARD		=> IOSTANDARD,
	DIFF_TERM		=> DIFF_TERM
)
port map (                      
	I    			=> DATAp_I(i),
	IB       		=> DATAn_I(i),
	O         		=> rx_data_in_p(i),
	OB         		=> rx_data_in_n(i)
);

rx_data_in_m(i) <= rx_data_in_p(i) xor INVERT_DATA(i);
rx_data_in_s(i) <= rx_data_in_n(i) xor INVERT_DATA(i);

idelay_m : IDELAYE2
generic map (
	REFCLK_FREQUENCY 		=> REF_FREQ,
	HIGH_PERFORMANCE_MODE 	=> HIGH_PERFORMANCE_MODE,
	IDELAY_VALUE			=> 0,
	DELAY_SRC				=> "IDATAIN",
	IDELAY_TYPE				=> "VAR_LOAD"
)
port map (                
	DATAOUT					=> rx_data_in_md(i),
	C						=> system_clk_int,
	CE						=> '0',
	INC						=> '0',
	DATAIN					=> '0',
	IDATAIN					=> rx_data_in_m(i),
	LD						=> '1',
	LDPIPEEN				=> '0',
	REGRST					=> '0',
	CINVCTRL				=> '0',
	CNTVALUEIN				=> m_delay_val_in(5*i+4 downto 5*i),
	CNTVALUEOUT				=> open
);

iserdes_m : ISERDESE2
generic map (
	DATA_WIDTH     			=> S, 			
	DATA_RATE      			=> DATA_RATE, 		
	SERDES_MODE    			=> "MASTER", 		
	IOBDELAY	    		=> "IFD",
	DYN_CLK_INV_EN			=> "FALSE", 		
	INTERFACE_TYPE 			=> "NETWORKING"
) 	
port map (                      
	D       				=> '0',
	DDLY     				=> rx_data_in_md(i),
	CE1     				=> '1',
	CE2     				=> '1',
	CLK	   					=> rxclk_int,
	CLKB    				=> not rxclk_int,
	RST     				=> reset,
	CLKDIV  				=> system_clk_int,
	CLKDIVP  				=> '0',
	OCLK    				=> '0',
	OCLKB    				=> '0',
	DYNCLKSEL    			=> '0',
	DYNCLKDIVSEL  			=> '0',
	SHIFTIN1 				=> '0',
	SHIFTIN2 				=> '0',
	BITSLIP 				=> BITSLIP_I(i),
	O	 					=> open,
	Q8  					=> m_serdes(8*i+0),
	Q7  					=> m_serdes(8*i+1),
	Q6  					=> m_serdes(8*i+2),
	Q5  					=> m_serdes(8*i+3),
	Q4  					=> m_serdes(8*i+4),
	Q3  					=> m_serdes(8*i+5),
	Q2  					=> m_serdes(8*i+6),
	Q1  					=> m_serdes(8*i+7),
	OFB 					=> '0',
	SHIFTOUT1				=> open,
	SHIFTOUT2 				=> open
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
	DATAOUT					=> rx_data_in_sd(i),
	C						=> system_clk_int,
	CE						=> '0',
	INC						=> '0',
	DATAIN					=> '0',
	IDATAIN					=> rx_data_in_s(i),
	LD						=> '1',
	LDPIPEEN				=> '0',
	REGRST					=> '0',
	CINVCTRL				=> '0',
	CNTVALUEIN				=> s_delay_val_in(5*i+4 downto 5*i),
	CNTVALUEOUT				=> open
);

iserdes_s : ISERDESE2
generic map (
	DATA_WIDTH     			=> S,
	DATA_RATE      			=> DATA_RATE,
	IOBDELAY	    		=> "IFD",
	DYN_CLK_INV_EN			=> "FALSE",
	INTERFACE_TYPE 			=> "NETWORKING"
) 	
port map (                      
	D       				=> '0',
	DDLY     				=> rx_data_in_sd(i),
	CE1     				=> '1',
	CE2     				=> '1',
	CLK	   					=> rxclk_int,
	CLKB    				=> not rxclk_int,
	RST     				=> reset,
	CLKDIV  				=> system_clk_int,
	CLKDIVP  				=> '0',
	OCLK    				=> '0',
	OCLKB    				=> '0',
	DYNCLKSEL    			=> '0',
	DYNCLKDIVSEL  			=> '0',
	SHIFTIN1 				=> '0',
	SHIFTIN2 				=> '0',
	BITSLIP 				=> BITSLIP_I(i),
	O	 					=> open,
	Q8  					=> s_serdes(8*i+0),
	Q7  					=> s_serdes(8*i+1),
	Q6  					=> s_serdes(8*i+2),
	Q5  					=> s_serdes(8*i+3),
	Q4  					=> s_serdes(8*i+4),
	Q3  					=> s_serdes(8*i+5),
	Q2  					=> s_serdes(8*i+6),
	Q1  					=> s_serdes(8*i+7),
	OFB 					=> '0',
	SHIFTOUT1				=> open,
	SHIFTOUT2 				=> open
);

mdataout(S*(i+1)-1 downto S*i) <=     m_serdes(8*i+7 downto 8*i+(8-S));	
sdataout(S*(i+1)-1 downto S*i) <= not s_serdes(8*i+7 downto 8*i+(8-S));
  
data_order : for j in 0 to S-1 generate			-- Assign data bits to correct serdes according to required format
	
	msb : if MSB_FIRST = false generate
		perclk: if DATA_FORMAT = "PER_CLOCK" generate
			DATA_O(D*j+i) <= mdataout(S*i+j);
		end generate;
		
		perch : if DATA_FORMAT = "PER_CHANL" generate
			DATA_O(S*i+j) <= mdataout(S*i+j);
		end generate;
	else generate
		perclk : if DATA_FORMAT = "PER_CLOCK" generate
			DATA_O(D*j+i) <= mdataout(S*i+S-j-1);
		end generate;
		
		perch : if DATA_FORMAT = "PER_CHANL" generate
			DATA_O(S*i+j) <= mdataout(S*i+S-j-1);
		end generate;
	end generate;
end generate;
  
end generate;

end Behavioral;
