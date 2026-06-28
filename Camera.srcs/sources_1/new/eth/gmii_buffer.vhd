library IEEE, UNISIM, UNIMACRO, XPM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.all;
use UNIMACRO.vcomponents.all;
use XPM.vcomponents.all;
use Work.util.all;

entity GMII_buffer is
	generic (
		USE_CLK90		: boolean := FALSE;
		INV_CLK			: boolean := FALSE
	);
	port (		
		CLK_I 			: in 	std_logic;
		CLK90_I			: in	std_logic := '0';
		RESET_I 		: in 	std_logic;

		-- GMII in
		GMII_TX_CLK_O	: out	std_logic;
		GMII_TXD_O		: out	std_logic_vector(7 downto 0);
		GMII_TX_CTL_O	: out	std_logic;
		GMII_TX_ERR_O	: out	std_logic;
		
		GMII_RX_CLK_I	: in	std_logic;
		GMII_RXD_I		: in	std_logic_vector(7 downto 0);
		GMII_RX_CTL_I	: in	std_logic;
		GMII_RX_ERR_I	: in	std_logic;
	
		-- GMII out
		GMII_TXD_I		: in	std_logic_vector(7 downto 0);
		GMII_TX_DV_I	: in	std_logic;
		GMII_TX_ER_I	: in	std_logic;
		
		GMII_RXD_O		: out	std_logic_vector(7 downto 0);
		GMII_RX_DV_O	: out	std_logic;
		GMII_RX_EMPTY_O : out   std_logic;
		GMII_RX_ER_O	: out	std_logic
	);
end GMII_buffer;

architecture Behavioral of GMII_buffer is

signal gmii_rx_clk			: std_logic;
signal gmii_rx_reset		: std_logic;

signal gmii_rxd         	: std_logic_vector(7 downto 0) := (others => '0');
signal gmii_rx_dv       	: std_logic := '0';
signal gmii_rx_er       	: std_logic := '0';

signal gmii_rx_dv_last		: std_logic := '0'; 

signal gmii_rx_empty		: std_logic := '0';
signal gmii_rx_almost_empty	: std_logic := '0';

signal rx_fifo_dout         : std_logic_vector(9 downto 0) := (others => '0');
signal rx_fifo_din          : std_logic_vector(9 downto 0) := (others => '0');
signal rx_fifo_almost_full  : std_logic;

-- delayed fifo reset signals
signal reset_gmii_rx_fifo 	: std_logic_vector(15 downto 0) := (others => '1');
signal reset_clk          	: std_logic_vector(15 downto 0) := (others => '1');

signal fifo_write			: std_logic;
signal fifo_read			: std_logic;

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
	Q	=> GMII_TX_CLK_O,
	D0	=> switch(INV_CLK, '0', '1'),
	D1	=> switch(INV_CLK, '1', '0'),
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
	Q	=> GMII_TX_CLK_O,
	D0	=> switch(INV_CLK, '0', '1'),
	D1	=> switch(INV_CLK, '1', '0'),
	R	=> '0',
	S	=> '0'	
);

end generate;

tx_data : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		GMII_TX_CTL_O <= GMII_TX_DV_I;
		GMII_TX_ERR_O <= GMII_TX_ER_I;
		GMII_TXD_O	  <= GMII_TXD_I;
	end if;
end process;

--------------------------------------------------------------------------
-- RX
--------------------------------------------------------------------------

rx_clk : BUFG
port map (
	I	=> GMII_RX_CLK_I,
	O	=> gmii_rx_clk
);

gmii_rx_dv <= GMII_RX_CTL_I;
gmii_rx_er <= GMII_RX_ERR_I;
gmii_rxd   <= GMII_RXD_I;

--------------------------------------------------------------------------
-- FIFOs
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

reset_sync : xpm_cdc_sync_rst
generic map (
	DEST_SYNC_FF => 2,
	INIT => 1,
	INIT_SYNC_FF => 0,
	SIM_ASSERT_CHK => 0 
)
port map (
	src_rst		=> RESET_I,
	
	dest_clk	=> gmii_rx_clk,
	dest_rst	=> gmii_rx_reset
);

reset_gen_rxclk: process(gmii_rx_clk)
begin
    if (rising_edge(gmii_rx_clk)) then
    	if (gmii_rx_reset = '1') then
    		reset_gmii_rx_fifo <= (others => '1');
    	else
    		reset_gmii_rx_fifo <= reset_gmii_rx_fifo(reset_gmii_rx_fifo'high-1 downto 0) & '0';
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

process(gmii_rx_clk)
begin
	if rising_edge(gmii_rx_clk) then
		gmii_rx_dv_last <= gmii_rx_dv;		-- Ensure one cycle of dv=0 in FIFO to prevent back-to-back packets
	end if;
end process;

fifo_write <= (NOT rx_fifo_almost_full OR gmii_rx_dv OR gmii_rx_dv_last) AND (NOT reset_gmii_rx_fifo(reset_gmii_rx_fifo'high));

rx_fifo : FIFO_DUALCLOCK_MACRO
generic map (
	DEVICE				=> "7SERIES", 
	ALMOST_FULL_OFFSET	=> X"0200",		-- Use Almost Full = 512
	ALMOST_EMPTY_OFFSET => X"01FF",		-- Use Almost Empty = 511
	DATA_WIDTH			=> 10,   		-- 18Kb FIFO at 10bit Width = 1024 Depth
	FIFO_SIZE			=> "18Kb"
) 
port map (
	rst			=> fifo_reset(fifo_reset'high),
	
	WRCLK		=> gmii_rx_clk,
	WREN 		=> fifo_write,
	WRERR 		=> open,
	ALMOSTFULL 	=> rx_fifo_almost_full,
	FULL 		=> open,
	WRCOUNT		=> open,
	DI 			=> rx_fifo_din,
	
	RDCLK		=> CLK_I,
	RDEN 		=> fifo_read,
	RDERR		=> open, 	
	ALMOSTEMPTY => gmii_rx_almost_empty,
	EMPTY 		=> gmii_rx_empty,
	RDCOUNT 	=> open,
	DO 			=> rx_fifo_dout
);

fifo_read <= (NOT gmii_rx_almost_empty OR rx_fifo_dout(9)) AND NOT reset_clk(reset_clk'high);

--------------------------------------------------------------------------
-- combinatorial logic
--------------------------------------------------------------------------

-- GMII -> FIFO
rx_fifo_din <= gmii_rx_dv & gmii_rx_er & gmii_rxd;

-- FIFO -> GMII (Userland)
GMII_RXD_O      <= rx_fifo_dout(7 downto 0);
GMII_RX_ER_O    <= rx_fifo_dout(8);-- XOR rx_fifo_dout(9); 
GMII_RX_DV_O    <= rx_fifo_dout(9);
GMII_RX_EMPTY_O <= gmii_rx_almost_empty AND NOT rx_fifo_dout(9);

end architecture;
