library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.vcomponents.all;
use work.util.all;

entity clk_gen is
	Generic (
		CLK_IN_PERIOD	: real			:= 20.0;
		DIFF_CLK_IN		: boolean		:= false;
		BUF_CLK_IN		: boolean		:= false;
		CLKFB_MULT		: real			:= 20.0;
		DIVCLK_DIVIDE	: integer		:= 1;           			-- Master division value (1-106)
		CLK_OUT_DIVIDE	: real_vector(6 downto 0) := (others => 0.0)
	);
	Port (
		CLK_Ip		: in	STD_LOGIC;
		CLK_In		: in	STD_LOGIC := '0';
		
		LOCKED_O	: out	STD_LOGIC := '0';
		
		CLK0_O		: out	STD_LOGIC := '0';
		CLK1_O		: out	STD_LOGIC := '0';
		CLK2_O		: out	STD_LOGIC := '0';
		CLK3_O		: out	STD_LOGIC := '0';
		CLK4_O		: out	STD_LOGIC := '0';
		CLK5_O		: out	STD_LOGIC := '0';
		CLK6_O		: out	STD_LOGIC := '0'
	);
end clk_gen;

architecture Behavioral of clk_gen is

signal in_clk	: std_logic := '0';
signal fb_clk	: std_logic := '0';
signal fb_clk_b : std_logic := '0';

signal clk_out	: std_logic_vector(6 downto 0) := (others => '0');

begin

buf : if DIFF_CLK_IN = TRUE generate
	diff : IBUFDS
	port map (
		I	=> CLK_Ip,
		IB	=> CLK_In,
		O	=> in_clk
	);
else generate
	g: if BUF_CLK_IN = TRUE generate
		buf : BUFG
		port map (
			I	=> CLK_Ip,
			O	=> in_clk
		);
	else generate
		in_clk <= CLK_Ip;
	end generate;
end generate;

clk_gen : MMCME2_ADV
generic map (
  BANDWIDTH 			=> "OPTIMIZED",
  CLKFBOUT_MULT_F		=> CLKFB_MULT,
  CLKFBOUT_PHASE		=> 0.0,
  CLKIN1_PERIOD			=> CLK_IN_PERIOD,
  DIVCLK_DIVIDE			=> DIVCLK_DIVIDE,

  CLKOUT0_DIVIDE_F		=> CLK_OUT_DIVIDE(0),
  CLKOUT0_DUTY_CYCLE 	=> 0.5,
  CLKOUT0_PHASE 		=> 0.0,

  CLKOUT1_DIVIDE		=> max(integer(CLK_OUT_DIVIDE(1)), 1),
  CLKOUT1_DUTY_CYCLE 	=> 0.5,
  CLKOUT1_PHASE 		=> 0.0,
  
  CLKOUT2_DIVIDE		=> max(integer(CLK_OUT_DIVIDE(2)), 1),
  CLKOUT2_DUTY_CYCLE 	=> 0.5,
  CLKOUT2_PHASE 		=> 0.0,
  
  CLKOUT3_DIVIDE		=> max(integer(CLK_OUT_DIVIDE(3)), 1),
  CLKOUT3_DUTY_CYCLE 	=> 0.5,
  CLKOUT3_PHASE 		=> 0.0,
  
  CLKOUT4_DIVIDE		=> max(integer(CLK_OUT_DIVIDE(4)), 1),
  CLKOUT4_DUTY_CYCLE 	=> 0.5,
  CLKOUT4_PHASE 		=> 0.0,
  
  CLKOUT5_DIVIDE		=> max(integer(CLK_OUT_DIVIDE(5)), 1),
  CLKOUT5_DUTY_CYCLE 	=> 0.5,
  CLKOUT5_PHASE 		=> 0.0,
  
  CLKOUT6_DIVIDE		=> max(integer(CLK_OUT_DIVIDE(6)), 1),
  CLKOUT6_DUTY_CYCLE 	=> 0.5,
  CLKOUT6_PHASE 		=> 0.0,
  
  CLKOUT4_CASCADE		=> FALSE,      		-- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
  COMPENSATION			=> "ZHOLD",       	-- ZHOLD, BUF_IN, EXTERNAL, INTERNAL
  STARTUP_WAIT			=> FALSE,         	-- Delays DONE until MMCM is locked (FALSE, TRUE)
  CLKFBOUT_USE_FINE_PS	=> FALSE,			-- USE_FINE_PS: Fine phase shift enable (TRUE/FALSE)
  CLKOUT0_USE_FINE_PS	=> FALSE
)
port map (
  -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
  CLKOUT0	=> clk_out(0),
  CLKOUT0B	=> open,
  CLKOUT1	=> clk_out(1),
  CLKOUT1B	=> open,
  CLKOUT2	=> clk_out(2),
  CLKOUT2B	=> open,
  CLKOUT3	=> clk_out(3),
  CLKOUT3B	=> open,
  CLKOUT4	=> clk_out(4),
  CLKOUT5	=> clk_out(5),
  CLKOUT6	=> clk_out(6),
  -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
  CLKFBOUT	=> fb_clk,
  CLKFBOUTB	=> open,
  -- Status Ports: 1-bit (each) output: MMCM status ports
  LOCKED	=> LOCKED_O,
  -- Clock Inputs: 1-bit (each) input: Clock input
  CLKIN1	=> in_clk,
  CLKIN2	=> '0',
  CLKINSEL	=> '1',
  -- Control Ports: 1-bit (each) input: MMCM control ports
  PWRDWN	=> '0',
  RST		=> '0',
  DADDR		=> (others => '0'),
  DCLK		=> '0',
  DEN		=> '0',
  DI		=> (others => '0'),
  DO		=> open,
  DRDY		=> open,
  DWE		=> '0',
  PSCLK		=> '0',
  PSEN		=> '0',
  PSINCDEC	=> '0',
  PSDONE	=> open, 
  -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
  CLKFBIN	=> fb_clk_b      -- 1-bit input: Feedback clock
);

fb_buf : BUFG
port map (
	I	=> fb_clk,
	O	=> fb_clk_b
);

buf0 : BUFG
port map (
	I	=> clk_out(0),
	O	=> CLK0_O
);

out1 : if CLK_OUT_DIVIDE(1) > 0.0 generate
	buf1 : BUFG
	port map (
		I	=> clk_out(1),
		O	=> CLK1_O
	);
else generate
	CLK1_O <= '0';
end generate;
	
out2 : if CLK_OUT_DIVIDE(2) > 0.0 generate
	buf : BUFG
	port map (
		I	=> clk_out(2),
		O	=> CLK2_O
	);
else generate
	CLK2_O <= '0';
end generate;

out3 : if CLK_OUT_DIVIDE(3) > 0.0 generate
	buf1: BUFG
	port map (
		I	=> clk_out(3),
		O	=> CLK3_O
	);
else generate
	CLK3_O <= '0';
end generate;

out4 : if CLK_OUT_DIVIDE(4) > 0.0 generate
	buf : BUFG
	port map (
		I	=> clk_out(4),
		O	=> CLK4_O
	);
else generate
	CLK4_O <= '0';
end generate;

out5 : if CLK_OUT_DIVIDE(5) > 0.0 generate
	buf : BUFG
	port map (
		I	=> clk_out(5),
		O	=> CLK5_O
	);
else generate
	CLK5_O <= '0';
end generate;

out6 : if CLK_OUT_DIVIDE(6) > 0.0 generate
	buf : BUFG
	port map (
		I	=> clk_out(6),
		O	=> CLK6_O
	);
else generate
	CLK6_O <= '0';
end generate;

end Behavioral;
