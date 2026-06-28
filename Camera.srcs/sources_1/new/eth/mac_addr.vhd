library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.all;
use Work.util.all;

entity mac_addr is
	Port (
		CLK_I 		: in STD_LOGIC;
		RESET_I 	: in STD_LOGIC;
		
		PREFIX_I 	: in STD_LOGIC_VECTOR (23 downto 0) := x"54_4C_4C";
		MAC_O 		: out STD_LOGIC_VECTOR (47 downto 0) := (others => '0')
	);
end mac_addr;

architecture Behavioral of mac_addr is

signal shift		: std_logic := '0';
signal read			: std_logic := '0';
signal dout			: std_logic := '0';

signal count		: integer range 0 to 63 := 0;

signal mac			: std_logic_vector(23 downto 0) := (others => '0');
signal mac_shift	: std_logic_vector(23 downto 0) := (others => '0');

signal dna_clk		: std_logic := '0';		-- MAX Clockrate DNA Block = 100MHz

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			shift		<= '0';
			read		<= '0';
			count		<= 0;
			dna_clk		<= '0';
--			mac			<= (others => '0');
		else
			read	<= '0';
			shift	<= '0';
			
			dna_clk	<= not dna_clk;
			
			if (dna_clk = '1') then
				if (count = 0) then
					read <= '1';
					count <= count + 1;
				else
					if (count < 58) then
						count <= count + 1;
						shift <= '1';
						
						mac_shift <= mac_shift(mac_shift'high-1 downto 0) & dout;
					else
						mac_shift	<= mac_shift;
						count 		<= count;
						mac			<= mac_shift;
					end if;
				end if;
				
			end if;
			
			MAC_O <= mac & PREFIX_I;
		end if;
	end if;
end process;

DNA : DNA_PORT
generic map (
  SIM_DNA_VALUE => x"DEAD_BEEF_1234_567"  -- Specifies a sample 57-bit DNA value for simulation
)
port map (
	CLK => dna_clk,    	-- 1-bit input: Clock input.
	
	READ => read,   	-- 1-bit input: Active high load DNA, active low read input.
	SHIFT => shift,  	-- 1-bit input: Active high shift enable input.
	
	DOUT => dout,   	-- 1-bit output: DNA output data.
	DIN => '0'     		-- 1-bit input: User data input pin.
);

end Behavioral;
