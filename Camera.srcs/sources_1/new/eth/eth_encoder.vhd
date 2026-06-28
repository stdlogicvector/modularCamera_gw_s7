library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity eth_encoder is
	port(
		-- system signals
		CLK_I		: in	std_logic;
		RESET_I		: in	std_logic;
	
		MAC_ADDR_I	: in	std_logic_vector(47 downto 0);
	
		-- GMII
		PHY_TXD_O   : out 	std_logic_vector(7 downto 0) := (others => '0');
		PHY_TX_EN_O	: out 	std_logic := '0';
		PHY_TX_ER_O	: out	std_logic := '0';
		
		-- from next layer
		START_I		: in	std_logic;
		BUSY_O		: out	std_logic := '0';
		READY_O		: out	std_logic := '0';
		
		DV_I		: in 	std_logic;
		DATA_I		: in	std_logic_vector(7 downto 0) := (others => '0');
		
		DST_MAC_I 	: in	std_logic_vector(47 downto 0) := (others => '0');
		ETHERTYPE_I	: in	std_logic_vector(15 downto 0)
	);
end eth_encoder;

architecture Behavioral of eth_encoder is
	-- constants

	-- types
	type state_t is (
		S_IDLE,
		S_PREAMBLE,
		S_SFD,
		S_DST_MAC,
		S_SRC_MAC,
		S_ETHER_TYPE,
		S_PAYLOAD,
		S_PADDING,
		S_FCS,
		S_IPG
	);
	
	-- statemachine
	signal state 	: state_t := S_IDLE;
		
	-- crc signals
	signal crc_reset 	: std_logic := '1';
	signal crc_enable	: std_logic := '0';
	signal crc_out		: std_logic_vector(31 downto 0) := (others => '0');

	-- other signals
	signal tx_en		: std_logic := '0';
	signal tx_data	 	: std_logic_vector(7 downto 0) := (others => '0');

	-- counters
	signal byte_count 	: integer range 0 to 63 := 0;
	 
	-- local registers
	signal dst_mac		: std_logic_vector(47 downto 0) := (others => '0');
	signal ethertype	: std_logic_vector(15 downto 0) := (others => '0');
	
begin


---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

PHY_TXD_O	<= tx_data;
PHY_TX_EN_O <= tx_en;

PHY_TX_ER_O <= '0';	-- TODO: Error Handling

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

fsm: process(CLK_I, RESET_I)

procedure transmit(p : std_logic_vector; next_state : state_t) is
	begin
		-- we split the vector into bytes and send them
		if (byte_count < (p'length/8)) then
			tx_data <= byte(p, byte_count);
		end if;
			
		-- on the next-to-eol byte we change to the next state
		if (byte_count = (p'length/8) - 1)
		then
			byte_count <= 0;
			state <= next_state;
		end if;
	end procedure;

procedure send_bytes(n : integer; next_state : state_t) is
	begin
		-- on the next-to-eol byte we change to the next state
		if (byte_count = n - 1)
		then
			byte_count <= 0;
			state <= next_state;
		end if;
	end procedure;	

begin
	if (rising_edge(CLK_I)) then
		if (RESET_I = '1') then
			state <= S_IDLE;
			
			tx_en <= '0';
			
			READY_O <= '0';
			BUSY_O  <= '0';
			
			crc_reset <= '1';
		else
			if byte_count < 63 then
				byte_count <= byte_count + 1;
			end if;
		
			case state is
				when S_IDLE =>
					tx_en <= '0';
					
					crc_reset  <= '1';
					crc_enable <= '0';
					
					BUSY_O  <= '0';
					READY_O <= '0';
					
					byte_count <= 0;
				
					if (START_I = '1') then
						BUSY_O <= '1';
						
						dst_mac <= DST_MAC_I;
						ethertype <= ETHERTYPE_I(7 downto 0) & ETHERTYPE_I(15 downto 8);
						state <= S_PREAMBLE;
					end if;
				
				when S_PREAMBLE =>
					tx_en <= '1';
					tx_data <= "01010101";
					
					send_bytes(7, S_SFD);
			
				when S_SFD =>
					transmit("11010101", S_DST_MAC);
			
				when S_DST_MAC =>				
					crc_reset <= '0';
					crc_enable <= '1';
					
					transmit(dst_mac, S_SRC_MAC);
				
				when S_SRC_MAC =>			
					transmit(MAC_ADDR_I, S_ETHER_TYPE);			

					if (byte_count = 5) then
						READY_O <= '1';		-- 2 cycles before payload is needed
					end if;	

				when S_ETHER_TYPE =>			
					transmit(ethertype, S_PAYLOAD);
					
				when S_PAYLOAD =>
					tx_data <= DATA_I;					
										
					if (DV_I = '1') then
						state <= S_PAYLOAD;
					else
						READY_O   <= '0';
						
						if (byte_count > 44) then
							state 		<= S_FCS;
							byte_count  <= 0;
						else
							state 		<= S_PADDING;
						end if;
					end if;
					
				when S_PADDING =>
					tx_data <= (others => '0');
					
					if (byte_count = 45) then
						state 		<= S_FCS;
						byte_count  <= 0;					
					end if;
					
				when S_FCS =>
					crc_enable <= '0';
					transmit(crc_out, S_IPG);
					
				when S_IPG =>
					tx_en <= '0';
					transmit(x"0000_0000_0000_0000", S_IDLE);
					
				end case;
		end if;
	end if;
end process;

---------------------------------------------------------------------------------------------
-- instances
---------------------------------------------------------------------------------------------

crc : entity work.crc32
port map(
	CLK_I		=> CLK_I,
	RESET_I		=> crc_reset,
	CRC_EN_I	=> crc_enable,
	CRC_O		=> crc_out,
	DATA_I		=> bit_reverse(tx_data)
);

end Behavioral;
