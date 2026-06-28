library IEEE, XPM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use XPM.VCOMPONENTS.ALL;
use work.util.all;

entity axi_fifo is
Generic (
	CLOCKING_MODE	: string := "common_clock";	-- "common_clock" / "independent_clock"
	DATA_WIDTH		: integer := 32;
	DEPTH			: integer := 1024
);
Port (
	nRST_I			: in  STD_LOGIC;
	
	-- AXI Slave
	S_AXIS_ACLK_I	: in  STD_LOGIC;
	S_AXIS_TVALID_I	: in  STD_LOGIC;
	S_AXIS_TLAST_I	: in  STD_LOGIC;
	S_AXIS_TDATA_I	: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TREADY_O	: out STD_LOGIC;

	-- AXI Master
	M_AXIS_ACLK_I	: in  STD_LOGIC;
	M_AXIS_TVALID_O	: out STD_LOGIC;
	M_AXIS_TLAST_O	: out STD_LOGIC;
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0);
	M_AXIS_TREADY_I	: in  STD_LOGIC;
	
	THRESHOLD_I		: in  STD_LOGIC_VECTOR(clogb2(DEPTH) downto 0);
	THRESHOLD_O		: out STD_LOGIC
);
end axi_fifo;

architecture Behavioral of axi_fifo is

signal rd_data_count		: std_logic_vector(clogb2(DEPTH) downto 0) := (others => '0');
signal threshold			: std_logic_vector(clogb2(DEPTH) downto 0) := (others => '1');

constant FIFO_WIDTH			: integer := integer(ceil(real(DATA_WIDTH)/8.0) * 8.0);

signal data_in				: std_logic_vector(FIFO_WIDTH-1 downto 0) := (others => '0');
signal data_out				: std_logic_vector(FIFO_WIDTH-1 downto 0) := (others => '0');

begin

data_in(DATA_WIDTH-1 downto 0) <= S_AXIS_TDATA_I;

fifo : xpm_fifo_axis
generic map (
	CASCADE_HEIGHT			=> 0,
	CDC_SYNC_STAGES			=> 2,
	CLOCKING_MODE			=> CLOCKING_MODE,
	ECC_MODE				=> "no_ecc",
	EN_SIM_ASSERT_ERR		=> "warning",
	FIFO_DEPTH				=> DEPTH,
	FIFO_MEMORY_TYPE		=> "auto",
	PACKET_FIFO				=> "false",
	PROG_EMPTY_THRESH		=> 10,
	PROG_FULL_THRESH		=> DEPTH / 2,
	RD_DATA_COUNT_WIDTH		=> clogb2(DEPTH)+1,
	RELATED_CLOCKS			=> 0,
	SIM_ASSERT_CHK			=> 0,
	TDATA_WIDTH				=> FIFO_WIDTH,
	TDEST_WIDTH				=> 1,
	TID_WIDTH				=> 1,
	TUSER_WIDTH				=> 2,
	USE_ADV_FEATURES		=> "0402",
	WR_DATA_COUNT_WIDTH		=> 1
)
port map (
	s_aresetn 				=> nRST_I,
	
	s_aclk					=> S_AXIS_ACLK_I,
	s_axis_tvalid			=> S_AXIS_TVALID_I,
	s_axis_tlast			=> S_AXIS_TLAST_I,
	s_axis_tuser			=> S_AXIS_TUSER_I,
	s_axis_tdata			=> data_in,
	s_axis_tready			=> S_AXIS_TREADY_O,
		
	s_axis_tdest			=> (others => '0'),
	s_axis_tid				=> (others => '0'),
	s_axis_tkeep			=> (others => '1'),  
	s_axis_tstrb			=> (others => '1'),
	
	m_aclk					=> M_AXIS_ACLK_I,
	m_axis_tvalid			=> M_AXIS_TVALID_O,
	m_axis_tlast			=> M_AXIS_TLAST_O,
	m_axis_tuser			=> M_AXIS_TUSER_O,
	m_axis_tdata			=> data_out,
	m_axis_tready			=> M_AXIS_TREADY_I,
	
	m_axis_tdest			=> open,
	m_axis_tid				=> open,
	m_axis_tkeep			=> open,
	m_axis_tstrb			=> open,
	
	injectdbiterr_axis		=> '0',
	injectsbiterr_axis		=> '0',
	
	almost_empty_axis		=> open,
	almost_full_axis		=> open,
	
	prog_empty_axis			=> open,
	prog_full_axis			=> open,--THRESHOLD_O,
	
	wr_data_count_axis		=> open,
	rd_data_count_axis		=> rd_data_count
);

M_AXIS_TDATA_O <= data_out(DATA_WIDTH-1 downto 0);

process(M_AXIS_ACLK_I)
begin
	if rising_edge(M_AXIS_ACLK_I) then
		threshold <= dec(THRESHOLD_I);
	
		if (rd_data_count > threshold) then
			THRESHOLD_O <= '1';
		else
			THRESHOLD_O <= '0';
		end if; 
	end if;
end process;

end Behavioral;
