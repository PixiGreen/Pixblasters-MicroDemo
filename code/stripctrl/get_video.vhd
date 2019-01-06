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
--  v1.0    11.11.2018.  FPGA demo code for learning and experimenting with RGB LEDs. 
-----------------------------------------------------------------------------------------------------------
-- Description:
--
--  Controls controller's reset condition. Checks the polarity of video sync signals, and if necessary,
--  changes it into required positive polarity.
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

entity get_video is
   port (

      grabber_enable        : in  std_logic;
      vs_fedge              : in  std_logic;
	  hdmi_present          : in  std_logic;

      video_rst_n           : out std_logic;
      pol_detected          : out std_logic;
	  sync_pol_change       : out std_logic;

      -- DVI video input
      pix_clk               : in  std_logic;
      pix_hsync             : in  std_logic;
      pix_vsync             : in  std_logic;
      pix_de                : in  std_logic;
      pix_data              : in  std_logic_vector(23 downto 0);
      video_valid           : in  std_logic;

      -- Selected Parallel RGB input

      rgb_clk               : out std_logic;
      rgb_data              : out std_logic_vector(23 downto 0);
      rgb_de                : out std_logic;
      rgb_hs                : out std_logic;
      rgb_vs                : out std_logic
   );
end get_video;

architecture rtl of get_video is

   ----------------------------------------------------------------------------
   -- SIGNALS
   ----------------------------------------------------------------------------

   signal lo                : std_logic := '0';
   signal hi                : std_logic := '1';
   signal sampling_point    : std_logic := '0';
   signal sampling_point_d  : std_logic := '0';
   signal rgb_de_d          : std_logic := '0';
   signal inv_hs            : std_logic := '0'; -- inverts HS to make it positive, if necessary
   signal inv_vs            : std_logic := '0'; -- inverts VS to make it positive, if necessary
   signal inv_hs_d          : std_logic := '0'; -- delayed - inverts HS to make it positive, if necessary
   signal inv_vs_d          : std_logic := '0'; -- delayed - inverts VS to make it positive, if necessary
   signal change_hs         : std_logic := '0'; -- changed the sync polarity - due to the change of the input video source
   signal change_vs         : std_logic := '0'; -- changed the sync polarity - due to the change of the input video source   
   signal pol_detected_i    : std_logic := '0';
   signal video_rst_n_i     : std_logic := '0';
   signal rgb_de_i          : std_logic;
   signal rgb_hs_i          : std_logic;
   signal rgb_vs_i          : std_logic;

   signal rst_pol_detected  : std_logic;
   
begin

   lo <= '0';
   hi <= '1';

   rgb_clk        <= pix_clk;
   rgb_data       <= pix_data;
   rgb_de         <= pix_de;
   rgb_vs         <= rgb_vs_i;
   rgb_hs         <= rgb_hs_i;
   
   pol_detected   <= pol_detected_i;
   video_rst_n    <= video_rst_n_i;
   rgb_de_i       <= pix_de;
   
   reset_proc: process(pix_clk)
   begin
      if rising_edge(pix_clk) then
		 if (video_valid = '0' or rst_pol_detected = '1') then
		    video_rst_n_i <= '0';
         elsif (pol_detected_i = '1' and vs_fedge = '1' and video_valid = '1') then
            video_rst_n_i <= grabber_enable;
         end if;
      end if;
   end process;

   ----------------------------------------------------------------------------------
   --                                                                              --
   --                               Sync signals checkout                          --
   --                                                                              --
   --  1) samples sync's polarity at the beginning of the DE when syncs are not    --
   --     active (guaranteed)                                                      --
   --  3) if any of sync signals is 1, it means that it is active negative and     --
   --     needs to be inverted                                                     --
   --  4) such sync signals are inverted and the logic following afterwards        --
   --     is always working with active high sync signals                          --
   --                                                                              --
   ----------------------------------------------------------------------------------

   -- Detects polarity of the sync signals and inverts them (if necessary) to be   --
   -- active high - as it is requested by the further processing logic.             --

   keep_reset: process(pix_clk)
   begin
      if rising_edge(pix_clk) then
		if (rst_pol_detected = '1' or video_valid = '0') then
			pol_detected_i   <= '0';
		else
            pol_detected_i   <= (sampling_point_d and rgb_de_i) or pol_detected_i;
		end if;
      end if;
   end process keep_reset;

   proba: process(pix_clk)
   begin
		if rising_edge(pix_clk) then
			rst_pol_detected <= pol_detected_i and (change_hs or change_vs);
		end if;
   end process proba;
   
   sync_pol_change  <= rst_pol_detected;
   
   -- Delay process that generates signals required for edge detection
   -- Sampling point definition

   de_sampler: process(pix_clk)
   begin
      if rising_edge(pix_clk) then
		if (video_valid = '0') then
			rgb_de_d         <= '0';
			sampling_point_d <= '0';		
		else 
			rgb_de_d         <= rgb_de_i;
			sampling_point_d <= sampling_point;
		end if; 
      end if;
   end process de_sampler;

   sampling_point <= video_valid and rgb_de_i and (not rgb_de_d);

   -- Checks the polarity of the input sync signals and sets inverter controls
   -- When input sync signals are high during DE, it is necessary to invert them, since
   -- they have inverted polarity (active negative). Grabber memory storage logic expects positive polarity.
   
   hs_checker: process(pix_clk)
   begin
      if rising_edge(pix_clk) then
         if (video_valid = '0' or (pix_hsync = '0' and sampling_point = '1')) then
            inv_hs <= '0';
         elsif (pix_hsync = '1' and sampling_point = '1') then
            inv_hs <= '1';
         end if;
      end if;
   end process hs_checker;

   vs_checker: process(pix_clk)
   begin
      if rising_edge(pix_clk) then
         if (video_valid = '0' or (pix_vsync = '0' and sampling_point = '1')) then
            inv_vs <= '0';
         elsif (pix_vsync = '1' and sampling_point = '1') then
            inv_vs <= '1';
         end if;
      end if;
   end process vs_checker;
   
   -- detects the sync polarity change - assumed the change of the input video signal
   
   dly_changers: process(pix_clk)
   begin
	if rising_edge(pix_clk) then

		inv_hs_d <= inv_hs;
		inv_vs_d <= inv_vs;

	end if;
   end process dly_changers;
 
   change_hs <= inv_hs xor inv_hs_d;
   change_vs <= inv_vs xor inv_vs_d;
 
   -- Inverters activated if input sync signals have negative polarity

   mux_hs_proc: process(inv_hs, pix_hsync)
   begin
      if (inv_hs = '1') then
         rgb_hs_i <= not pix_hsync;
      else
         rgb_hs_i <= pix_hsync;
      end if;
   end process mux_hs_proc;

   mux_vs_proc: process(inv_vs, pix_vsync)
   begin
      if (inv_vs = '1') then
         rgb_vs_i <= not pix_vsync;
      else
         rgb_vs_i <= pix_vsync;
      end if;
   end process mux_vs_proc;

end rtl;



