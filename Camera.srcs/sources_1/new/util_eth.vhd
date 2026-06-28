library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;
use work.util.all;
use work.types.all;

package Util_Eth is

procedure rgmii_tx(
					byte 	: in std_logic_vector(7 downto 0);
					en   	: in std_logic;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				);
				
procedure eth_send(
					dst : in std_logic_vector(47 downto 0);
					src : in std_logic_vector(47 downto 0);
					ethertype : in std_logic_vector(15 downto 0);
					payload : in array8_t;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				);
				
procedure arp_send(
					dstmac : in std_logic_vector(47 downto 0);
					srcmac : in std_logic_vector(47 downto 0);
					dstip  : in std_logic_vector(31 downto 0);
					srcip  : in std_logic_vector(31 downto 0);
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				);

procedure ipv4_send(
					dstmac : in std_logic_vector(47 downto 0);
					srcmac : in std_logic_vector(47 downto 0);
					dstip : in std_logic_vector(31 downto 0);
					srcip : in std_logic_vector(31 downto 0);
					protocol : in std_logic_vector(7 downto 0);
					payload : in array8_t;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				);

procedure udp_send(
					dstmac : in std_logic_vector(47 downto 0);
					srcmac : in std_logic_vector(47 downto 0);
					dstip : in std_logic_vector(31 downto 0);
					srcip : in std_logic_vector(31 downto 0);
					dstport : in std_logic_vector(15 downto 0);
					srcport : in std_logic_vector(15 downto 0);
					payload : in array8_t;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				);				

pure function ipv4_checksum(header : array8_t) return std_logic_vector;
pure function eth_checksum(frame: array8_t; polynomial : std_logic_vector(31 downto 0)) return std_logic_vector;

shared variable ipv4_id : std_logic_vector(15 downto 0) := x"0000";

end Util_Eth;

package body Util_Eth is

procedure rgmii_tx(
					byte 	: in std_logic_vector(7 downto 0);
					en   	: in std_logic;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				)
is
begin
	if data'length = 4 then
		wait until rising_edge(clk);
		dv <= en;
		data <= byte(3 downto 0);
		wait until falling_edge(clk);
		dv <= en;
		data <= byte(7 downto 4);
	elsif data'length = 8 then
		wait until rising_edge(clk);
		dv <= en;
		data <= byte;
	end if;
end procedure;
	
procedure eth_send(
					dst : in std_logic_vector(47 downto 0);
					src : in std_logic_vector(47 downto 0);
					ethertype : in std_logic_vector(15 downto 0);
					payload : in array8_t;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				)
is
	variable i : integer;
	variable pkt : array8_t(0 to max(45, 6+6+2+payload'length-1)) := (others => x"00");
	variable crc : std_logic_vector(31 downto 0);
begin
	-- IPG
	for i in 1 to 12 loop
		rgmii_tx(x"00", '0', clk, dv, data);
	end loop;
	
	-- Preamble
	for i in 1 to 7 loop
		rgmii_tx(x"55", '1', clk, dv, data);
	end loop;
	
	-- SFD
	rgmii_tx(x"D5", '1', clk, dv, data);

	pkt := (dst(47 downto 40), dst(39 downto 32), dst(31 downto 24), dst(23 downto 16), dst(15 downto  8), dst( 7 downto  0),
			src(47 downto 40), src(39 downto 32), src(31 downto 24), src(23 downto 16), src(15 downto  8), src( 7 downto  0),
			ethertype(15 downto 8), ethertype(7 downto 0),
			others => x"00");

	for i in 0 to payload'length-1 loop
		pkt(14+i) := payload(i);
	end loop;		  

	for i in 0 to pkt'length-1 loop
		rgmii_tx(pkt(i), '1', clk, dv, data);
	end loop;
	
	-- FCS
	crc := eth_checksum(pkt, x"EDB88320");
	
	for i in 4 downto 1 loop
		rgmii_tx(crc(i*8-1 downto (i-1)*8), '1', clk, dv, data);
	end loop;
	
	wait until rising_edge(clk);
	dv <= '0';
	data <= (others => '0');
end procedure;

procedure arp_send(
					dstmac : in std_logic_vector(47 downto 0);
					srcmac : in std_logic_vector(47 downto 0);
					dstip  : in std_logic_vector(31 downto 0);
					srcip  : in std_logic_vector(31 downto 0);
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				)
is
	variable i : integer;
	variable payload : array8_t(0 to 27);
begin
	payload := (
		x"00", x"01", x"08", x"00",
		x"06", x"04", x"00", x"01",
		srcmac(47 downto 40), srcmac(39 downto 32), srcmac(31 downto 24), srcmac(23 downto 16),
		srcmac(15 downto  8), srcmac( 7 downto  0), srcip(31 downto 24), srcip(23 downto 16),
		srcip(15 downto 8), srcip(7 downto 0), dstmac(47 downto 40), dstmac(39 downto 32),
		dstmac(31 downto 24), dstmac(23 downto 16), dstmac(15 downto  8), dstmac( 7 downto  0),
		dstip(31 downto 24), dstip(23 downto 16), dstip(15 downto 8), dstip(7 downto 0)
	);
		
	eth_send(dstmac, srcmac, x"0806", payload, clk, dv, data);
end;

procedure ipv4_send(
					dstmac : in std_logic_vector(47 downto 0);
					srcmac : in std_logic_vector(47 downto 0);
					dstip : in std_logic_vector(31 downto 0);
					srcip : in std_logic_vector(31 downto 0);
					protocol : in std_logic_vector(7 downto 0);
					payload : in array8_t;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				)
is
	variable i : integer;
	variable len : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(20 + payload'length, 16));
	variable checksum : std_logic_vector(15 downto 0) := x"0000";
	
	variable pkt : array8_t(0 to 20+payload'length-1);
begin
	pkt := (
		x"45", x"00", len(15 downto  8), len(7 downto  0),
		ipv4_id(15 downto 8), ipv4_id(7 downto 0), x"40", x"00",  
		x"40", protocol, checksum(15 downto 8), checksum(7 downto 0),
		srcip(31 downto 24), srcip(23 downto 16), srcip(15 downto 8), srcip(7 downto 0),
		dstip(31 downto 24), dstip(23 downto 16), dstip(15 downto 8), dstip(7 downto 0),
		others => x"00"
	);
	
	ipv4_id := ipv4_id + '1';
	
	checksum := ipv4_checksum(pkt(0 to 19));
	pkt(10) := checksum(15 downto 8);
	pkt(11) := checksum( 7 downto 0);	
	
	for i in 0 to payload'length-1 loop
		pkt(20+i) := payload(i);
	end loop;
	
	eth_send(dstmac, srcmac, x"0800", pkt, clk, dv, data);
end;

procedure udp_send(
					dstmac : in std_logic_vector(47 downto 0);
					srcmac : in std_logic_vector(47 downto 0);
					dstip : in std_logic_vector(31 downto 0);
					srcip : in std_logic_vector(31 downto 0);
					dstport : in std_logic_vector(15 downto 0);
					srcport : in std_logic_vector(15 downto 0);
					payload : in array8_t;
					signal clk : in std_logic;
					signal dv : out std_logic;
					signal data : out std_logic_vector
				)
is
	variable i : integer;
	variable len : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(8 + payload'length, 16));
	variable checksum : std_logic_vector(15 downto 0) := x"0000";
	
	variable pseudopkt : array8_t(0 to integer(ceil(real(20 + payload'length-1) / 2.0) * 2.0));	-- Round up to multiple of 2 bytes
	
	variable pkt : array8_t(0 to 8 + payload'length-1);
begin
	pseudopkt := (
		srcip(31 downto 24), srcip(23 downto 16), srcip(15 downto 8), srcip(7 downto 0),
		dstip(31 downto 24), dstip(23 downto 16), dstip(15 downto 8), dstip(7 downto 0),
		x"00", x"11", len(15 downto  8), len(7 downto  0),
		srcport(15 downto 8), srcport(7 downto 0), dstport(15 downto 8), dstport(7 downto 0),
		len(15 downto  8), len(7 downto  0), checksum(15 downto 8), checksum(7 downto 0),
		others => x"00"
	);

	for i in 0 to payload'length-1 loop
		pseudopkt(20+i) := payload(i);
	end loop;

	checksum := ipv4_checksum(pseudopkt);

	pkt := (
		srcport(15 downto 8), srcport(7 downto 0), dstport(15 downto 8), dstport(7 downto 0),
		len(15 downto  8), len(7 downto  0), checksum(15 downto 8), checksum(7 downto 0),
		others => x"00"
	);
	
	for i in 0 to payload'length-1 loop
		pkt(8+i) := payload(i);
	end loop;
	
	ipv4_send(dstmac, srcmac, dstip, srcip, x"11", pkt, clk, dv, data);
end;

pure function ipv4_checksum(header : array8_t) return std_logic_vector
is
	variable word : std_logic_vector(15 downto 0);
	variable checksum : std_logic_vector(31 downto 0) := (others => '0');
begin
	for i in 0 to header'length/2-1 loop
		word := header(i*2+0) & header(i*2+1);
		checksum := checksum + word;
	end loop;
	
	while checksum(31 downto 16) /= x"0000" loop
		checksum := (checksum and x"0000FFFF") + checksum(31 downto 16);
	end loop;

	return not checksum(15 downto 0);
end;

pure function eth_checksum(frame: array8_t; polynomial : std_logic_vector(31 downto 0)) return std_logic_vector
is
	variable b : std_logic;
	variable byte : std_logic_vector(7 downto 0);
	variable checksum : std_logic_vector(31 downto 0) := (others => '1');
begin
	
	for i in 0 to frame'length-1 loop
		byte := frame(i);
		
		for j in 0 to 7 loop
			b := byte(j) xor checksum(0);
			checksum := '0' & checksum(31 downto 1);	-- Shift Right
			
			if b = '1' then
				checksum := checksum xor polynomial;
			end if;
		end loop;
	end loop;	
	
	return not byte_reverse(checksum);
end;

end Util_Eth;