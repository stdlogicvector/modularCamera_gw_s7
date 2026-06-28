library IEEE, UNISIM, UNIMACRO;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.all;
use UNIMACRO.vcomponents.all;
use Work.util.all;


--This block converts a Reduced-Media-Independent-Interface (RGMII)
--to GMII like interface. The GMII data is synchronized to the
--user clock domain (CLK_I) with an elastic buffer. 
--the user clock domain (CLK_I) is used to drive the RGMII TX clock. 
--http://ebook.pldworld.com/_eBook/-Telecommunications,Networks-/TCPIP/RGMII/RGMIIv2_0_final_hp.pdf 
 
entity RGMII2GMII is
	generic (
		INPUT_DELAY		: integer range 0 to 255 := 0;
		OUTPUT_DELAY	: integer range 0 to 255 := 0;
		CLK_INPUT_STYLE	: string := "BUFG";
		USE_CLK90		: boolean := FALSE
	);
	port (		
		CLK_I 			: in 	std_logic;
		CLK90_I			: in	std_logic;
		RESET_I 		: in 	std_logic;

		-- RGMII interface
		RGMII_TX_CLK_O	: out	std_logic;
		RGMII_TXD_O		: out	std_logic_vector(3 downto 0);
		RGMII_TX_CTL_O	: out	std_logic;
		
		RGMII_RX_CLK_I	: in	std_logic;
		RGMII_RXD_I		: in	std_logic_vector(3 downto 0);
		RGMII_RX_CTL_I	: in	std_logic;
	
		-- GMII interface
		GMII_TXD_I		: in	std_logic_vector(7 downto 0);
		GMII_TX_DV_I	: in	std_logic;
		GMII_TX_ER_I	: in	std_logic;
		
		GMII_RXD_O		: out	std_logic_vector(7 downto 0);
		GMII_RX_DV_O	: out	std_logic;
		GMII_RX_EMPTY   : out   std_logic;
		GMII_RX_ER_O	: out	std_logic
	);
end RGMII2GMII;

architecture Behavioral of RGMII2GMII is

signal RGMII_RX_CTL_I_D		: std_logic;
signal RGMII_RXD_I_D		: std_logic_vector(3 downto 0);

signal rgmii_rx_clk			: std_logic;
signal rgmii_rx_clk_iobuf	: std_logic;
signal rgmii_rx_clk_iddr	: std_logic;
signal rgmii_rx_reset		: std_logic;

signal gmii_rxd         	: std_logic_vector(7 downto 0) := (others => '0');
signal gmii_rx_dv       	: std_logic := '0';
signal gmii_rx_er       	: std_logic := '0';

signal rx_fifo_dout         : std_logic_vector(9 downto 0) := (others => '0');
signal rx_fifo_din          : std_logic_vector(9 downto 0) := (others => '0');
signal rx_fifo_almost_full  : std_logic;

-- delayed fifo reset signals
signal reset_rgmii_rx_fifo 	: std_logic_vector(15 downto 0) := (others => '1');
signal reset_clk          	: std_logic_vector(15 downto 0) := (others => '1');

signal fifo_reset			: std_logic_vector(5 downto 0) := "111110";

begin

--------------------------------------------------------------------------
-- TX
--------------------------------------------------------------------------

CLK_90 : if USE_CLK90 = TRUE generate

tx_clk : ODDR2
generic map (
	DDR_ALIGNMENT	=> "C0",
	SRTYPE			=> "ASYNC"
)
port map (
	C0	=> CLK90_I,
	C1	=> not CLK90_I,
	CE	=> '1',
	Q	=> RGMII_TX_CLK_O,
	D0	=> '1',
	D1	=> '0',
	R	=> '0',
	S	=> '0'	
);

end generate;

CLK_0 : if USE_CLK90 = FALSE generate

tx_clk : ODDR2
generic map (
	DDR_ALIGNMENT	=> "C0",
	SRTYPE			=> "ASYNC"
)
port map (
	C0	=> CLK_I,
	C1	=> not CLK_I,
	CE	=> '1',
	Q	=> RGMII_TX_CLK_O,
	D0	=> '1',
	D1	=> '0',
	R	=> '0',
	S	=> '0'	
);

end generate;

tx_ctrl : ODDR2
generic map (
	DDR_ALIGNMENT	=> "C0",
	SRTYPE			=> "ASYNC"
)
port map (
	C0	=> CLK_I,
	C1	=> not CLK_I,
	CE	=> '1',
	Q	=> RGMII_TX_CTL_O,
	D0	=> GMII_TX_DV_I,
	D1	=> GMII_TX_DV_I XOR GMII_TX_ER_I,
	R	=> '0',
	S	=> '0'	
);

tx_data : for i in 0 to 3 generate

tx : ODDR2
generic map (
	DDR_ALIGNMENT	=> "C0",
	SRTYPE			=> "ASYNC"
)
port map (
	C0	=> CLK_I,
	C1	=> not CLK_I,
	CE	=> '1',
	Q	=> RGMII_TXD_O(i),
	D0	=> GMII_TXD_I(i),
	D1	=> GMII_TXD_I(i+4),
	R	=> '0',
	S	=> '0'	
);

end generate;

--------------------------------------------------------------------------
-- RX
--------------------------------------------------------------------------

BUFIO2_CLK : if CLK_INPUT_STYLE = "BUFIO2" generate

rx_clk_buf : BUFIO2
generic map (
	DIVIDE			=> 1,
	DIVIDE_BYPASS	=> TRUE,
	I_INVERT		=> FALSE,
	USE_DOUBLER		=> FALSE
)	
port map (
	I				=> RGMII_RX_CLK_I,
	DIVCLK			=> rgmii_rx_clk_iobuf,
	IOCLK			=> rgmii_rx_clk_iddr,
	SERDESSTROBE	=> open	
);

end generate;

rx_clk : BUFG
port map (
	I	=> rgmii_rx_clk_iobuf,
	O	=> rgmii_rx_clk
);

BUFG_CLK : if CLK_INPUT_STYLE /= "BUFIO2" generate

rgmii_rx_clk_iobuf	<= RGMII_RX_CLK_I;
rgmii_rx_clk_iddr	<= rgmii_rx_clk;

end generate;

rx_ctrl_delay : if INPUT_DELAY > 0 generate

rx_ctrl_delay_i : IODELAY2
generic map (
	COUNTER_WRAPAROUND => "WRAPAROUND", -- "STAY_AT_LIMIT" or "WRAPAROUND" 
	DATA_RATE => "DDR",                 -- "SDR" or "DDR" 
	DELAY_SRC => "IDATAIN",             -- "IO", "ODATAIN" or "IDATAIN" 
	IDELAY2_VALUE => 0,                 -- Delay value when IDELAY_MODE="PCI" (0-255)
	IDELAY_MODE => "NORMAL",            -- "NORMAL" or "PCI" 
	IDELAY_TYPE => "FIXED",             -- "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
										-- or "DIFF_PHASE_DETECTOR" 
	IDELAY_VALUE => INPUT_DELAY,        -- Amount of taps for fixed input delay (0-255)
	ODELAY_VALUE => 0,                  -- Amount of taps fixed output delay (0-255)
	SERDES_MODE => "NONE",              -- "NONE", "MASTER" or "SLAVE" 
	SIM_TAPDELAY_VALUE => 75            -- Per tap delay used for simulation in ps
)
port map (
	IDATAIN => RGMII_RX_CTL_I,
	DATAOUT => RGMII_RX_CTL_I_D,
	BUSY => open,
	DATAOUT2 => open,
	DOUT => open,
	TOUT => open,
	CAL => '0',
	CE => '0',
	CLK => '0',
	INC => '0',
	IOCLK0 => '0',
	IOCLK1 => '0',
	ODATAIN => '0',
	RST => '0',
	T => '1'
);

end generate;

rx_ctrl_no_delay : if INPUT_DELAY = 0 generate

RGMII_RX_CTL_I_D <= RGMII_RX_CTL_I;

end generate;

rx_ctrl : IDDR2
generic map (
	DDR_ALIGNMENT	=> "C0"
)
port map (
	C0	=> rgmii_rx_clk_iddr,
	C1	=> not rgmii_rx_clk_iddr,
	CE	=> '1',
	D	=> RGMII_RX_CTL_I_D,
	Q0	=> gmii_rx_dv,
	Q1	=> gmii_rx_er,		
	R	=> '0',
	S	=> '0'	
);

rx_data : for i in 0 to 3 generate

rx_delay : if INPUT_DELAY > 0 generate

rx_delay_i : IODELAY2
generic map (
	COUNTER_WRAPAROUND => "WRAPAROUND", -- "STAY_AT_LIMIT" or "WRAPAROUND" 
	DATA_RATE => "DDR",                 -- "SDR" or "DDR" 
	DELAY_SRC => "IDATAIN",             -- "IO", "ODATAIN" or "IDATAIN" 
	IDELAY2_VALUE => 0,                 -- Delay value when IDELAY_MODE="PCI" (0-255)
	IDELAY_MODE => "NORMAL",            -- "NORMAL" or "PCI" 
	IDELAY_TYPE => "FIXED",             -- "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
										-- or "DIFF_PHASE_DETECTOR" 
	IDELAY_VALUE => INPUT_DELAY,        -- Amount of taps for fixed input delay (0-255)
	ODELAY_VALUE => 0,                  -- Amount of taps fixed output delay (0-255)
	SERDES_MODE => "NONE",              -- "NONE", "MASTER" or "SLAVE" 
	SIM_TAPDELAY_VALUE => 75            -- Per tap delay used for simulation in ps
)
port map (
	IDATAIN => RGMII_RXD_I(i),
	DATAOUT => RGMII_RXD_I_D(i),
	BUSY => open,
	DATAOUT2 => open,
	DOUT => open,
	TOUT => open,
	CAL => '0',
	CE => '0',
	CLK => '0',
	INC => '0',
	IOCLK0 => '0',
	IOCLK1 => '0',
	ODATAIN => '0',
	RST => '0',
	T => '1'
);

end generate;

rx_no_delay : if INPUT_DELAY = 0 generate

RGMII_RXD_I_D(i) <= RGMII_RXD_I(i);

end generate;

-- Rising Edge [3:0], Falling Edge [7:4] -- is this still true after clock delay?

rx : IDDR2
generic map (
	DDR_ALIGNMENT	=> "C0"
)
port map (
	C0	=> rgmii_rx_clk_iddr,
	C1	=> not rgmii_rx_clk_iddr,
	CE	=> '1',
	D	=> RGMII_RXD_I_D(i),
	Q0	=> gmii_rxd(i),
	Q1	=> gmii_rxd(i+4),
	R	=> '0',
	S	=> '0'	
);

end generate;

--------------------------------------------------------------------------
-- fifos
--------------------------------------------------------------------------

--Signals wr_en and rd_en of an series 7 built-in fifo must be held low
--while reset is asserted. To ensure correct operation, the signals 
--are held low for another 16 clock cycles after reset is deasserted.
--https://www.xilinx.com/support/documentation/ip_documentation/fifo_generator/v13_1/pg057-fifo-generator.pdf
--Page 130

reset_gen_clk: process(CLK_I)
begin
    if (rising_edge(CLK_I)) then
    	if (RESET_I = '1') then
    		fifo_reset	<= (others => '1');
    		reset_clk	<= (others => '1');
		else
			reset_clk <= reset_clk(reset_clk'high-1 downto 0) & '0'; 
			fifo_reset <= fifo_reset(fifo_reset'high-1 downto 0) & '0';
		end if; 
    end if;
end process;

reset : entity work.sync_clk_domain(HandShake)
generic map (
	STAGES	=> 3
)
port map (
	RST_SRC_I	=> RESET_I,
	
	CLK_DST_I	=> rgmii_rx_clk,
	RST_DST_O	=> rgmii_rx_reset
);

reset_gen_rxclk: process(rgmii_rx_clk)
begin
    if (rising_edge(rgmii_rx_clk)) then
    	if (rgmii_rx_reset = '1') then
    		reset_rgmii_rx_fifo <= (others => '1');
    	else
    		reset_rgmii_rx_fifo <= reset_rgmii_rx_fifo(reset_rgmii_rx_fifo'high-1 downto 0) & '0';
    	end if; 
    end if;
end process;

--The RX fifo is used in an elasic buffer configuration.
--The wr_en logic ensures that the buffer is always filled at least halfway.
--In order to achive this behaviour the wr_en signal is asserted when the RGMII interface
--is indicating a new packet (RX_DV = '1') or when the almost_full flag is deasserted.
--https://www.fpgadeveloper.com/2015/12/fpga-network-tap-designing-ethernet-pass-through.html
--Chapter: Wire the FIFOs as elastic buffers
--
--For handling of the reset signals see description in the 'processes' block. 
 
rx_fifo : entity work.eth_rx_fifo
port map (
    rst			=> fifo_reset(fifo_reset'high),
	
    wr_clk		=> rgmii_rx_clk,
	wr_en		=> (NOT rx_fifo_almost_full OR gmii_rx_dv) AND
              	   (NOT reset_rgmii_rx_fifo(reset_rgmii_rx_fifo'high)),
	prog_full	=> rx_fifo_almost_full,
	full		=> open,
	din			=> rx_fifo_din,
	
    rd_clk		=> CLK_I,
    rd_en		=> NOT reset_clk(reset_clk'high),
    empty		=> GMII_RX_EMPTY,
	dout		=> rx_fifo_dout
    
);

--------------------------------------------------------------------------
-- combinatorial logic
--------------------------------------------------------------------------

-- RGMII -> FIFO
rx_fifo_din <= gmii_rx_dv & gmii_rx_er & gmii_rxd;

-- FIFO -> GMII (Userland)
GMII_RXD_O      <= rx_fifo_dout(7 downto 0);
GMII_RX_ER_O    <= rx_fifo_dout(8) XOR rx_fifo_dout(9); 
GMII_RX_DV_O    <= rx_fifo_dout(9);


end architecture;
