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
--
-- The design can be implemented with the FREE Xilinx® ISE® WebPack™, the fully featured front-to-back
-- FPGA design solution for Linux, Windows XP, and Windows 7. Design is tested with the version 14.7 that
-- can be downloaded from here: https://www.xilinx.com/products/design-tools/ise-design-suite/ise-webpack.html  
--
--
-- NOTE! The design requires the DVI video receiver IP core. The Pixblasters team use the Xilinx DVI receiver
-- instantiated Xilinx DVI receiver code. Check-out the Xilinx Application Note
-- XAPP495: "Implementing a TMDS Video Interface in the Spartan-6 FPGA" at the following link
-- https://www.xilinx.com/support/documentation/application_notes/xapp495_S6TMDS_Video_Interface
--
--
-- Download the xapp495.zip with the necessary DVI RX source code from here: 
-- https://secure.xilinx.com/webreg/clickthrough.do?cid=154258 
--
-- Follow implementation instructions from the readme.txt file distributed with the code.
--
-----------------------------------------------------------------------------------------------------------
--  Version   Date          Description
--
--  v1.0    11.11.2018.  The pixblasters_light IP core - FPGA demo code for learning and experimenting with 
--                       RGB LEDs. Supported Pixblasters-Light Demo features:  
--
--    - 16 LED strips controller - 8192 RGB WS2812 LEDs
--    - max. 512 LEDs per line
--    - supports 60 fps vertical refresh
--    - RGB888 pixel format - 16M full colors
--    - The LEDs max. display's resolution is 512 x 16 (H x V)
--    - The controller crops the input video and shows the selected cropping window
--    - The top left corner of the LED video output set by TOP_LEFT_X & TOP_LEFT_Y
--    - The length of the LED display line set by LINE_LENGTH (max 512) 
--    - Pixblasters MS1 board's chaining, on-board micro and some other advanced features are not supported  
--
-----------------------------------------------------------------------------------------------------------
-- Description:
--
--  LED strip IP Core controller compatible with the Pixblasters MS1 LED controller board and third-party
--  Xilinx FPGA based boards.                
-----------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                               LIBRARIES
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
--                                ENTITY
-------------------------------------------------------------------------------

-- Note that the input clock strip_clk needs to be 25.6MHz for the best results. The clock is internally
-- divided by 32 - in order to produce 800 kHz clock for the WS2812 RGB LED. The LED strips are quite
-- sensitive on wrong clocking settings. If you use different clocking source, make sure to change the code
-- to stay within LED requirements. If the input clock is different from 25.6MHz, make sure to properly
-- setup the prescal_hold signal in the ledex.vhd. 

entity pixblaster_light is
   generic (
   	  LINE_LENGTH           : integer := 512;  -- defines the length of the display line in pixels - max 512
      TOP_LEFT_X            : integer := 0;    -- defines the x coordinate of the LED display's top left pixel
	  TOP_LEFT_Y            : integer := 0;    -- defines the y coordinate of the LED display's top left pixel
	  C_VCLK_PERIOD         : integer := 15384 -- video vclk clock period in ps (65 MHz)
      );
   port (

	  mclk                  : in  std_logic; -- main clock
	  strip_clk             : in  std_logic; -- 25.6 MHz for the LED strips control
	  clock_lock            : in  std_logic; -- high when all DCM modules locked	
 
      -- Parallel Video Input
      pix_clk               : in  std_logic;
      pix_hsync             : in  std_logic; -- expect active high
      pix_vsync             : in  std_logic; -- expect active high
      pix_de                : in  std_logic;
      pix_data              : in  std_logic_vector(23 downto 0);
	  
      video_valid           : in  std_logic; -- valid signal from the DVI encoder module
	  hdmi_present          : in  std_logic;

      -- LED strips out
      led_out               : out std_logic_vector(15 downto 0)
	  );
end pixblaster_light;

-------------------------------------------------------------------------------
--                             ARCHITECTURE
-------------------------------------------------------------------------------

architecture rtl of pixblaster_light is

-------------------------------------------------------------------------------
--                             COMPONENTS
-------------------------------------------------------------------------------
 
	-- The GET_VIDEO module controls the controller's reset and sets up
	-- both video sync signals to positive polarity

	component get_video is
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
	end component get_video;

	-- The CROPPER block sets up to cropping window as follows:
	-- Top left corner    :   TOP_LEFT_X      ,  TOP_LEFT_Y
    -- Top right corner   :   TOP_LEFT_X + 511,  TOP_LEFT_Y
    -- Bottom left corner :   TOP_LEFT_X      ,  TOP_LEFT_Y + 15
	-- Bottom right corner:   TOP_LEFT_X + 511,  TOP_LEFT_Y + 15

	component cropper is
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
		  video_data             : out std_logic_vector(23 downto 0);
		  store_data             : out std_logic;
		  store_end              : out std_logic
	   );
	end component cropper;

	-- The cropped input video is stored in line buffers. There are two sets of line buffers
    -- that work in an interleaved mode, i.e. while one set of buffers is written to, the other
    -- one is read by the LEDEX module that refreshes the LED display. This module also contains
    -- the mux logic for changing input pixel format, i.e. RGB to GRB, and so on. 

    component liner is
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
		  fetch_address          : in  std_logic_vector(8 downto 0) := (others => '0'); -- counter fixed to 512 pixels
		 
		 -- Outputs		 
		  ramed_pixel            : out std_logic_vector((16 * 24) - 1 downto 0) := (others => '0')
	   );
	end component liner;

	-- The LEDEX block reads the stored lines of pixels and serializes them. The serialized data
	-- is further coded by the WS2812 encoder block. The WS2812 block supports the required bit coding (see datasheet).
	-- The WS2812 block contains programmable LUT tables to support fine tuning of the coded bit values for other
	-- WorldSemi (mnfg.) LED chip drivers: WS2811 and WS2812B. They use the same coding, but the bit timings are different.

	component ledex is
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

		  fetch_address          : out std_logic_vector(8 downto 0) := (others => '0'); -- counter fixed to 512 pixels

		  -- Data inputs

		  out_ready              : out std_logic;
		  out_pixels             : in  std_logic_vector((16 * 24) - 1 downto 0);

		  -- Coded LED Outputs
		  led_out                : out std_logic_vector(15 downto 0)

	   );
	end component ledex;

   ----------------------------------------------------------------------------
   -- SIGNALS
   ----------------------------------------------------------------------------
   
   signal hi                : std_logic;
   signal lo                : std_logic;
   signal rst               : std_logic := '1';

   -- Grabber
   signal grabber_enable    : std_logic := '0';
   signal video_rst_n       : std_logic := '0';
   signal vs_fedge          : std_logic;
   signal pol_detected      : std_logic := '0';

   -- DVI RX

   signal rgb_clk           : std_logic;
   signal rgb_data          : std_logic_vector(23 downto 0);
   signal rgb_de            : std_logic;
   signal rgb_de_d          : std_logic;
   signal fall_de           : std_logic;
   signal rgb_hs            : std_logic;
   signal rgb_vs            : std_logic;

   -- Cropper

   signal hs_fedge          : std_logic;
   signal video_data        : std_logic_vector(23 downto 0);
   signal store_data        : std_logic;
   signal store_end         : std_logic := '0';

   -- ledex

   signal fetch_address     : std_logic_vector(8 downto 0) := (others => '0'); -- counter fixed to 512 pixels
   signal output_pixels     : std_logic_vector((16 * 24) - 1 downto 0) := (others => '0');

   -- for debugging

   signal kochilo           : std_logic_vector(19 downto 0) := (others => '0');
   signal kochilo_tc        : std_logic;
   signal rgb_clk_i         : std_logic;

   signal out_ready         : std_logic;
   signal pol_change        : std_logic;

begin -- architecture

   hi   <= '1';
   lo   <= '0';
   rst  <= not clock_lock;

    ----------------------------------------------------------------------------
	-- DVI RX excepts the dvi input and sources the parallel RGB video interface
	--
	----------------------------------------------------------------------------

	video_in: get_video
	   port map(

		  grabber_enable           => grabber_enable,
		  vs_fedge                 => vs_fedge,
		  hdmi_present             => hdmi_present,

		  video_rst_n              => video_rst_n,
		  pol_detected             => pol_detected,
		  sync_pol_change          => pol_change,

          -- DVI video input
          pix_clk                  => pix_clk,       
          pix_hsync                => pix_hsync,     
          pix_vsync                => pix_vsync,     
          pix_de                   => pix_de,        
          pix_data                 => pix_data,      
          video_valid              => video_valid,   		  

		  -- Selected Parallel RGB input

		  rgb_clk                  => rgb_clk,
		  rgb_data                 => rgb_data, 
		  rgb_de                   => rgb_de,
		  rgb_hs                   => rgb_hs,
		  rgb_vs                   => rgb_vs
	   );

	---------------------------------------------------------------------------
	-- Counts on pol_detected, which means valid_video input, and
	-- after some delay the grabber_enable signal starts the LED controller
	-- In more complex designs, it can be microprocessor controlled.
	---------------------------------------------------------------------------

	process(strip_clk)
	begin
		if rising_edge(strip_clk) then
			if (video_valid = '0' or pol_detected = '0') then
				kochilo <= (others => '0');
			elsif (pol_detected = '1') then
				kochilo <= kochilo + 1;
		    end if;
		end if;
	end process;

	kochilo_tc <= '1' when (kochilo(14) = '1') else '0';

	process(strip_clk)
	begin
		if rising_edge(strip_clk) then
			if (video_valid = '0' or pol_detected = '0') then
				grabber_enable <= '0';
			else
				grabber_enable <= kochilo_tc or grabber_enable;
			end if;
		end if;
	end process;

    ----------------------------------------------------------------------------
	-- Cuts out the video frame portion of the interest
	--
	----------------------------------------------------------------------------

	cutout_win: cropper
	   generic map(
	      LINE_LENGTH => LINE_LENGTH,
          TOP_LEFT_X  => TOP_LEFT_X,  
	      TOP_LEFT_Y  => TOP_LEFT_Y  
            )
	   port map(
		  -- Video Input
		  video_rst_n              => video_rst_n,
		  pol_detected             => pol_detected,

		  rgb_clk                  => rgb_clk,
		  rgb_data                 => rgb_data,
		  rgb_de                   => rgb_de,
		  rgb_hs                   => rgb_hs,
		  rgb_vs                   => rgb_vs,

		  -- Coded LED Outputs
		  vs_fedge_out             => vs_fedge,
		  hs_fedge_out             => hs_fedge,
		  video_data               => video_data,
		  store_data               => store_data,
		  store_end                => store_end
	   );

    ----------------------------------------------------------------------------
	-- BRAM line FIFOs
	--
	----------------------------------------------------------------------------

    line_buffers: liner
	   port map(
		  -- Sync inputs
		  video_rst_n              => video_rst_n,
		  rgb_clk                  => rgb_clk,

		  vs_fedge                 => vs_fedge,
		  hs_fedge                 => hs_fedge,

		  video_data               => video_data,
		  pre_store_data           => store_data,
		  pre_store_end            => store_end,

		  -- Control Pixel for shifting
		  out_ready                => out_ready,
		  strip_clk                => strip_clk,
		  fetch_address            => fetch_address,
		  -- Outputs

		  ramed_pixel              => output_pixels
	   );

    ----------------------------------------------------------------------------
	-- LED modulator portion
	--
	----------------------------------------------------------------------------

	strip_outs: ledex
	   generic map(
	      LINE_LENGTH => LINE_LENGTH
            )
	   port map(
		  strip_clk                => strip_clk,
		  rgb_clk                  => rgb_clk,
		  -- Control Inputs

		  video_rst_n              => video_rst_n,
		  rgb_vs                   => rgb_vs,
		  vs_fedge                 => vs_fedge,

		  -- Control Outputs

          out_ready                => out_ready,
		  fetch_address            => fetch_address,

		  -- Data inputs

		  out_pixels               => output_pixels,

		  -- Coded LED Outputs
		  led_out                  => led_out
	   );

end rtl;

