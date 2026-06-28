library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.util.all;

entity axi_upscale is
Generic (
	INPUT_WIDTH		: integer := 8;
	INPUT_HEIGHT	: integer := 8;
	FACTOR_WIDTH	: integer := 8;
	DATA_WIDTH		: integer := 8
);
Port (
	RST_I				: in  STD_LOGIC;
	
	X_FACTOR_I			: in  STD_LOGIC_VECTOR(FACTOR_WIDTH-1 downto 0);
	Y_FACTOR_I			: in  STD_LOGIC_VECTOR(FACTOR_WIDTH-1 downto 0);	
	
	-- AXI Slave
	S_AXIS_ACLK_I		: in  STD_LOGIC;
	S_AXIS_TVALID_I		: in  STD_LOGIC;
	S_AXIS_TLAST_I		: in  STD_LOGIC;
	S_AXIS_TDATA_I		: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	S_AXIS_TUSER_I		: in  STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TREADY_O		: out STD_LOGIC;
	
	-- AXI Master
	M_AXIS_ACLK_O		: out STD_LOGIC := '0';
	M_AXIS_TVALID_O		: out STD_LOGIC := '0';
	M_AXIS_TLAST_O		: out STD_LOGIC := '0';
	M_AXIS_TUSER_O		: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TDATA_O		: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
	M_AXIS_TREADY_I		: in  STD_LOGIC	
);
end axi_upscale;

architecture NearestNeighbor of axi_upscale is

constant RAM_DEPTH		: integer := clogb2(INPUT_HEIGHT * INPUT_WIDTH);

signal write_buffer		: std_logic := '0';
signal write_enable		: std_logic := '0';
signal write_addr		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');
signal write_data		: std_logic_vector(DATA_WIDTH+3-1 downto 0) := (others => '0');
signal write_switch		: std_logic := '0';
signal write_done		: std_logic := '0';

signal read_buffer		: std_logic := '0';
signal read_addr		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');
signal read_data		: std_logic_vector(DATA_WIDTH+3-1 downto 0) := (others => '0');
signal read_done		: std_logic := '0';

type rstate_t			is (S_IDLE, S_READING);

signal read_state		: rstate_t := S_IDLE;

signal x_factor			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;
signal y_factor			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;
signal x_count			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;
signal y_count			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;

signal frame_start		: std_logic := '0';
signal line_start		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');

signal val_delay		: std_logic_vector(1 downto 0) := (others => '0');
signal eol_delay		: std_logic_vector(1 downto 0) := (others => '0');
signal sof_delay		: std_logic_vector(1 downto 0) := (others => '0');
signal eof_delay		: std_logic_vector(1 downto 0) := (others => '0');

begin

M_AXIS_ACLK_O <= S_AXIS_ACLK_I;

ram : entity work.ram
generic map (
	RAM_WIDTH	=> DATA_WIDTH + 3,
	RAM_DEPTH	=> 2**(RAM_DEPTH+1) -- Double Buffering
)
port map (
	RESET_I		=> RST_I,
	
	A_CLK_I		=> S_AXIS_ACLK_I,
	A_ENA_I		=> '1',
	A_WEN_I		=> write_enable,
	A_ADDR_I	=> write_buffer & write_addr,
	A_DATA_I	=> write_data,
	
	B_CLK_I		=> M_AXIS_ACLK_O,
	B_ENA_I		=> '1',
	B_WEN_I		=> '0',
	B_ADDR_I	=> read_buffer & read_addr,
	B_DATA_O	=> read_data
);

write_enable <= S_AXIS_TVALID_I;
write_data	 <= S_AXIS_TUSER_I & S_AXIS_TLAST_I & S_AXIS_TDATA_I;

store : process(S_AXIS_ACLK_I)
begin
	if rising_edge(S_AXIS_ACLK_I) then
		write_done <= '0';
		
		if read_done = '1' then		-- Reading has finished
			write_switch <= '1';	-- Switch buffer for next Frame
		end if;
			
		if S_AXIS_TUSER_I(1) = '1' then		-- EOF
			write_done <= '1';
			write_addr <= (others => '0');
		elsif S_AXIS_TVALID_I = '1' then
			write_addr <= inc(write_addr);
		end if;
		
		if S_AXIS_TUSER_I(0) = '1' then 	-- SOF
			if write_switch = '1' then		-- Switch buffer if reading has finished
				write_switch <= '0';
				write_buffer <= not write_buffer;
			end if;
		end if;
		
	end if;
end process;

output : process(M_AXIS_ACLK_O)
begin
	if rising_edge(M_AXIS_ACLK_O) then
		read_done <= '0';
		
		val_delay(0) <= '0';
		eol_delay(0) <= '0';
		sof_delay(0) <= '0';
		eof_delay(0) <= '0';
		
		case read_state is
		when S_IDLE =>
			S_AXIS_TREADY_O <= M_AXIS_TREADY_I;
			
			x_factor <= vec2int(X_FACTOR_I) - 1;
			y_factor <= vec2int(Y_FACTOR_I) - 1;
			
			x_count <= 0;
			y_count <= 0;
			
			read_addr <= (others => '0');
			frame_start <= '1';
			
			if write_done = '1' then
				read_buffer <= write_buffer;	-- Read from buffer that was just written to
				read_state  <= S_READING;
			end if;
			
		when S_READING =>
			val_delay(0) <= '1';
					
			sof_delay(0) <= frame_start;
			frame_start <= '0';
					
			if x_count < x_factor then
				x_count <= x_count + 1;
			else
				if read_data(DATA_WIDTH) = '1' then	-- EOL
					eol_delay(0) <= '1';
					
					if y_count < y_factor then
						read_addr <= line_start;	-- Jump back to start of line
						y_count <= y_count + 1;
					else
						if read_data(DATA_WIDTH+2) = '1' then 	-- EOF
							eof_delay(0) <= '1';
							read_state <= S_IDLE;
							read_done <= '1';
						end if;						
					
						y_count <= 0;
						read_addr  <= inc(read_addr);
						line_start <= inc(read_addr);
					end if;
				else
					read_addr <= inc(read_addr);
				end if;
				
				x_count <= 0;
			end if;
		
		end case;
		
		val_delay(1) <= val_delay(0);
		eof_delay(1) <= eof_delay(0);
		sof_delay(1) <= sof_delay(0);
		eol_delay(1) <= eol_delay(0);
		
		M_AXIS_TVALID_O	<= val_delay(1);
		M_AXIS_TLAST_O	<= eol_delay(1);
		M_AXIS_TUSER_O	<= eof_delay(1) & sof_delay(1);
		M_AXIS_TDATA_O	<= read_data(DATA_WIDTH-1 downto 0);
		
	end if;
end process;

end NearestNeighbor;

architecture Bilinear of axi_upscale is

constant RAM_DEPTH		: integer := clogb2(INPUT_HEIGHT * INPUT_WIDTH);

signal write_buffer		: std_logic := '0';
signal write_enable		: std_logic := '0';
signal write_addr		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');
signal write_data		: std_logic_vector(DATA_WIDTH+3-1 downto 0) := (others => '0');
signal write_switch		: std_logic := '0';
signal write_done		: std_logic := '0';

signal read_buffer		: std_logic := '0';
signal read_addr		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');
signal read_data		: std_logic_vector(DATA_WIDTH+3-1 downto 0) := (others => '0');
signal read_done		: std_logic := '0';

signal w_count			: integer range 0 to INPUT_WIDTH-1 := 0;
signal width			: integer range 0 to INPUT_WIDTH-1 := 0;
signal h_count			: integer range 0 to INPUT_HEIGHT-1 := 0;
signal height			: integer range 0 to INPUT_HEIGHT-1 := 0;

type rstate_t			is (S_IDLE, S_READ_X0Y0, S_READ_X1, S_READ_Y1, S_READING);

signal read_state		: rstate_t := S_IDLE;

signal frame_start		: std_logic := '1';
signal line_start		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');

signal val_delay		: std_logic_vector(1 downto 0) := (others => '0');
signal eol_delay		: std_logic_vector(1 downto 0) := (others => '0');
signal sof_delay		: std_logic_vector(1 downto 0) := (others => '0');
signal eof_delay		: std_logic_vector(1 downto 0) := (others => '0');

signal x_factor			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;
signal y_factor			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;
signal x_count			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;
signal y_count			: integer range 0 to 2**(FACTOR_WIDTH)-1 := 0;

signal x0y0_state		: std_logic_vector(2 downto 0);
signal x0y0				: signed(DATA_WIDTH downto 0);
signal x1				: signed(DATA_WIDTH downto 0);
signal y1				: signed(DATA_WIDTH downto 0);

signal dx				: signed(DATA_WIDTH downto 0);
signal dy				: signed(DATA_WIDTH downto 0);

-- width = 3; 0-7; Shift by 7 = div by 128

signal sx				: signed(2**(FACTOR_WIDTH)-1 downto 0);
signal sy				: signed(2**(FACTOR_WIDTH)-1 downto 0);

begin

assert FACTOR_WIDTH < 5 report "FactorWidth must be less than 5" severity ERROR;

M_AXIS_ACLK_O <= S_AXIS_ACLK_I;

ram : entity work.ram
generic map (
	RAM_WIDTH	=> DATA_WIDTH + 3,
	RAM_DEPTH	=> 2**(RAM_DEPTH+1) -- Double Buffering
)
port map (
	RESET_I		=> RST_I,
	
	A_CLK_I		=> S_AXIS_ACLK_I,
	A_ENA_I		=> '1',
	A_WEN_I		=> write_enable,
	A_ADDR_I	=> write_buffer & write_addr,
	A_DATA_I	=> write_data,
	
	B_CLK_I		=> M_AXIS_ACLK_O,
	B_ENA_I		=> '1',
	B_WEN_I		=> '0',
	B_ADDR_I	=> read_buffer & read_addr,
	B_DATA_O	=> read_data
);

write_enable <= S_AXIS_TVALID_I;
write_data	 <= S_AXIS_TUSER_I & S_AXIS_TLAST_I & S_AXIS_TDATA_I;

store : process(S_AXIS_ACLK_I)
begin
	if rising_edge(S_AXIS_ACLK_I) then
		write_done <= '0';
		
		if read_done = '1' then		-- Reading has finished
			write_switch <= '1';	-- Switch buffer for next Frame
		end if;
			
		if S_AXIS_TUSER_I(1) = '1' then		-- EOF
			h_count <= 0;
			height 	<= h_count;
			
			write_done <= '1';
			write_addr <= (others => '0');
		elsif S_AXIS_TVALID_I = '1' then
			w_count <= w_count + 1;
			write_addr <= inc(write_addr);
		end if;
		
		if S_AXIS_TLAST_I = '1' then
			h_count <= h_count + 1;
			w_count <= 0;
			width	<= w_count;
		end if;
		
		if S_AXIS_TUSER_I(0) = '1' then 	-- SOF
			if write_switch = '1' then		-- Switch buffer if reading has finished
				write_switch <= '0';
				write_buffer <= not write_buffer;
			end if;
		end if;
		
	end if;
end process;

output : process(M_AXIS_ACLK_O)
begin
	if rising_edge(M_AXIS_ACLK_O) then
		read_done <= '0';
		
		val_delay(0) <= '0';
		eol_delay(0) <= '0';
		sof_delay(0) <= '0';
		eof_delay(0) <= '0';
		
		case read_state is
		when S_IDLE =>
			S_AXIS_TREADY_O <= M_AXIS_TREADY_I;
			
			x_factor <= vec2int(X_FACTOR_I);
			y_factor <= vec2int(Y_FACTOR_I);
			
			x_count <= 0;
			y_count <= 0;
			
			read_addr <= (others => '0');
			frame_start <= '1';
			
			if write_done = '1' then
				read_buffer <= write_buffer;	-- Read from buffer that was just written to
				read_state  <= S_READ_X0Y0;
			end if;
			
		when S_READ_X0Y0 =>
			x0y0_state <= read_data(read_data'high downto read_data'high-3);	-- Remember state bits for later
			x0y0 <= signed("0" & read_data(DATA_WIDTH-1 downto 0));
			
			read_addr <= inc(read_addr);
			read_state <= S_READ_X1;
			
		when S_READ_X1 =>
			x1	<= signed("0" & read_data(DATA_WIDTH-1 downto 0));
		
			
		when S_READING =>
			val_delay(0) <= '1';
					
			sof_delay(0) <= frame_start;
			frame_start <= '0';
					
			if x_count < x_factor then
				x_count <= x_count + 1;
			else
				if read_data(DATA_WIDTH) = '1' then	-- EOL
					eol_delay(0) <= '1';
					
					if y_count < y_factor then
						read_addr <= line_start;	-- Jump back to start of line
						y_count <= y_count + 1;
					else
						if read_data(DATA_WIDTH+2) = '1' then 	-- EOF
							eof_delay(0) <= '1';
							read_state <= S_IDLE;
							read_done <= '1';
						end if;						
					
						y_count <= 0;
						read_addr  <= inc(read_addr);
						line_start <= inc(read_addr);
					end if;
				else
					read_addr <= inc(read_addr);
				end if;
				
				x_count <= 0;
			end if;
		
		end case;
		
		val_delay(1) <= val_delay(0);
		eof_delay(1) <= eof_delay(0);
		sof_delay(1) <= sof_delay(0);
		eol_delay(1) <= eol_delay(0);
		
		M_AXIS_TVALID_O	<= val_delay(1);
		M_AXIS_TLAST_O	<= eol_delay(1);
		M_AXIS_TUSER_O	<= eof_delay(1) & sof_delay(1);
		M_AXIS_TDATA_O	<= read_data(DATA_WIDTH-1 downto 0);
	end if;
end process;

end Bilinear;
