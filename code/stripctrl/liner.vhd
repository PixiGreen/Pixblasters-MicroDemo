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
--  v1.00    14.11.2018     Implemented 24-bit (RGB888) pixel colour
-----------------------------------------------------------------------------------------------------------
-- Description:
--
-- The cropped input video is stored in line buffers. There are two sets of line buffers
-- that work in an interleaved mode, i.e. while one set of buffers is written to, the other
-- one is read by the LEDEX module that refreshes the LED display. This module also contains
-- the mux logic for changing input pixel format, i.e. RGB to GRB, and so on. 
--
-----------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--                               LIBRARIES
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library std;
use std.textio.all;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
--                                ENTITY
-------------------------------------------------------------------------------

entity liner is
   port (
      -- Sync inputs
      video_rst_n            : in  std_logic;
      rgb_clk                : in  std_logic;

      vs_fedge               : in  std_logic;
      hs_fedge               : in  std_logic;

      video_data             : in  std_logic_vector(23 downto 0);
      pre_store_data         : in  std_logic;
      pre_store_end          : in  std_logic;

      -- Control Pixel for shifting
	  out_ready              : in  std_logic;
      strip_clk              : in  std_logic;
      fetch_address          : in  std_logic_vector(8 downto 0) := (others => '0');-- counter fixed to 512 pixels

      -- Outputs
      ramed_pixel            : out std_logic_vector((16 * 24) - 1 downto 0) := (others => '0')
   );
end liner;

architecture rtl of liner is

   ----------------------------------------------------------------------------
   -- SIGNALS
   ----------------------------------------------------------------------------

   -- hard-wired

   signal lo             : std_logic := '0';
   signal hi             : std_logic := '1';

   -- A port (video in) of the FIFO - control

   signal adresa_a       : std_logic_vector(8 downto 0) := (others => '0'); -- full BRAM port A address 
   signal switch_fifo    : std_logic := '0'; -- switches storage on the vertical sync
   signal input_rgb      : std_logic_vector(23 downto 0) := (others => '0');

   signal write_first    : std_logic; -- enable writing into the first line buffer
   signal write_second   : std_logic; -- enable writing into the second line buffer

   signal read_first     : std_logic := '0'; -- enable reading from the first line buffer
   signal read_second    : std_logic := '0'; -- enable reading from the second line buffer
   signal bram_select    : std_logic_vector(15 downto 0) := (others => '0');

   signal ramed_pixel_l  : std_logic_vector((16 * 24) - 1 downto 0) := (others => '0');
   signal ramed_pixel_h  : std_logic_vector((16 * 24) - 1 downto 0) := (others => '0');
   signal ramed_pixel_i  : std_logic_vector((16 * 24) - 1 downto 0) := (others => '0');

   signal h_byte         : std_logic_vector(7 downto 0) := (others => '0');
   signal m_byte         : std_logic_vector(7 downto 0) := (others => '0');
   signal l_byte         : std_logic_vector(7 downto 0) := (others => '0');
   
   signal store_data     : std_logic := '0';
   signal store_end      : std_logic := '0';
   signal store_end_d    : std_logic;

   signal data_input     : std_logic_vector(31 downto 0) := (others => '0');
   signal data_output_l  : std_logic_vector((16 * 32) - 1 downto 0) := (others => '0');
   signal data_output_h  : std_logic_vector((16 * 32) - 1 downto 0) := (others => '0');

begin

   lo <= '0';
   hi <= '1';
   
   ----------------------------------------------------
   --                                                --
   -- Some strips require RGB data re-ordering       --
   -- These multiplexers enable re-ordering prior to --
   -- storage into line FIFO buffers                 --
   --                                                --
   ----------------------------------------------------

   -- Example WS2812 requires GRB pixel instead of the RGB pixel
   -- Example WS2811 requires RGB pixel

   h_byte <= video_data(15 downto 8);   -- G
   m_byte <= video_data(23 downto 16);  -- R
   l_byte <= video_data(7 downto 0);    -- B
	
   process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         input_rgb   <= h_byte(7 downto 0) & m_byte(7 downto 0) & l_byte(7 downto 0);
		 store_end   <= pre_store_end;
		 store_data  <= pre_store_data;
		 store_end_d <= store_end;
      end if;
   end process;

   process(input_rgb)
   begin
	   data_input              <= (others => '0');
	   data_input(23 downto 0) <= input_rgb;
   end process;
   
   ------------------------------------------------
   -- Address port A of the video input FIFO     --
   ------------------------------------------------

   -- switching between FIFO groups on the vertical sync

   buf_switcher: process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (video_rst_n = '0') then
            switch_fifo <= '0';
         elsif (vs_fedge = '1' and out_ready = '1') then 
            switch_fifo <= not switch_fifo;
         end if;
      end if;
   end process buf_switcher;

   write_first      <= store_data and not switch_fifo;
   write_second     <= store_data and switch_fifo;
      
   -- Reading is blocked on buffers that are currently written to

   read_first   <= switch_fifo;
   read_second  <= not switch_fifo;
   
   -- Port A addressing
   adr_a_port: process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
		if (video_rst_n = '0' or vs_fedge = '1' or store_end = '1') then
			adresa_a <= (others => '0');
		elsif (store_data = '1') then
			adresa_a <= adresa_a + 1;
		end if;
	  end if;
   end process adr_a_port;
 
   line_shifter: process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (video_rst_n = '0' or vs_fedge = '1') then
            bram_select(0)                         <= '1';
            bram_select(bram_select'left downto 1) <= (others => '0');
		 elsif (store_end_d = '1') then
            bram_select <= bram_select(14 downto 0) & bram_select(15);
         end if;
      end if;
   end process line_shifter;
   
   gen_line_fifos: for i in 0 to 15 generate

      BRAM_L0: RAMB16_S36_S36         -- first set of lines 
         port map(
            clka     => rgb_clk,

            doa      => open, 
            dopa     => open, 

            addra    => adresa_a, 
            dia      => data_input,
            dipa     => (others => '0'),

            ena      => bram_select(i),
            ssra     => lo,
            wea      => write_first,
            ---------
            clkb     => strip_clk,

            dob      => data_output_l(((i * 32) + 31) downto ((i * 32) + 0)), 
            dopb     => open, 

            addrb    => fetch_address,
            dib      => (others => '0'),
            dipb     => (others => '0'),

            enb      => read_first,
            ssrb     => lo,
            web      => lo
            );
			
	  ramed_pixel_l(((i * 24) + 23) downto ((i * 24) + 0)) <= data_output_l(((i * 32) + 23) downto ((i * 32) + 0));	

      BRAM_L1: RAMB16_S36_S36         -- second set of lines
         port map(
            clka     => rgb_clk,

            doa      => open,
            dopa     => open,

            addra    => adresa_a, 
            dia      => data_input,
            dipa     => (others => '0'),

            ena      => bram_select(i),
            ssra     => lo,
            wea      => write_second,
            ---------
            clkb     => strip_clk,

            dob      => data_output_h(((i * 32) + 31) downto ((i * 32) + 0)), 
            dopb     => open,

            addrb    => fetch_address,
            dib      => (others => '0'),
            dipb     => (others => '0'),

            enb      => read_second,
            ssrb     => lo,
            web      => lo
            );
			
	  ramed_pixel_h (((i * 24) + 23) downto ((i * 24) + 0)) <= data_output_h(((i * 32) + 23) downto ((i * 32) + 0));

   end generate gen_line_fifos;

   -- Selects the right FIFOs outputs
   -- Reading pixel data from BRAMs group that is not currently written to

   out_muxer: process(switch_fifo, ramed_pixel_l, ramed_pixel_h)
   begin
      if (switch_fifo = '0') then
         ramed_pixel_i <= ramed_pixel_h;
      else
         ramed_pixel_i <= ramed_pixel_l;
      end if;
   end process out_muxer;
     
   -- Muxed output pixels from line FIFOs
   ramed_pixel <= ramed_pixel_i;

end rtl;
