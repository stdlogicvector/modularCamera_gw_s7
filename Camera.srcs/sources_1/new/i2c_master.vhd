library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use UNISIM.vcomponents.all;

entity i2c_master is
	GENERIC (
		CLK_MHZ		: real := 100.0;
		SCL_KHZ		: real := 400.0
	);
	PORT (
		CLK_I		: in     STD_LOGIC;
		RST_I		: in     STD_LOGIC;
		
		SDA_IO		: inout  STD_LOGIC;
		SCL_IO		: inout  STD_LOGIC;
		
		EN_I		: in     STD_LOGIC;                    -- latch in command
		ADDR_I		: in     STD_LOGIC_VECTOR(6 DOWNTO 0);
		RW_I		: in     STD_LOGIC;                    -- '0' = write, '1' = read
		DATA_I		: in     STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		BUSY_O		: out    STD_LOGIC;
		DATA_O		: out    STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		ERROR_O		: buffer STD_LOGIC                    -- ACK error
	);
end i2c_master;

architecture RTL of i2c_master is

constant divider  	:  integer := integer((CLK_MHZ * 1000.0 / SCL_KHZ) / 4.0); --number of clocks in 1/4 cycle of SCL_IO
  
type state_t is (
	S_IDLE,
	S_START,
	S_COMMAND,
	S_SLV_ACK_1,
	S_WRITE,
	S_READ,
	S_SLV_ACK_2,
	S_MST_ACK,
	S_STOP
);
  
signal SCL_I		 : std_logic;
signal SCL_O		 : std_logic;
signal SDA_I		 : std_logic;
signal SDA_O		 : std_logic;
  
signal state         : state_t;
signal data_clk      : std_logic_vector(1 downto 0);

signal scl_clk       : std_logic;
signal scl_ena       : std_logic := '0';
signal sda_int       : std_logic := '1';
signal sda_ena_n     : std_logic;

signal addr_rw       : std_logic_vector(7 downto 0) := (others => '0');
signal data_tx       : std_logic_vector(7 downto 0) := (others => '0');
signal data_rx       : std_logic_vector(7 downto 0) := (others => '0');
signal bit_cnt       : integer range 0 to 7 := 7;

signal stretch       : std_logic := '0';

begin

process(CLK_I)
	variable count  :  integer range 0 to divider*4;
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') THEN
			stretch <= '0';
			count := 0;
		else
			data_clk(1) <= data_clk(0);
		  
			if (count = divider*4-1) then		--end of timing cycle
				count := 0;						--reset timer
			elsif (stretch = '0') then			--clock stretching from slave not detected
				count := count + 1;				--continue clock generation timing
			end if;
		  
			case count is
			when 0 to divider-1 =>				--first 1/4 cycle of clocking
				scl_clk		<= '0';
				data_clk(0) <= '0';
			  
			when divider to divider*2-1 => 		--second 1/4 cycle of clocking
				scl_clk		<= '0';
				data_clk(0) <= '1';
			
			when divider*2 to divider*3-1 => 	--third 1/4 cycle of clocking
				scl_clk <= '1'; 				--release scl_io
			
				if (SCL_I = '0') then			--detect if slave is stretching clock
					stretch <= '1';
				else
					stretch <= '0';
				end if;

				data_clk(0) <= '1';

			when others =>						--last 1/4 cycle of clocking
				scl_clk		<= '1';
				data_clk(0)	<= '0';
			end case;
		end if;
	end if;
end process;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
	    if (RST_I = '1') then
			state	<= S_IDLE;
			BUSY_O	<= '1';
			scl_ena	<= '0';
			sda_int <= '1';
			ERROR_O <= '0';
			bit_cnt <= 7;
			DATA_O	<= "00000000";   
		else

			if (data_clk = "01") then			-- rising edge
		  
				case state is
				when S_IDLE =>
					if (EN_I = '1') then
						BUSY_O <= '1';
						addr_rw <= ADDR_I & RW_I;
						data_tx <= DATA_I;
						
						state <= S_START;
					else
						BUSY_O <= '0';
						state <= S_IDLE;
					end if;
				
				when S_START =>
					BUSY_O <= '1';						--resume BUSY_O if continuous mode
					sda_int <= addr_rw(bit_cnt);		--set first address bit to bus
					state <= S_COMMAND;
				
				when S_COMMAND =>
					if (bit_cnt = 0) then
						sda_int <= '1';                --release SDA_IO for slave acknowledge
						bit_cnt <= 7;

						state <= S_SLV_ACK_1;
					else
						bit_cnt <= bit_cnt - 1;
						sda_int <= addr_rw(bit_cnt-1);
						
						state <= S_COMMAND;
					end if;
				
				WHEN S_SLV_ACK_1 =>
					if (addr_rw(0) = '0') then
						sda_int <= data_tx(bit_cnt);
						
						state <= S_WRITE;
					else
						sda_int <= '1';					--release SDA_IO from incoming data
						
						state <= S_READ;
					end if;
				
				WHEN S_WRITE =>
					BUSY_O <= '1';						--resume BUSY_O if continuous mode
					
					if (bit_cnt = 0) then
						sda_int <= '1';					--release SDA_IO for slave acknowledge
						bit_cnt <= 7;
						
						state <= S_SLV_ACK_2;
					else
						bit_cnt <= bit_cnt - 1;
						sda_int <= data_tx(bit_cnt-1);
						
						state <= S_WRITE;
					end if;
				
				when S_READ =>
					BUSY_O <= '1';						--resume BUSY_O if continuous mode
					
					if (bit_cnt = 0) then
						if (EN_I = '1' AND addr_rw = ADDR_I & RW_I) then
							sda_int <= '0';
						else
							sda_int <= '1';				--send a no-acknowledge (before S_STOP or repeated S_START)
						end if;

						bit_cnt <= 7;
						DATA_O <= data_rx;
						state <= S_MST_ACK;
					else
						bit_cnt <= bit_cnt - 1;
						state <= S_READ;
					end if;
				
				when S_SLV_ACK_2 =>
					if (EN_I = '1') then
						BUSY_O <= '0';
						addr_rw <= ADDR_I & RW_I;
						data_tx <= DATA_I;
						
						if (addr_rw = ADDR_I & RW_I) then
							sda_int <= DATA_I(bit_cnt);
							state <= S_WRITE;
						else
							state <= S_START;
						end if;
					else
						state <= S_STOP;
					end if;
				
				when S_MST_ACK =>
					if (EN_I = '1') then
						BUSY_O <= '0';
						addr_rw <= ADDR_I & RW_I;
						data_tx <= DATA_I;

						if (addr_rw = ADDR_I & RW_I) then
							sda_int <= '1';
							state <= S_READ;
						else
							state <= S_START;					--repeated S_START
						end if;    
					else
						state <= S_STOP;
					end if;
				
				when S_STOP =>
					BUSY_O <= '0';
					state <= S_IDLE;
				end case;    
			
			elsif (data_clk = "10") then						-- falling edge
				case state is
				when S_START =>                  
					if (scl_ena = '0') THEN						--starting new transaction
					  scl_ena <= '1';
					  ERROR_O <= '0';
					end if;

				WHEN S_SLV_ACK_1 =>
					if (SDA_I /= '0' OR ERROR_O = '1') then	--no-acknowledge or previous no-acknowledge
					  ERROR_O <= '1';
					end if;

				WHEN S_READ =>
					data_rx(bit_cnt) <= SDA_I;
				
				WHEN S_SLV_ACK_2 =>
					if (SDA_I /= '0' OR ERROR_O = '1') then	--no-acknowledge or previous no-acknowledge
					  ERROR_O <= '1';
					end if;

				WHEN S_STOP =>
					scl_ena <= '0';
				
				when others =>
					null;
				end case;
			end if;
		end if;
	end if;
end process;  

with state select
	sda_ena_n <= data_clk(1) when S_START,
			 NOT data_clk(1) when S_STOP,
			 sda_int when others;

  
--SCL_IO <= '0' when (scl_ena = '1' AND scl_clk = '0') else 'Z';
--SDA_IO <= '0' when sda_ena_n = '0' else 'Z';


SCL : IOBUF
generic map
(
	DRIVE		=> 12,
	IOSTANDARD	=> "DEFAULT",
	SLEW		=> "SLOW"
)
port map
(
	IO 	=> SCL_IO,							-- Buffer inout port (connect directly to top-level port)
  	O	=> SCL_I,							-- Buffer output
    I 	=> '0',								-- Buffer input
  	T 	=> not (not scl_clk and scl_ena)  	-- 3-state enable input, high=input, low=output 
);
  
SDA : IOBUF
generic map
(
	DRIVE		=> 12,
	IOSTANDARD	=> "DEFAULT",
	SLEW		=> "SLOW"
)
port map
(
	IO 	=> SDA_IO,			-- Buffer inout port (connect directly to top-level port)
  	O	=> SDA_I,			-- Buffer output
    I 	=> '0',				-- Buffer input
  	T 	=> sda_ena_n     	-- 3-state enable input, high=input, low=output 
);

end;
