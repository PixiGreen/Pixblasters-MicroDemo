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
-- Description:
--
-- The LEDEX block reads the stored lines of pixels and serializes them. The serialized data
-- is further coded by the WS2812 encoder block.  The WS2812 block supports the required bit coding (see
-- datasheet). The WS2812 block contains programmable LUT tables to support fine tuning of the coded bit
-- values for other WorldSemi (mnfg.) LED chip drivers: WS2811 and WS2812B. They use the same coding,
-- but the bit timings are different.
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

entity ledex is
	   generic (
	      LINE_LENGTH : integer := 512  -- defines the length of the display line in pixels - max 512
            );
   port (
      strip_clk             : in  std_logic;
      rgb_clk               : in  std_logic; -- for internal synchronizations on the input video clock
      -- Control Inputs

      video_rst_n            : in  std_logic;
      rgb_vs                 : in  std_logic;
      vs_fedge               : in  std_logic;
	  
      -- Control Outputs

      out_ready              : out std_logic;
      fetch_address          : out std_logic_vector(8 downto 0) := (others => '0'); -- counter fixed to 512 pixels

      -- Data inputs

      out_pixels             : in  std_logic_vector((16 * 24) - 1 downto 0);

      -- Coded LED Outputs
      led_out                : out std_logic_vector(15 downto 0)

   );
end ledex;

architecture rtl of ledex is

   -----------------------------------------------------------------------------------------------------------
   -- TYPE DECLARATIONS
   -----------------------------------------------------------------------------------------------------------

   type STRIP_DATA is array (15 downto 0) of std_logic_vector(23 downto 0);

   -----------------------------------------------------------------------------------------------------------
   -- COMPONENTS
   -----------------------------------------------------------------------------------------------------------

   component ws2812 is
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
   end component ws2812;

   ----------------------------------------------------------------------------
   -- SIGNALS
   ----------------------------------------------------------------------------

   -- cropping values change during the blanking interval; synchronized on the vertical refresh sync

   signal hor_res_hold    : std_logic_vector(9 downto 0) := (others => '0');
   signal prescal_hold    : std_logic_vector(9 downto 0) := (others => '0');

   signal strip_pixel_even  : STRIP_DATA := (others => (others => '0'));

   signal adresa_b        : std_logic_vector(8 downto 0) := (others => '0'); -- counter fixed to 512 pixels
   -- Pixel outputs preparations

   signal new_pixel       : std_logic;
   signal new_pixel_d     : std_logic;
   signal new_pixel_2d    : std_logic;

   signal pixel_len_cnt   : std_logic_vector (4 downto 0) := (others => '1');
   signal new_strip_cycle : std_logic := '0'; -- start new shift cycle at led

   signal set_shift_flag  : std_logic := '0'; -- condition that sets the flag active during active pixel shifting
                                              -- downstream the strip
   signal shift_flag      : std_logic := '0'; -- flag active during active pixels shift
   signal end_shift       : std_logic := '0'; -- end of led values shifting; now limited by generic

   signal out_pixel       : std_logic_vector(15 downto 0);

   -- Fake clocking

   signal tick            : std_logic := '0';	
   signal tick_tc         : std_logic := '0';	
   signal tick_cnt        : std_logic_vector(9 downto 0) := (others => '1');
   signal bit_slot        : std_logic := '0'; -- period of one serial bit at the strip

   signal oversample_cnt  : std_logic_vector(4 downto 0) := (others => '1');

   signal rgb_vs_d        : std_logic;
   signal rgb_vs_2d       : std_logic;
   signal rgb_vs_3d       : std_logic;
   signal rgb_vs_4d       : std_logic;

   signal line_change     : std_logic;
   signal bit_slot_d      : std_logic;
   
   signal bit_slot_pre    : std_logic;
   signal new_pixel_pre   : std_logic;
 
   signal end_pixel          : std_logic_vector(hor_res_hold'range);
   signal set_start_address  : std_logic_vector(8 downto 0) :=(others => '0');
   signal set_target_address : std_logic_vector(8 downto 0) :=(others => '0'); 
   signal last_shift         : std_logic := '0'; -- active while shifting the last pixel in the row  
   signal out_ready_i     : std_logic := '0'; -- blocks video input and causes frame slips
   signal end_vs          : std_logic := '0'; -- strip-clk synchronized end of the vertical sync
   signal rst_adresa_b    : std_logic := '0';
   signal rgb_vs_gamma    : std_logic := '0';
 
begin

   hor_res_hold <= conv_std_logic_vector(LINE_LENGTH, 10);
   prescal_hold <= "0000000000";

   ------------------------------------------------------
   --                                                  --
   --    Bit Time Slot Clocking                        --
   --                                                  --
   ------------------------------------------------------

   -- Assumption - the clock input is something usable for integer division that results
   -- by the strip clock aligned with the LED STRIP's requirements

   -- Let the clock work before the led display enable
   -- SW set ups clock, than other display parameters

   ticker: process(strip_clk)
   begin
		if rising_edge(strip_clk) then
	       if (tick = '1') then
				tick_cnt <= prescal_hold;
		   else
				tick_cnt <= tick_cnt - 1;
		   end if;
		end if;
   end process ticker;
   
   tick <= '1' when (tick_cnt = 0) else '0';
   
   divider: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
         if (bit_slot_pre = '1') then 
            oversample_cnt <= "11111";
         elsif (tick = '1') then
            oversample_cnt <= oversample_cnt - 1;
         end if;
      end if;
   end process divider;

   bit_slot_pre <= '1' when (oversample_cnt = 0 and tick = '1') else '0';

   sinikro: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
		bit_slot  <= bit_slot_pre;
		new_pixel <= new_pixel_pre;
      end if;
   end process sinikro;
   
   ------------------------------------------------------
   --                                                  --
   --    Pixel length definition                       --
   --                                                  --
   ------------------------------------------------------

   -- This clocking also enabled prior to the display enable

   pixel_measure: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
         if (new_pixel = '1') then
            pixel_len_cnt <= (others => '0');
         elsif (bit_slot = '1') then
            pixel_len_cnt <= pixel_len_cnt + 1;
         end if;
      end if;
   end process pixel_measure;

   new_pixel_pre <= '1' when (bit_slot = '1' and pixel_len_cnt = 23) else '0';

   ------------------------------------------------------
   --                                                  --
   --    Starting up new shifting time                 --
   --                                                  --
   ------------------------------------------------------

   gamma_delay: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
         rgb_vs_gamma    <= rgb_vs;  
      end if;                        
   end process gamma_delay;
   
   vsync_edger: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
         rgb_vs_d    <= rgb_vs_gamma;
         rgb_vs_2d   <= rgb_vs_d;
         rgb_vs_3d   <= rgb_vs_2d;
         rgb_vs_4d   <= rgb_vs_3d;
      end if;
   end process vsync_edger;

   end_vs <= not rgb_vs_3d and rgb_vs_4d;

   -- Due to different clocking domains this is not-fixed in the time
   -- it waits on the vsync, and sets up the shift_flag. The setup 
   -- flag switches off the set signal
   -- the flag is not set while the output still shifts the previous row (slow LEDs)
   
   set_zastavica: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
		 if (video_rst_n = '0' or rgb_vs_gamma = '1' or shift_flag = '1') then --gg
            set_shift_flag <= '0';
         else
            set_shift_flag <= (set_shift_flag or end_vs); --rgb_vs_3d and rgb_vs_4d));
         end if;
      end if;
   end process set_zastavica;

   shift_traka: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
         if (video_rst_n = '0' or end_shift = '1' or (rgb_vs_gamma = '1' and out_ready_i = '1')) then --gg
            shift_flag <= '0';
         elsif (new_pixel = '1') then
            shift_flag <= shift_flag or set_shift_flag;
	     end if;
      end if;
   end process shift_traka;
   
   -- Marks shifting of the last pixel in the row and prevents the controller to stop too early
   
   endermon: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
	    if (video_rst_n = '0' or end_shift = '1') then
		    last_shift <= '0';
		elsif (shift_flag = '1' and adresa_b = set_target_address) then
			last_shift <= new_pixel or last_shift;
		end if;
	  end if;
   end process endermon;
   
   end_shift <= '1' when (last_shift = '1' and new_pixel = '1') else '0';
   
   ------------------------------------------------------
   --                                                  --
   --    Address for fetching stored pixels in         --
   --    line BRAM-implemented dual-FIFO               --
   --                                                  --
   ------------------------------------------------------

   tick_address: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
		new_pixel_d  <= new_pixel;
		new_pixel_2d <= new_pixel_d;
		bit_slot_d   <= bit_slot;
      end if;
   end process tick_address;
      
   end_pixel <= hor_res_hold - 1;
     
   set_start_address  <= (others => '0');
   set_target_address <= end_pixel(set_target_address'range);
 
   rst_adresa_b <= not video_rst_n or (out_ready_i and (rgb_vs_gamma or set_shift_flag));
 
   adr_a_port: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
		 if (video_rst_n = '0' or rst_adresa_b = '1') then 
            adresa_b <= set_start_address;
         elsif (shift_flag = '1' and new_pixel_2d = '1') then
            adresa_b <= adresa_b + 1;
         end if;
      end if;
   end process adr_a_port;

   line_change   <= new_pixel_2d or new_pixel_d or new_pixel;
   fetch_address <= adresa_b;

   ------------------------------------------------------------
   -- Output slower than the input causes frame drops at     --
   -- the input. out_ready_i blocks new writes and prevents  --
   -- premature stop of the output shifting                  --
   ------------------------------------------------------------
   
   set_out_ready_i: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
		 if (video_rst_n = '0') then
			out_ready_i <= '1';
		 else
            out_ready_i <= (end_shift or out_ready_i) and not set_shift_flag; 
		 end if;
      end if;
   end process set_out_ready_i;
   
   out_ready <= out_ready_i;

   ------------------------------------------------------------
   -- DoubleBuffer Field - take pixel from the BRAM and      --
   -- prepare it for parallel shifting through STRIPS number --
   -- of LED strip driving channels                          --
   ------------------------------------------------------------

   -- the MSB goes out as the FIRST bit!

   zadrzivaci: for i in 0 to 15 generate

   drzi_pixel_even: process(strip_clk)
   begin
      if rising_edge(strip_clk) then
		 if (video_rst_n = '0' or rgb_vs_gamma = '1') then
            strip_pixel_even(i) <= (others => '0');
         elsif (new_pixel = '1') then
            strip_pixel_even(i) <= out_pixels(((i * 24) + 23) downto ((i * 24) + 16)) &
                              out_pixels(((i * 24) + 15) downto ((i * 24) + 8)) & 
							  out_pixels(((i * 24) + 7 ) downto  (i * 24));
         elsif (shift_flag = '1' and bit_slot_d = '1') then
            strip_pixel_even(i) <= strip_pixel_even(i)(22 downto 0) & strip_pixel_even(i)(23);
         end if;
      end if;
   end process drzi_pixel_even;

   out_pixel(i)       <= strip_pixel_even(i)(23); 

   end generate zadrzivaci;

   ------------------------------------------------------------
   -- Field of shift registers                               --
   ------------------------------------------------------------

   ws2812_led: ws2812
      port map(
         -- General
         clk           => strip_clk,
		 bit_slice     => tick,
         rst_n         => video_rst_n,

         -- Inputs
         enable_out    => shift_flag,
 
         bit_slot      => bit_slot_d,
         serial_in     => out_pixel,

         -- Encoded Outputs

         led_out       => led_out
   );

end rtl;



