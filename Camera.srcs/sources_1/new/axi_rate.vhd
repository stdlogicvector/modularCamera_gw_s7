library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity axi_rate is
	Generic (
		CLK_MHZ			: real := 100.0;
		RESOLUTION_US	: integer := 1;
		DATA_WIDTH		: integer := 8
	);
	Port (
		AXIS_ACLK_I		: in  STD_LOGIC;
		RST_I 			: in  STD_LOGIC;
		
		INTERVAL_I		: in  STD_LOGIC_VECTOR (15 downto 0);
		
		-- AXI Slave
		S_AXIS_TVALID_I	: in  STD_LOGIC;
		S_AXIS_TLAST_I	: in  STD_LOGIC;
		S_AXIS_TDATA_I	: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
		S_AXIS_TREADY_O	: out STD_LOGIC := '0';
	
		-- AXI Master
		M_AXIS_TVALID_O	: out STD_LOGIC := '0';
		M_AXIS_TLAST_O	: out STD_LOGIC := '0';
		M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
		M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
		M_AXIS_TREADY_I	: in  STD_LOGIC
	);
end axi_rate;

architecture Behavioral of axi_rate is

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant PRESCALE	: integer := integer(real(RESOLUTION_US) * 1000.0 / CLK_PERIOD);

signal prescaler	: integer range 0 to PRESCALE-1 := 0;

signal timer		: std_logic_vector(15 downto 0) := (others => '0');

type state_t is (S_IDLE, S_FRAME, S_WAIT, S_EOF);
signal state		: state_t := S_IDLE;

signal in_frame		: std_logic := '0';

begin

process(AXIS_ACLK_I)
begin
	if rising_edge(AXIS_ACLK_I) then
		if prescaler = PRESCALE-1 then
			prescaler <= 0;
			
			timer <= inc(timer);
		else
			prescaler <= prescaler + 1;
		end if;
		
		case state is
		when S_IDLE =>
			if S_AXIS_TUSER_I(0) = '1' then
				state <= S_FRAME;
				timer <= (others => '0');
			end if;
			
		when S_FRAME =>
			if S_AXIS_TUSER_I(1) = '1' then
				state <= S_WAIT;
			end if;
			
		when S_WAIT =>
			if S_AXIS_TUSER_I(0) = '1' then
				in_frame <= '1';
			end if;
			
			if timer > INTERVAL_I then
				state <= S_EOF;
			end if;
			
		when S_EOF =>
			if in_frame = '0' or S_AXIS_TUSER_I(1) = '1' then
				state <= S_IDLE;
			end if;
		
		end case;
		
		if state = S_IDLE or state = S_FRAME then
			M_AXIS_TVALID_O	<= S_AXIS_TVALID_I;
			M_AXIS_TLAST_O	<= S_AXIS_TLAST_I;
			M_AXIS_TUSER_O	<= S_AXIS_TUSER_I;
			S_AXIS_TREADY_O <= M_AXIS_TREADY_I;
		else
			M_AXIS_TVALID_O	<= '0';
			M_AXIS_TLAST_O	<= '0';
			M_AXIS_TUSER_O	<= (others => '0');
			S_AXIS_TREADY_O <= '0';
		end if;
		
		M_AXIS_TDATA_O <= S_AXIS_TDATA_I;
		
		if RST_I = '1' then
			state <= S_IDLE;
		end if;
	
	end if;
end process;

end Behavioral;

