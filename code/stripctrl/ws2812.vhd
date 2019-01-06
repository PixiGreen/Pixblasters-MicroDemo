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
--  Version   Date          Description
--
--  v1.00    14.11.2018     Implemented WS2812 interface
-----------------------------------------------------------------------------------------------------------
-- DESCRIPTION:
--
-- WS2812 compatible encoder of the LED pixel data serialized for the LED strip
--
-----------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

   entity ws2812 is
      port(
         -- General
         clk           : in  std_logic;
		 bit_slice     : in  std_logic;
         rst_n         : in  std_logic; -- General Synchronous reset

         -- Inputs
         enable_out    : in std_logic;
         bit_slot      : in std_logic;
         serial_in     : in std_logic_vector(15 downto 0);

         -- Encoded outputs
         led_out       : out std_logic_vector(15 downto 0)
   );
   end entity ws2812;

-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------

architecture rtl of ws2812 is

-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------

   signal adresar          : std_logic_vector(4 downto 0) := (others => '0');
   signal zero             : std_logic;
   signal uno              : std_logic;
   signal led_out_i        : std_logic_vector(15 downto 0) := (others => '0');

   signal lo               : std_logic;
   signal hi               : std_logic;

begin

   lo    <= '0';
   hi    <= '1';

   adresno_brojilo: process(clk)
   begin
      if rising_edge(clk) then
         if (rst_n = '0' or bit_slot = '1') then
            adresar <= (others => '0');
         elsif (bit_slice = '1') then
            adresar <= adresar + 1;
         end if;
      end if;
   end process adresno_brojilo;
   
   zero_code : ROM32X1
      generic map (
		 INIT      => X"0000003F") 
      port map (
         O         => zero,
         A0        => adresar(0),
         A1        => adresar(1),
         A2        => adresar(2),
         A3        => adresar(3),
         A4        => adresar(4)
    );

   uno_code : ROM32X1
      generic map (

		 INIT      => X"0000ffff") 
      port map (
         O         => uno,
         A0        => adresar(0),
         A1        => adresar(1),
         A2        => adresar(2),
         A3        => adresar(3),
         A4        => adresar(4)
    );

   ------------------------------------------------------------
   -- Encoders field                                         --
   ------------------------------------------------------------

   koderi:  for i in 0 to 15 generate

      mux_kodes: process(serial_in, zero, uno)
      begin
         if (serial_in(i) = '0') then
            led_out_i(i) <= zero;
         else
            led_out_i(i) <= uno;
         end if;
      end process mux_kodes;

      out_ffs: process(clk)
      begin
         if rising_edge(clk) then
            if (rst_n = '0' or enable_out = '0') then
               led_out(i) <= '0';
            elsif (enable_out = '1') then
               led_out(i) <= led_out_i(i);
            end if;
         end if;
      end process out_ffs;

   end generate koderi;

end architecture rtl;
