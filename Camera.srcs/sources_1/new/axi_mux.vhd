library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;

entity axi_mux is
Generic (
	DATA_WIDTH			: integer := 32;
	OVERRIDE_0          : boolean := false;
	OVERRIDE_1          : boolean := false
);
Port (
	SELECT_I			: in STD_LOGIC;
	
	-- AXI Slave 0
	S_AXIS_ACLOCK_0_I	: in STD_LOGIC;
	S_AXIS_TVALID_0_I	: in STD_LOGIC;
	S_AXIS_TLAST_0_I	: in STD_LOGIC;
	S_AXIS_TUSER_0_I	: in STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TDATA_0_I	: in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	S_AXIS_TREADY_0_O	: out STD_LOGIC := '0';
	
	-- AXI Slave 1
	S_AXIS_ACLOCK_1_I	: in STD_LOGIC;
	S_AXIS_TVALID_1_I	: in STD_LOGIC;
	S_AXIS_TLAST_1_I	: in STD_LOGIC;
	S_AXIS_TUSER_1_I	: in STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TDATA_1_I	: in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	S_AXIS_TREADY_1_O	: out STD_LOGIC := '0';
	
	-- AXI Master
	M_AXIS_ACLOCK_O		: out STD_LOGIC := '0';
	M_AXIS_TVALID_O		: out STD_LOGIC := '0';
	M_AXIS_TLAST_O		: out STD_LOGIC := '0';
	M_AXIS_TUSER_O		: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TDATA_O		: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
	M_AXIS_TREADY_I		: in  STD_LOGIC	
);
end axi_mux;

architecture Behavioral of axi_mux is

signal sel_clk  : std_logic := '0';

signal change_0	: std_logic := '0';
signal change_1	: std_logic := '0';

signal ack_0	: std_logic := '0';
signal ack_1	: std_logic := '0';

signal pre_sel	: std_logic := '1';
signal sel 		: std_logic := '1';

signal busy		: std_logic_vector(1 downto 0) := "00";

begin

clk_mux : BUFGMUX
generic map (
	CLK_SEL_TYPE	=> "ASYNC"
)
port map (
	S	=> sel,
	I0	=> S_AXIS_ACLOCK_0_I,
	I1	=> S_AXIS_ACLOCK_1_I,
	O	=> M_AXIS_ACLOCK_O
);

busy_0 : process(S_AXIS_ACLOCK_0_I)
begin
	if rising_edge(S_AXIS_ACLOCK_0_I) then
		ack_0 <= change_0;
		
		if S_AXIS_TUSER_0_I(0) = '1' then
			busy(0) <= '0';
		elsif S_AXIS_TVALID_1_I = '1' then
			busy(0) <= '1';
		end if;
	end if;
end process;

busy_1 : process(S_AXIS_ACLOCK_1_I)
begin
	if rising_edge(S_AXIS_ACLOCK_1_I) then
		ack_1 <= change_1;
		
		if S_AXIS_TUSER_1_I(0) = '1' then
			busy(1) <= '0';
		elsif S_AXIS_TVALID_1_I = '1' then
			busy(1) <= '1';
		end if;
	end if;
end process;

clk_sel : if OVERRIDE_0 = true generate
    sel_clk <= S_AXIS_ACLOCK_1_I;
elsif OVERRIDE_1 = true generate
    sel_clk <= S_AXIS_ACLOCK_0_I;
else generate
    sel_clk <= M_AXIS_ACLOCK_O;
end generate; 

process(sel_clk)
begin
	if rising_edge(sel_clk) then
		if (busy(0) = '0' AND SELECT_I = '0')
		or (busy(1) = '0' AND SELECT_I = '1') then
			pre_sel <= SELECT_I;
		
			if pre_sel /= SELECT_I then
				change_0 <= not SELECT_I;
				change_1 <= SELECT_I;
			end if;
		end if;
		
		if ((ack_0 = '1' or OVERRIDE_0 = true) and pre_sel = '0')
		or ((ack_1 = '1' or OVERRIDE_1 = true) and pre_sel = '1') then
			sel <= pre_sel;
			change_0 <= '0';
			change_1 <= '0';
		end if;
	end if;
end process;
	
process(M_AXIS_ACLOCK_O)
begin
	if rising_edge(M_AXIS_ACLOCK_O) then
		if sel = '0' then
			M_AXIS_TVALID_O		<= S_AXIS_TVALID_0_I;
			M_AXIS_TLAST_O		<= S_AXIS_TLAST_0_I;
			M_AXIS_TUSER_O		<= S_AXIS_TUSER_0_I;
			M_AXIS_TDATA_O		<= S_AXIS_TDATA_0_I;
			
			S_AXIS_TREADY_0_O	<= M_AXIS_TREADY_I;
			S_AXIS_TREADY_1_O	<= '0';
		else
			M_AXIS_TVALID_O		<= S_AXIS_TVALID_1_I;
			M_AXIS_TLAST_O		<= S_AXIS_TLAST_1_I;
			M_AXIS_TUSER_O		<= S_AXIS_TUSER_1_I;
			M_AXIS_TDATA_O		<= S_AXIS_TDATA_1_I;
			
			S_AXIS_TREADY_0_O	<= '0';
			S_AXIS_TREADY_1_O	<= M_AXIS_TREADY_I;
		end if;
	end if;
end process;

end Behavioral;
