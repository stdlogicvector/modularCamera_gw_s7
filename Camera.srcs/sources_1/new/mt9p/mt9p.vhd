library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity mt9p is
Port (
	RST_I			: in  STD_LOGIC;
	
	MCLK_I			: in  STD_LOGIC;
	MCLK_O			: out STD_LOGIC := '0';

	PCLK_I			: in  STD_LOGIC;
	LVAL_I			: in  STD_LOGIC;
	FVAL_I			: in  STD_LOGIC;
 	DATA_I			: in  STD_LOGIC_VECTOR(11 downto 0);
 	
 	LPF_I			: in  STD_LOGIC_VECTOR(15 downto 0) := int2vec(2592, 16);
	
	-- AXI Master
	M_AXIS_ACLK_O	: out STD_LOGIC := '0';
	M_AXIS_TVALID_O	: out STD_LOGIC := '0';
	M_AXIS_TLAST_O	: out STD_LOGIC := '0';
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TREADY_I	: in  STD_LOGIC	
);
end mt9p;

architecture Behavioral of mt9p is

signal ready		: std_logic := '0';
signal valid		: std_logic := '0';
signal sof			: std_logic := '0';

signal in_frame		: std_logic := '0';

signal line			: std_logic_vector(15 downto 0) := (others => '0');

signal data_0		: std_logic_vector(11 downto 0) := (others => '0');
signal data_1		: std_logic_vector(11 downto 0) := (others => '0');
signal fval_edge 	: std_logic_vector(1 downto 0) := "00";
signal lval_edge 	: std_logic_vector(1 downto 0) := "00";

begin

MCLK_O 				<= MCLK_I;

M_AXIS_ACLK_O		<= PCLK_I;

process(PCLK_I)
begin
	if rising_edge(PCLK_I) then
	
		sof <= '0';
		M_AXIS_TUSER_O(1) <= '0';
		
		if FVAL_I = '0' then
			ready 	<= M_AXIS_TREADY_I;
		end if;
		
		fval_edge <= fval_edge(0) & FVAL_I;
		lval_edge <= lval_edge(0) & LVAL_I;
		
		if lval_edge = "01" then	-- Rising Edge
			in_frame <= '1';		-- Frame starts on beginning of first line
			valid	 <= ready;
			sof 	 <= not in_frame;
			line 	 <= inc(line);
		end if;
		
		if lval_edge = "10" then	-- Falling Edge
			valid	 <= '0';
			
			if line = LPF_I then	-- End of Frame
				line <= (others => '0');
				in_frame <= '0';
				M_AXIS_TUSER_O(1) <= '1';
			end if;
		end if;
		
		if fval_edge = "10" then
			in_frame <= '0';
			line <= (others => '0');
		end if;
		
		data_0 <= DATA_I;
		data_1 <= data_0;
		
		M_AXIS_TVALID_O		<= valid;
		M_AXIS_TDATA_O		<= data_1;
		M_AXIS_TLAST_O		<= lval_edge(1) and not lval_edge(0);					-- End of Line 	  = Falling Edge of LVAL
		M_AXIS_TUSER_O(0)	<= sof;
--		M_AXIS_TUSER_O(0)	<= not in_frame and lval_edge(0) and not lval_edge(1);	-- Start of Frame = Rising Edge of first LVAL
--		M_AXIS_TUSER_O(1)	<= lval_edge(1) and not lval_edge(0);					-- End of Frame   = Falling Edge of FVAL
	end if;
end process;

end Behavioral;
