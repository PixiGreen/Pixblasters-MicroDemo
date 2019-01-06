-----------------------------------------------------------------------------------------------------------
--
-- Copyright 2018 - Pixblasters.com
-- All rights reserved - Sva prava pridržana  
--
-----------------------------------------------------------------------------------------------------------
--
-- This file is part of the Pixblasters_Light Demo.

-- Pixblasters_Light Demo is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- Pixblasters_Light Demo is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with Pixblasters_Light Demo.  If not, see <https://www.gnu.org/licenses/>.
--
-----------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity romic is
	port(clk  :in  std_logic;
		 en   :in  std_logic;
         addr :in  std_logic_vector(7 downto 0);
         data :out std_logic_vector(7 downto 0)
	);
end romic;

architecture syn of romic is

type rom_type is array(0 to 255) of std_logic_vector(7 downto 0);
	signal ROM: rom_type := (
		X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
		X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
		X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
		X"00", X"00", X"00", X"00", X"01", X"01", X"01", X"01",
		X"01", X"01", X"01", X"01", X"01", X"01", X"01", X"01",
		X"01", X"02", X"02", X"02", X"02", X"02", X"02", X"02",
		X"02", X"03", X"03", X"03", X"03", X"03", X"03", X"03",
		X"04", X"04", X"04", X"04", X"04", X"05", X"05", X"05",
		X"05", X"06", X"06", X"06", X"06", X"07", X"07", X"07",
		X"07", X"08", X"08", X"08", X"09", X"09", X"09", X"0A",
		X"0A", X"0A", X"0B", X"0B", X"0B", X"0C", X"0C", X"0D",
		X"0D", X"0D", X"0E", X"0E", X"0F", X"0F", X"10", X"10",
		X"11", X"11", X"12", X"12", X"13", X"13", X"14", X"14",
		X"15", X"15", X"16", X"16", X"17", X"18", X"18", X"19",
		X"19", X"1A", X"1B", X"1B", X"1C", X"1D", X"1D", X"1E",
		X"1F", X"20", X"20", X"21", X"22", X"23", X"23", X"24",
		X"25", X"26", X"27", X"27", X"28", X"29", X"2A", X"2B",
		X"2C", X"2D", X"2E", X"2F", X"30", X"31", X"32", X"32",
		X"33", X"34", X"36", X"37", X"38", X"39", X"3A", X"3B",
		X"3C", X"3D", X"3E", X"3F", X"40", X"42", X"43", X"44",
		X"45", X"46", X"48", X"49", X"4A", X"4B", X"4D", X"4E",
		X"4F", X"51", X"52", X"53", X"55", X"56", X"57", X"59",
		X"5A", X"5C", X"5D", X"5F", X"60", X"62", X"63", X"65",
		X"66", X"68", X"69", X"6B", X"6D", X"6E", X"70", X"72",
		X"73", X"75", X"77", X"78", X"7A", X"7C", X"7E", X"7F",
		X"81", X"83", X"85", X"87", X"89", X"8A", X"8C", X"8E",
		X"90", X"92", X"94", X"96", X"98", X"9A", X"9C", X"9E",
		X"A0", X"A2", X"A4", X"A7", X"A9", X"AB", X"AD", X"AF",
		X"B1", X"B4", X"B6", X"B8", X"BA", X"BD", X"BF", X"C1",
		X"C4", X"C6", X"C8", X"CB", X"CD", X"D0", X"D2", X"D5",
		X"D7", X"DA", X"DC", X"DF", X"E1", X"E4", X"E7", X"E9",
		X"EC", X"EF", X"F1", X"F4", X"F7", X"F9", X"FC", X"FF"
	);

	attribute ram_style: string;
    attribute ram_style of ROM: signal is "distributed";

begin
	process(clk)
		begin
			if rising_edge(clk) then
			    if (en = '1') then
					data <= ROM(conv_integer(addr));
				end if;
			end if;
	end process;
end syn;