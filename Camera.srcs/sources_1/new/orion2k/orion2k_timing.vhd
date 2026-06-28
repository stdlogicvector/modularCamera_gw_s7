library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity orion2k_timing is
generic (
	CLOCK_MHZ		: real := 80.0 -- MHz
);
port (
	-- Internal
	CLK_I			: IN	STD_LOGIC;
	RST_I			: IN	STD_LOGIC;
	
	ENABLE_I		: IN	STD_LOGIC;
	TRIGGER_I		: IN	STD_LOGIC;
	
	INTEGRATING_O	: OUT	STD_LOGIC;
	END_OF_LINE_O	: OUT	STD_LOGIC;
	
	INT_CLKS_I		: IN	STD_LOGIC_VECTOR(15 downto 0);	-- Insert Integration Time Clocks
	DELAY_CLKS_I	: IN	STD_LOGIC_VECTOR(15 downto 0);	-- Insert Delay Clocks to change Linerate 
	
	-- External
	RST_CVC_O		: OUT	STD_LOGIC;
	RST_CDS_O		: OUT	STD_LOGIC;
	SAMPLE_O		: OUT	STD_LOGIC;
	START_ADC_O		: OUT	STD_LOGIC;
	START_READOUT_O	: OUT	STD_LOGIC
);
end orion2k_timing;

architecture RTL of orion2k_timing is

constant CLOCK_PERIOD		: real := 1000.0 / CLOCK_MHZ;	-- ns

type sampling_state_t is (IDLE, DELAY, RESET_CVC, RESET_CDS, INTEGRATE, SAMPLE_PULSE);
signal s_state : sampling_state_t := IDLE;

type convert_state_t is (IDLE, CONV_DELAY, START_CONV, CONVERTING, START_READ);
signal c_state : convert_state_t := IDLE;

type readout_state_t is (IDLE, READ_DELAY, START_READOUT, READING);
signal r_state : readout_state_t := IDLE;

-- Sampling Timing Values
constant clks_500ns	: integer := max(integer(ceil(500.0 / CLOCK_PERIOD)), 25);

constant min_clks	   	: std_logic_vector(15 downto 0) := int2vec(568 - 2, 16);
constant min_integ_clks : std_logic_vector(15 downto 0) := int2vec(568-clks_500ns*2 - 2, 16);		-- 568 - CVC - CDS - Sample
signal rst_cvc_clks		: std_logic_vector(15 downto 0) := int2vec(clks_500ns - 2, 16);
constant rst_cds_clks	: std_logic_vector(15 downto 0) := int2vec(clks_500ns - 1, 16);
constant sample_clks	: std_logic_vector(15 downto 0) := int2vec(clks_500ns - 2, 16);				-- 23 clks / 460ns
	
signal delay_clks 		: std_logic_vector(15 downto 0) := (others => '0');
signal integ_clks 		: std_logic_vector(15 downto 0) := int2vec(100, 16);

-- Conversion Timing Values
constant delay_ad_clks	: std_logic_vector(15 downto 0) := int2vec(  8 - 1, 16);					-- End of Sample Pulse to ADC Pulse
constant strt_ad_clks 	: std_logic_vector(15 downto 0) := int2vec(  4 - 1, 16);					-- Length of ADC Pulse
constant convert_clks 	: std_logic_vector(15 downto 0) := int2vec(548 - 1, 16);					-- End of ADC Pulse to ReadOut Pulse

-- Readout Timing Values
constant delay_ro_clks	: std_logic_vector(15 downto 0) := int2vec(  9 - 1, 16);					-- End of ADC Time to ReadOut Pulse
constant strt_ro_clks 	: std_logic_vector(15 downto 0) := int2vec(  4 - 1, 16);
constant reading_clks 	: std_logic_vector(15 downto 0) := int2vec(548 - 1, 16);

-- StateMachine Cycle Counter
signal s_counter 		: std_logic_vector(15 downto 0) := (others => '0');
signal c_counter 		: std_logic_vector(15 downto 0) := (others => '0');
signal r_counter 		: std_logic_vector(15 downto 0) := (others => '0');

-- Control Signals
signal trig_edge  		: std_logic_vector(1 downto 0) := (others => '0');
signal triggered		: std_logic := '0';
signal enable			: std_logic := '0';

signal go_convert		: std_logic := '0';
signal go_readout		: std_logic := '0';

signal reset_conv		: std_logic := '0';

-- Sensor Signals
signal rst_cvc			: std_logic := '1';
signal rst_cds			: std_logic := '1';
signal sample			: std_logic := '0';
signal start_ad			: std_logic := '0';
signal start_ro			: std_logic := '0';

signal end_of_line		: std_logic := '0';
signal integrating		: std_logic := '0';

begin

sampling : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1')
		then
			trig_edge 		<= (others => '0');
			triggered		<= '0';

			s_state			<= IDLE;
			s_counter		<= (others => '0');

			rst_cvc			<= '1';
			rst_cds			<= '1';
			sample 			<= '0';
			
			integrating 	<= '0';
			end_of_line		<= '0';
		else
			end_of_line		<= '0';
			go_convert		<= '0';
		
			trig_edge <= trig_edge(0) & TRIGGER_I;
			
			if (enable = '1')
			then
				if (trig_edge = "01")
				then
					triggered <= '1';
				end if;
			else
				triggered <= '0';
			end if;
			
			case (s_state) is
			when IDLE =>
				rst_cvc			<= '1';
				rst_cds			<= '1';
				sample 			<= '0';
			
				integrating 	<= '0';
				
				enable			<= ENABLE_I;
				delay_clks		<= DELAY_CLKS_I;
				integ_clks		<= INT_CLKS_I;	
				
				if (enable = '1' AND trig_edge = "01")
				then
					triggered 	<= '0';
					s_counter	<= (others => '0');
					
					if (integ_clks < min_integ_clks)
					then
						rst_cvc_clks <= std_logic_vector(unsigned(min_integ_clks) - unsigned(integ_clks));
					else
						rst_cvc_clks <= int2vec(clks_500ns - 2, 16);
					end if;
				
					s_state		<= RESET_CVC;
				end if;
	
			when RESET_CVC =>
				if (s_counter = rst_cvc_clks) then
					rst_cvc		<= '0';
					s_counter	<= (others => '0');
					s_state		<= RESET_CDS;
				else
					s_counter	<= inc(s_counter);
				end if;
				
			when RESET_CDS =>
				if (s_counter = rst_cds_clks) then
					rst_cds 	<= '0';
					integrating <= '1';
					s_counter	<= (others => '0');
					s_state		<= INTEGRATE;								-- Start of Integration
				else
					s_counter	<= inc(s_counter);
				end if;
			
			when INTEGRATE =>
				if (s_counter = integ_clks)
				then								
					s_counter	<= (others => '0');
					s_state		<= SAMPLE_PULSE;							-- Integration Clocks finished, send sample pulse
				else
					s_counter	<= inc(s_counter);
				end if;
					
			when SAMPLE_PULSE =>
				sample		<= '1';
				
				if (s_counter = sample_clks) then
					s_counter	<= (others => '0');
					
--					end_of_line	<= '1';
					integrating <= '0';										-- End of Integration
					sample		<= '0';
					go_convert	<= '1';										-- Start conversion
					
					s_state		<= DELAY;											
				else
					s_counter	<= inc(s_counter);
				end if;
				
			when DELAY =>
				if (s_counter = delay_clks)
				then
					s_counter	<= (others => '0');
					
					end_of_line <= '1';
					
					s_state 	<= IDLE;
				else
					s_counter	<= inc(s_counter);
				end if;
					
			end case;
		end if;
	end if;
end process;

conversion : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			c_state		<= IDLE;
			c_counter	<= (others => '0');
			
			start_ad	<= '0';
			go_readout  <= '0';
		else
			go_readout  <= '0';
		
			case (c_state) is
			when IDLE =>
				if (go_convert = '1') then
					c_counter	<= (others => '0');
					c_state 	<= CONV_DELAY;
				end if;
				
			when CONV_DELAY =>
				if (c_counter = delay_ad_clks) then
					c_counter	<= (others => '0');
					start_ad	<= '1';
					c_state		<= START_CONV;
				else
					c_counter	<= inc(c_counter);
				end if;
				
			when START_CONV =>
				if (c_counter = strt_ad_clks) then
					c_counter	<= (others => '0');
					start_ad	<= '0';
					c_state		<= CONVERTING;
				else
					c_counter	<= inc(c_counter);
				end if;
				
			when CONVERTING =>
				if (c_counter = convert_clks) then
					c_counter	<= (others => '0');
					c_state		<= START_READ;
				else
					c_counter	<= inc(c_counter);
				end if;
				
			when START_READ =>
				go_readout 	<= '1';
				c_state		<= IDLE;
			end case;
		end if;
	end if;
end process;

readout : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			r_state		<= IDLE;
			r_counter	<= (others => '0');
			
			start_ro		<= '0';
		else
	
			case (r_state) is
			when IDLE =>
				if (go_readout = '1') then
					r_counter	<= (others => '0');
					r_state 	<= READ_DELAY;
				end if;
				
			when READ_DELAY =>
				if (r_counter = delay_ro_clks) then
					r_counter	<= (others => '0');
					start_ro	<= '1';
					r_state		<= START_READOUT;
				else
					r_counter	<= inc(r_counter);
				end if;
				
			when START_READOUT =>
				if (r_counter = strt_ro_clks) then
					r_counter	<= (others => '0');
					start_ro	<= '0';
					r_state		<= READING;
				else
					r_counter	<= inc(r_counter);
				end if;
				
			when READING =>
				if (r_counter = reading_clks) then
					r_counter	<= (others => '0');
					r_state		<= IDLE;
				else
					r_counter	<= inc(r_counter);
				end if;
				
			end case;
		end if;
	end if;
end process;

output:
	RST_CVC_O			<= rst_cvc 		when enable = '1' else '1';
	RST_CDS_O			<= rst_cds 		when enable = '1' else '1';
	SAMPLE_O			<= sample		when enable = '1' else '0';
	START_ADC_O			<= start_ad		when enable = '1' else '0';
	START_READOUT_O		<= start_ro		when enable = '1' else '0';

	INTEGRATING_O		<= integrating	when enable = '1' else '0';
	END_OF_LINE_O		<= end_of_line	when enable = '1' else '0';

end RTL;
