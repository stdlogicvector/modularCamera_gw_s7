library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity udp_frame_transmitter is
	generic (
		PORT_NR			: integer	:= 16#1339#
	);
	port (
		-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
		-- UDP Interface
		TX_RTS_O		: out	std_logic := '0';
		TX_START_O		: out	std_logic := 'Z';
		TX_READY_I		: in	std_logic;
		TX_BUSY_I		: in	std_logic;
		
		TX_DV_O			: out	std_logic := '0';
		TX_DATA_O		: out	std_logic_vector( 7 downto 0) := (others => 'Z');
		TX_DST_MAC_O	: out	std_logic_vector(47 downto 0) := (others => 'Z');
		TX_DST_IP_O		: out	std_logic_vector(31 downto 0) := (others => 'Z');
		TX_SRC_PORT_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		TX_DST_PORT_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		TX_DATA_SIZE_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		
		-- Internal Interface
		AVAIL_I			: in	std_logic;
		
		-- AXI Slave
		S_AXIS_TVALID_I	: in  STD_LOGIC;
		S_AXIS_TLAST_I	: in  STD_LOGIC;
		S_AXIS_TDATA_I	: in  STD_LOGIC_VECTOR(7 downto 0);
		S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
		S_AXIS_TREADY_O	: out STD_LOGIC;

		PKT_BPP_I		: in	std_logic_vector( 7 downto 0);
		PKT_LINE_I		: in	std_logic_vector(15 downto 0);
		PKT_FRAME_I		: in	std_logic_vector(15 downto 0);
		PKT_LEN_I		: in	std_logic_vector(15 downto 0);

		FRM_DST_MAC_I	: in	std_logic_vector(47 downto 0);
		FRM_DST_IP_I	: in	std_logic_vector(31 downto 0);
		FRM_DST_PORT_I	: in	std_logic_vector(15 downto 0) := int2vec(PORT_NR, 16)
	);
end udp_frame_transmitter;

architecture Behavioral of udp_frame_transmitter is

constant FRM_PORT	: std_logic_vector(15 downto 0) := int2vec(PORT_NR, 16);

type state_t is (
	S_IDLE,
	S_WAIT_FOR_BUSY,
	S_START,
	S_DELAY,
	S_WAIT_FOR_READY,
	S_FRAME_HI,
	S_FRAME_LO,
	S_LINE_HI,
	S_LINE_LO,
	S_DEPTH,
	S_SIZE_HI,
	S_SIZE_LO,
	S_TRANSMIT_DATA,
	S_END
);

signal state 			: state_t := S_IDLE;

signal tx_en			: std_logic := '0';

signal active			: std_logic := '0';
signal tx_start			: std_logic := '0';
signal tx_data			: std_logic_vector( 7 downto 0) := (others => '0');
signal tx_dst_mac		: std_logic_vector(47 downto 0) := (others => '0');
signal tx_dst_ip		: std_logic_vector(31 downto 0) := (others => '0');
signal tx_src_port		: std_logic_vector(15 downto 0) := (others => '0');
signal tx_dst_port		: std_logic_vector(15 downto 0) := (others => '0');
signal tx_data_size		: std_logic_vector(15 downto 0) := (others => '0');

signal pkt_addr			: std_logic_vector(15 downto 0) := (others => '0');

begin

TX_START_O		<= tx_start		when active = '1' else '0';
TX_DV_O			<= tx_en		when active = '1' else '0';
TX_DATA_O		<= tx_data		when active = '1' else (others => 'Z');
TX_DST_MAC_O	<= tx_dst_mac	when active = '1' else (others => 'Z');
TX_DST_IP_O		<= tx_dst_ip	when active = '1' else (others => 'Z');
TX_DST_PORT_O	<= tx_dst_port	when active = '1' else (others => 'Z');
TX_SRC_PORT_O	<= tx_src_port	when active = '1' else (others => 'Z');
TX_DATA_SIZE_O	<= tx_data_size	when active = '1' else (others => 'Z');

tx : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state		<= S_IDLE;
			TX_RTS_O	<= '0';
			tx_en		<= '0';
			active		<= '0';
		end if;
--		else
			tx_start	<= '0';
			S_AXIS_TREADY_O	<= '0';
		
			case (state) is
			when S_IDLE =>
				tx_en <= '0';
				active <= '0';
				TX_RTS_O	<= '0';
				
				if (AVAIL_I = '1') then
					TX_RTS_O	<= '1';
							
					tx_dst_mac	<= FRM_DST_MAC_I;
					tx_dst_ip	<= FRM_DST_IP_I;
					tx_dst_port	<= FRM_DST_PORT_I;
					tx_src_port	<= FRM_PORT;
					
					tx_data_size	<= add(PKT_LEN_I, 7);
					
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
				tx_start	<= '1';
				pkt_addr	<= (others => '0');
				state		<= S_WAIT_FOR_READY;
				
			when S_WAIT_FOR_READY =>
				if (TX_READY_I = '1') then
					state	<= S_FRAME_HI;
				end if;
			
			when S_FRAME_HI =>
				tx_en		<= '1';
				tx_data 	<= PKT_FRAME_I(7 downto 0);
				state 		<= S_FRAME_LO;
			
			when S_FRAME_LO =>
				tx_en		<= '1';
				tx_data		<= PKT_FRAME_I(15 downto 8);
				state		<= S_LINE_HI;
				
			when S_LINE_HI =>
				tx_en		<= '1';
				tx_data 	<= PKT_LINE_I(7 downto 0);
				state 		<= S_LINE_LO;
			
			when S_LINE_LO =>
				tx_en		<= '1';
				tx_data		<= PKT_LINE_I(15 downto 8);
				state		<= S_DEPTH;
			
			when S_DEPTH =>
				tx_en		<= '1';
				tx_data 	<= PKT_BPP_I;
				state 		<= S_SIZE_HI;
								
			when S_SIZE_HI =>
				tx_en		<= '1';
				tx_data 	<= PKT_LEN_I(7 downto 0);
				pkt_addr	<= inc(pkt_addr);
				state 		<= S_SIZE_LO;
			
			-- Header provides 1 cycle delay for FIFO to provide data
			when S_SIZE_LO =>
				S_AXIS_TREADY_O	<= '1';
				tx_data		<= PKT_LEN_I(15 downto 8);
				pkt_addr	<= inc(pkt_addr);
				state		<= S_TRANSMIT_DATA;	
			
			when S_TRANSMIT_DATA =>
				tx_data		<= S_AXIS_TDATA_I;
				pkt_addr	<= inc(pkt_addr);
				
				if (pkt_addr < PKT_LEN_I) then
					S_AXIS_TREADY_O	<= '1';
				end if;
				
				if (pkt_addr > PKT_LEN_I) then
					state 		<= S_END;
				end if;
				
			when S_END =>
				tx_en  	 	<= '0';
				TX_RTS_O	<= '0';
				
				if AVAIL_I = '0' then -- TODO
					state 		<= S_IDLE;
				end if;
			
			end case;
--		end if;
	end if;
end process;

end architecture;