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
--  v1.0    11.11.2018.   Adapted for the micro-demo - crops the video input of 512x16 pixels and selects 
--                        that cropped window for the LED display
-----------------------------------------------------------------------------------------------------------
-- Description:
--
--  The cropper code takes a part of the input video frame in a selected resolution, i.e. 1280x720, and
--  stores it for internal processing and video display on the attached LED display. 
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

entity cropper is
   generic (
      LINE_LENGTH : integer := 512;  -- defines the length of the display line in pixels - max 512
      TOP_LEFT_X  : integer := 0;  -- defines the x coordinate of the LED display's top left pixel
	  TOP_LEFT_Y  : integer := 0   -- defines the y coordinate of the LED display's top left pixel
      );
   port (
      -- Video input
      video_rst_n            : in  std_logic;
      pol_detected           : in  std_logic;

      rgb_clk                : in  std_logic;
      rgb_data               : in  std_logic_vector(23 downto 0);
      rgb_de                 : in  std_logic;
      rgb_hs                 : in  std_logic;
      rgb_vs                 : in  std_logic;

      -- Cropped video data
      vs_fedge_out           : out std_logic;
      hs_fedge_out           : out std_logic;
      video_data             : out std_logic_vector(23 downto 0) := (others => '0');
      store_data             : out std_logic := '0';
      store_end              : out std_logic := '0'
   );
end cropper;

architecture rtl of cropper is

   -----------------------------------------------------------------------------------------------------------
   -- COMPONENTS
   -----------------------------------------------------------------------------------------------------------

   -- LUT based ROM memory for GAMMA correction table. The gamma correction improves the colors quality.
   
   component romic is
		port(clk  :in  std_logic;
			 en   :in  std_logic;
			 addr :in  std_logic_vector(7 downto 0);
			 data :out std_logic_vector(7 downto 0)
		);
	end component romic;
	
   ----------------------------------------------------------------------------
   -- SIGNALS
   ----------------------------------------------------------------------------

   -- hard-wired

   signal lo             : std_logic := '0';
   signal hi             : std_logic := '1';

   signal rgb_hs_d       : std_logic := '0';
   signal rgb_vs_d       : std_logic := '0';

   signal de_fedge       : std_logic;
   signal hs_fedge       : std_logic; -- falling edge of HSYNC
   signal vs_fedge       : std_logic; -- falling edge of the VSYNC, delayed 1 clk
   signal vs_fedge_out_i : std_logic; -- falling edge of VSYNC
   signal vs_redge       : std_logic; -- rising edge of VSYNC
   signal video_de       : std_logic;

   signal hor_window     : std_logic := '0'; -- flag defines the cropped horizontal line
   signal ver_window     : std_logic := '0'; -- flag defines the cropped vertical line
   signal hor_block      : std_logic := '0'; -- disables the flag activation within the same line
   signal ver_block      : std_logic := '0'; -- disables the repeated ver_window setup within the same frame
   signal store_data_i   : std_logic := '0'; -- store video data in FIFO while active
   signal store_data_d   : std_logic;        -- delayed store_data
   signal prestore       : std_logic;

   -- cropping values change during the blanking interval; synchronized on the vertical refresh sync

   signal x_count        : std_logic_vector(9 downto 0) := (others => '0');
   signal y_count        : std_logic_vector(9 downto 0) := (others => '0');

   signal pali_x         : std_logic := '0';
   signal gasi_x         : std_logic := '0';
   signal x_skip         : std_logic_vector(9 downto 0) := (others => '0');
 
   signal pali_y         : std_logic := '0';
   signal gasi_y         : std_logic := '0';
   signal y_skip         : std_logic_vector(9 downto 0) := (others => '0');

   signal rgb_vs_g       : std_logic := '0';
   signal rgb_hs_g       : std_logic := '0';
   signal rgb_de_g       : std_logic := '0';
   signal rgb_de_g_d     : std_logic := '0';

   signal red_gamma      : std_logic_vector(7 downto 0) := (others => '0');
   signal green_gamma    : std_logic_vector(7 downto 0) := (others => '0');
   signal blue_gamma     : std_logic_vector(7 downto 0) := (others => '0');

   signal crop_x_reg     : std_logic_vector(9 downto 0); -- values (0 - n)
   signal crop_y_reg     : std_logic_vector(9 downto 0); -- values (0 - n)
   signal store_x_reg    : std_logic_vector(9 downto 0); -- values n-1; ie. 9 for 10 pix
   signal store_y_reg    : std_logic_vector(9 downto 0) := "0000001111"; -- values n-1
   
begin

   lo <= '0';
   hi <= '1';

   -- Added GAMMA LUT ROMs 
   -- Currently used Gamma tables are equal for all colors. It can be easily changed
   -- within the romic.vhd code.
   
   red: romic
	port map(
	     clk   => rgb_clk,
		 en    => '1',
		 addr  => rgb_data(23 downto 16),
		 data  => red_gamma
   );
   
   green: romic
	port map(
	     clk   => rgb_clk,
		 en    => '1',
		 addr  => rgb_data(15 downto 8),
		 data  => green_gamma
   );

   blue: romic
	port map(
	     clk   => rgb_clk,
		 en    => '1',
		 addr  => rgb_data(7 downto 0),
		 data  => blue_gamma
   ); 

   df: process(rgb_clk)  -- rgb_clk is the video clock!
   begin
      if rising_edge(rgb_clk) then
         if (pol_detected = '0') then		 
		    rgb_hs_g     <= '0'; -- gamma delay compensation
			rgb_vs_g     <= '0'; -- gamma delay compensation
			rgb_de_g     <= '0'; -- gamma delay compensation		 
            rgb_hs_d     <= '0';
            rgb_vs_d     <= '0';
            video_de     <= '0'; -- used for debugging
            vs_fedge     <= '0';
            video_data   <= (others => '0');			
            rgb_de_g_d   <= '0';
         else
		    rgb_hs_g     <= rgb_hs;
			rgb_vs_g     <= rgb_vs;
			rgb_de_g     <= rgb_de;
            rgb_hs_d     <= rgb_hs_g;
            rgb_vs_d     <= rgb_vs_g;
            video_de     <= rgb_de_g; -- used for debugging
            vs_fedge     <= vs_fedge_out_i;
            rgb_de_g_d   <= rgb_de_g;
			video_data   <= red_gamma & green_gamma & blue_gamma;
            store_data_d <= store_data_i;
         end if;
      end if;
   end process df;

   -- Sync signals edges used for control logics synchronizations
   -- One clock period wide signals

   hs_fedge         <= not rgb_hs_g and rgb_hs_d;   -- detecting falling edge
   hs_fedge_out     <= hs_fedge;
   de_fedge         <= not rgb_de_g and video_de;
   vs_fedge_out_i   <= not rgb_vs_g and rgb_vs_d;
   vs_fedge_out     <= vs_fedge_out_i;
   vs_redge         <= rgb_vs_g and not rgb_vs_d;

   store_data_i     <= hor_window and ver_window; -- active during the storage of properly selected                                                                  -- (cropped) video data
   store_data       <= store_data_i;
   store_end        <= hor_block and (not store_data_i and store_data_d);
   
   ----------------------------------------------------------------
   --                                                            --
   -- Setup horizontal window for video data storage             --
   --                                                            --
   ----------------------------------------------------------------
   
   crop_x_reg  <= conv_std_logic_vector(TOP_LEFT_X, 10);    
   store_x_reg <= conv_std_logic_vector((LINE_LENGTH - 1), 10);    

   pali_x <= '1' when (rgb_de_g = '1' and x_skip = crop_x_reg)   else '0';
   gasi_x <= '1' when (rgb_de_g = '1' and x_count = store_x_reg) else '0';

   process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (video_rst_n = '0') then
            hor_window <= '0';
            hor_block  <= '0';
         else
            hor_window <= (pali_x or hor_window) and not gasi_x;
            hor_block  <= (gasi_x or hor_block) and not hs_fedge;
         end if;
      end if;
   end process;

   ----------------------------------------------------------------
   -- counts till the horizontal beginning of the cropped image  --
   -- removes unwanted beginning of the horizontal line          --
   ----------------------------------------------------------------

   x_before_window: process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (hs_fedge = '1' or video_rst_n = '0') then
            x_skip <= (others => '0');
		 elsif (rgb_de_g = '1' and hor_block = '0') then
            x_skip <= x_skip + 1;
         end if;
      end if;
   end process x_before_window;

   ----------------------------------------------------------------
   -- counts the number of pixels from a single line to store    --
   ----------------------------------------------------------------

   x_window: process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (hs_fedge = '1' or video_rst_n = '0') then
            x_count <= (others => '0');
		 elsif (rgb_de_g = '1' and hor_window = '1') then
            x_count <= x_count + 1;
         end if;
      end if;
   end process x_window;

   ----------------------------------------------------------------
   -- End of X cropping window code                              --
   ----------------------------------------------------------------

   ----------------------------------------------------------------
   -- Start of Y cropping window code                            --
   ----------------------------------------------------------------
   
   crop_y_reg  <= conv_std_logic_vector(TOP_LEFT_Y, 10);      
   
   pali_y <= '1' when (pali_x = '1' and y_skip = crop_y_reg) else '0';
   gasi_y <= '1' when (y_count = store_y_reg and de_fedge = '1') else '0';

   process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (video_rst_n = '0') then
            ver_window <= '0';
			ver_block  <= '0';
         else
            ver_window <= (ver_window or pali_y) and not gasi_y;
			ver_block  <= (ver_block or gasi_y) and not vs_fedge_out_i;
         end if;
      end if;
   end process;
   
   ----------------------------------------------------------------
   -- counts till the vertical beginning of the cropped image    --
   -- removes unwanted lines at the beginning of the frame       --
   ----------------------------------------------------------------

   y_before_window: process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (video_rst_n = '0' or vs_fedge_out_i = '1') then
            y_skip <= (others => '0');
         elsif (de_fedge = '1' and ver_block = '0') then
            y_skip <= y_skip + 1;
         end if;
      end if;
   end process y_before_window;
   
   ----------------------------------------------------------------
   -- counts the number of lines from a single frame to store    --
   ----------------------------------------------------------------

   y_window: process(rgb_clk)
   begin
      if rising_edge(rgb_clk) then
         if (video_rst_n = '0' or vs_fedge_out_i = '1') then
            y_count <= (others => '0');
         elsif (ver_window = '1' and de_fedge = '1') then
            y_count <= y_count + 1;
         end if;
      end if;
   end process y_window;

   ----------------------------------------------------------------
   -- End of Y cropping window code                              --
   ----------------------------------------------------------------

end rtl;



