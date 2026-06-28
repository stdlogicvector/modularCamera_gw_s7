library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;

entity adv7182a is
Port (
	RST_I			: in  STD_LOGIC;
	
	LLC_I			: in  STD_LOGIC;
	VSYNC_I			: in  STD_LOGIC;	-- Low during Frame
	HSYNC_I			: in  STD_LOGIC;	-- High during Data Valid
	DATA_I			: in  STD_LOGIC_VECTOR(7 downto 0);
	
	-- AXI Master
	M_AXIS_ACLK_O	: out STD_LOGIC := '0';
	M_AXIS_TVALID_O	: out STD_LOGIC := '0';
	M_AXIS_TLAST_O	: out STD_LOGIC := '0';
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TREADY_I	: in  STD_LOGIC	
);
end adv7182a;

architecture Behavioral of adv7182a is

signal data_buffer	: array8_t(4 downto 0) := (others => x"00");

signal sof			: std_logic_vector(4 downto 0) := (others => '0');
signal sol			: std_logic_vector(4 downto 0) := (others => '0');

signal dval			: std_logic := '0';
signal last_dval	: std_logic := '0';

signal fval			: std_logic := '0';
signal last_fval	: std_logic := '0';

signal field_start	: std_logic := '0';
signal field_end	: std_logic := '0';

signal start		: std_logic := '0';
signal stop			: std_logic := '0';
signal valid		: std_logic := '0';
signal ready		: std_logic := '0';

signal in_frame		: std_logic := '0';

signal color_pointer: integer range 0 to 1 := 0;
signal color_buffer	: array8_t(1 downto 0) := (others => x"00");
signal color_dval	: std_logic := '0';

begin

M_AXIS_ACLK_O		<= not LLC_I;

fval <= sof(sof'high);
dval <= sol(sol'high);	

process(M_AXIS_ACLK_O)
begin
	if rising_edge(M_AXIS_ACLK_O) then
		data_buffer(0) <= DATA_I;
		data_buffer(data_buffer'high downto 1) <= data_buffer(data_buffer'high-1 downto 0);
		
		--TODO: Wait for EOF before starting transmission/don't start in the middle of a frame
		
		-- SAV/EAV Sequence
		if  data_buffer(3) = x"FF"
		and data_buffer(2) = x"00"
		and data_buffer(1) = x"00" then
						
			if data_buffer(0)(5 downto 4) = "00" then		-- V and H = 0 Start of Field (No VBlank and SAV)
				field_start <= data_buffer(0)(6);
				sof(0) 		<= '1';
			elsif data_buffer(0)(5 downto 4) = "11" then	-- V and H = 1 End of Field (VBlank and EAV)
				field_end	<= data_buffer(0)(6);
				sof			<= (others => '0');
			end if;
		
			if data_buffer(0)(4) = '0' then	-- 0 at SAV, 1 at EAV
				sol(0) <= '1';
			else
				sol <= (others => '0');
			end if;
		else
			sof(sof'high downto 1) <= sof(sof'high-1 downto 0);
			sol(sol'high downto 1) <= sol(sol'high-1 downto 0);  
		end if;
			
		if in_frame = '0' then
			ready <= M_AXIS_TREADY_I;
		end if;	
					
		last_fval	<= fval;
		last_dval	<= dval;
		
		start	<= ready and (not last_fval and fval) and not field_start;	-- Start of field 0, Start of Frame
		stop	<= ready and (last_fval and not fval) and field_end;		-- End of Field 1, End of Frame
		valid	<= fval and dval and ready;
		
		if start = '1' then
			in_frame <= '1';
		elsif stop = '1' then			
			in_frame <= '0';
		end if;
		
		if RST_I = '1' then
			in_frame <= '0';
			sof	<= (others => '0');
			sol <= (others => '0');
		end if;
	end if;
end process;

M_AXIS_TUSER_O(1) <= stop and in_frame;

-- Flip Order of Y and Cb/Cr
process(M_AXIS_ACLK_O)
begin
	if rising_edge(M_AXIS_ACLK_O) then
		M_AXIS_TLAST_O		<= ready and in_frame and (last_dval and not dval);	-- End of Line
		M_AXIS_TUSER_O(0)	<= start;
		M_AXIS_TVALID_O		<= valid and (in_frame or start);
	
		color_dval <= dval;
	
		if dval = '1' then
			if color_pointer = 0 then
				color_buffer(0) <= data_buffer(data_buffer'high);
				color_pointer <= 1;
			else
				color_buffer(1) <= data_buffer(data_buffer'high);
				color_pointer <= 0;
			end if;
		else
			color_pointer <= 0;
		end if;
		
		if color_dval = '1' then
			M_AXIS_TDATA_O <= color_buffer(color_pointer);
		end if;
		
	end if;
end process;

end Behavioral;
