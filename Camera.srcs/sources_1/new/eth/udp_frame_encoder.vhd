library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

-- Packet Format
-- [	2 bytes Meta Length 	]
-- [	x bytes Meta Data	 	]
-- [	2 bytes Image Format	]
-- [	2 bytes Image Length	]
-- [	x bytes Image Data		]

entity udp_frame_encoder is
	generic (
		PORT_NR			: integer	:= 16#1339#
	);
	port (
		-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
		-- UDP Interface
		TX_START_O		: out	std_logic := 'Z';
		TX_RTS_O		: out	std_logic := '0';
		TX_READY_I		: in	std_logic;
		TX_BUSY_I		: in	std_logic;
		
		TX_DV_O			: out	std_logic := 'Z';
		TX_DATA_O		: out	std_logic_vector( 7 downto 0) := (others => 'Z');
		TX_DST_MAC_O	: out	std_logic_vector(47 downto 0) := (others => 'Z');
		TX_DST_IP_O		: out	std_logic_vector(31 downto 0) := (others => 'Z');
		TX_SRC_PORT_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		TX_DST_PORT_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		TX_DATA_SIZE_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		
		-- Internal Interface
		IMG_AVAIL_I		: in	std_logic;
		IMG_DONE_O		: out	std_logic := '0';
		IMG_ADDR_O		: out	std_logic_vector(15 downto 0);
		IMG_DATA_I		: in	std_logic_vector( 7 downto 0) := (others => '0');
		IMG_LEN_I		: in	std_logic_vector(15 downto 0);
		IMG_MAP_LEN_I	: in	std_logic_vector(15 downto 0);
				
		META_READY_I	: in	std_logic;
		META_DONE_O		: out	std_logic;
		META_ADDR_O		: out	std_logic_vector(15 downto 0);
		META_DATA_I		: in	std_logic_vector( 7 downto 0);
		META_LEN_I		: in	std_logic_vector(15 downto 0);
		
		FRM_DST_MAC_I	: in	std_logic_vector(47 downto 0);
		FRM_DST_IP_I	: in	std_logic_vector(31 downto 0);
		FRM_DST_PORT_I	: in	std_logic_vector(15 downto 0) := int2vec(PORT_NR, 16)
	);
end udp_frame_encoder;

architecture Behavioral of udp_frame_encoder is

constant FRM_PORT	: std_logic_vector(15 downto 0) := int2vec(PORT_NR, 16);

type state_t is (
	S_IDLE,
	S_WAIT_FOR_BUSY,
	S_DELAY,
	S_START,
	S_WAIT_FOR_READY,
	S_META_HEADER_LO,
	S_META_HEADER_HI,
	S_TRANSMIT_META,
	S_IMAGE_HEADER_LO,
	S_IMAGE_HEADER_HI,
	S_IMAGE_FORMAT_HI,
	S_IMAGE_FORMAT_LO,
	S_TRANSMIT_IMAGE,
	S_END
);

signal state 			: state_t := S_IDLE;

signal tx_en			: std_logic := '0';

signal no_meta			: std_logic := '0';
signal no_img			: std_logic := '0';

signal active			: std_logic := '0';
signal tx_start			: std_logic := '0';
signal tx_data			: std_logic_vector( 7 downto 0) := (others => '0');
signal tx_dst_mac		: std_logic_vector(47 downto 0) := (others => '0');
signal tx_dst_ip		: std_logic_vector(31 downto 0) := (others => '0');
signal tx_src_port		: std_logic_vector(15 downto 0) := (others => '0');
signal tx_dst_port		: std_logic_vector(15 downto 0) := (others => '0');
signal tx_data_size		: std_logic_vector(15 downto 0) := (others => '0');

signal meta_addr		: std_logic_vector(15 downto 0) := (others => '0');
signal img_addr			: std_logic_vector(15 downto 0) := (others => '0');

constant DELAY			: integer := 2;
signal last_meta		: std_logic_vector(DELAY-1 downto 0) := (others => '0');
signal last_img			: std_logic_vector(DELAY-1 downto 0) := (others => '0');

begin

TX_START_O		<= tx_start		when active = '1' else 'Z';
TX_DV_O			<= tx_en		when active = '1' else 'Z';
TX_DATA_O		<= tx_data		when active = '1' else (others => 'Z');
TX_DST_MAC_O	<= tx_dst_mac	when active = '1' else (others => 'Z');
TX_DST_IP_O		<= tx_dst_ip	when active = '1' else (others => 'Z');
TX_DST_PORT_O	<= tx_dst_port	when active = '1' else (others => 'Z');
TX_SRC_PORT_O	<= tx_src_port	when active = '1' else (others => 'Z');
TX_DATA_SIZE_O	<= tx_data_size	when active = '1' else (others => 'Z');

IMG_ADDR_O		<= img_addr;
META_ADDR_O		<= meta_addr;

tx : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state		<= S_IDLE;
			tx_en		<= '0';
			active		<= '0';
		else
			tx_start	<= '0';
			IMG_DONE_O	<= '0';
			META_DONE_O	<= '0';
			
			case (state) is
			when S_IDLE =>
				TX_RTS_O <= '0';	
				tx_en <= '0';
				active <= '0';
				
				if (IMG_AVAIL_I = '1') AND (META_READY_I = '1') then
					TX_RTS_O 	<= '1';		
					tx_dst_mac	<= FRM_DST_MAC_I;
					tx_dst_ip	<= FRM_DST_IP_I;
					tx_dst_port	<= FRM_DST_PORT_I;
					tx_src_port	<= FRM_PORT;
					
					tx_data_size	<= add(add(META_LEN_I, IMG_LEN_I), 6);	-- 2bytes Metasize, 2bytes Imagesize, 2bytes Format
					
					if (META_LEN_I /= int2vec(0, 16)) then
						no_meta	<= '0';
					else
						no_meta <= '1';
					end if;
					
					if (IMG_LEN_I /= int2vec(0, 16)) then
						no_img <= '0';
					else
						no_img <= '1';
					end if;
					
					state <= S_WAIT_FOR_BUSY;
				end if;

			when S_WAIT_FOR_BUSY =>
				if (TX_BUSY_I = '0') then
					active <= '1';
					state <= S_DELAY;
				end if;
				
			when S_DELAY =>
				state <= S_START;
				
			when S_START =>
				tx_start <= '1';
				state <= S_WAIT_FOR_READY;
				
			when S_WAIT_FOR_READY =>
				if (TX_READY_I = '1') then
					state <= S_META_HEADER_HI;
					tx_en <= '1';
				end if;
				
			when S_META_HEADER_HI =>
				tx_data <= META_LEN_I(7 downto 0);
				state <= S_META_HEADER_LO;
				
			when S_META_HEADER_LO =>
				tx_data <= META_LEN_I(15 downto 8);
				
				if (no_meta = '1') then
					state <= S_IMAGE_HEADER_HI;
				else
					state <= S_TRANSMIT_META;
				end if;
				
			when S_TRANSMIT_META =>
				tx_data <= META_DATA_I;
								
				if (last_meta(last_meta'high-1) = '1') then
					META_DONE_O <= '1';
					state <= S_IMAGE_HEADER_HI;
				end if;
			
			when S_IMAGE_HEADER_HI =>
				tx_data 	<= IMG_LEN_I(7 downto 0);
				state 		<= S_IMAGE_HEADER_LO;
				
			when S_IMAGE_HEADER_LO =>
				tx_data <= IMG_LEN_I(15 downto 8);
				
				state <= S_IMAGE_FORMAT_HI;
				
			when S_IMAGE_FORMAT_HI =>
				tx_data 	<= IMG_MAP_LEN_I(7 downto 0);
				state 		<= S_IMAGE_FORMAT_LO;
				
			when S_IMAGE_FORMAT_LO =>
				tx_data 	<= IMG_MAP_LEN_I(15 downto 8);
				
				if (no_img = '1') then
					state <= S_END;
				else
					state <= S_TRANSMIT_IMAGE;
				end if;	
			
			when S_TRANSMIT_IMAGE =>
				tx_data <= IMG_DATA_I;
								
				if (last_img(last_img'high-1) = '1') then
					IMG_DONE_O	<= '1';
					state 		<= S_END;
				end if;
				
			when S_END =>
				tx_en  	 	<= '0';
				if (IMG_AVAIL_I = '0') then
					state 		<= S_IDLE;
				end if;
			
			end case;
		end if;
	end if;
end process;

incr : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		--last_meta(0)	<= '0';
		--last_img(0) 	<= '0';
		
		last_meta(last_meta'high downto 1)	<= last_meta(last_meta'high-1 downto 0); 
		last_img(last_img'high downto 1)	<= last_img(last_img'high-1 downto 0);
				
		case (state) is
		when S_IDLE | S_END =>
			meta_addr	<= (others => '0');
			img_addr	<= (others => '0');
			last_meta	<= (others => '0');
			last_img	<= (others => '0');

		when S_META_HEADER_HI |
			 S_META_HEADER_LO |
			 S_TRANSMIT_META =>
			if (last_meta(0) = '0') then
				if (meta_addr = META_LEN_I) then
					last_meta(0) <= '1';
				else
					meta_addr <= inc(meta_addr);
				end if;
			end if;
				
		when S_IMAGE_FORMAT_HI |
			 S_IMAGE_FORMAT_LO |
			 S_TRANSMIT_IMAGE =>

			if (last_img(0) = '0') then
				if (img_addr = IMG_LEN_I) then
					last_img(0) <= '1';
				else
					img_addr <= inc(img_addr);
				end if;
			end if;
		
		when others => NULL;	
		
		end case;

	end if;
end process;

end architecture;