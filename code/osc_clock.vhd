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
-- Description:
--  Main clock signal generator
--
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

entity osc_clock is
    port (      
          in_clk                : in  std_logic; --  24   MHz from the on-board quartz
		  sclk_clk              : out std_logic; --  25.6 MHz for the LED strips control
          main_clk              : out std_logic; --  48   MHz for the main logic operation
		  clock_lock            : out std_logic  -- high when all DCM modules locked  
   );
end osc_clock;

architecture rtl of osc_clock is

   ----------------------------------------------------------------------------
   -- SIGNALS
   ----------------------------------------------------------------------------
   
    signal clkx         : std_logic; 
    signal clkx_buf     : std_logic;    
    signal dcm_clk      : std_logic;
    signal dcm_clkx2    : std_logic;
    signal dcm_fb       : std_logic;
    signal dcm_lckd     : std_logic; -- 1st DCM locked
	
	signal clk_48       : std_logic;
	signal clk_12_8     : std_logic;
	
	signal lo           : std_logic;
	signal hi           : std_logic;
	
begin

   lo <= '0';
   hi <= '1';
     
   ---------------------------------
   --                             --
   --      Clock generation       --
   --                             --
   ---------------------------------  
   
   -- input clock buffer
   clk_bufg_inst : BUFG
      port map(
         I  => in_clk,
         O  => clkx        -- input 24 MHz
   );
  
   -- feedback clock buffer
   fbclk_bufg_inst : BUFG
      port map(
         I  => clk_48,
         O  => dcm_fb
   );
   
   -- 48 MHz output clock buffer
   oclk_bufg_inst : BUFG
      port map(
         I  => clk_48,
         O  => main_clk
   );
   
   -- 12.8 MHz output clock buffer
   sclk_bufg_inst : BUFG
      port map(
         I  => clk_12_8,
         O  => sclk_clk
   );

	
   DCM_SP_inst : DCM_SP
     generic map (
        CLKDV_DIVIDE          => 2.000,   -- CLKDV divide value -- (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
        CLKFX_DIVIDE          => 15,      -- Divide value on CLKFX outputs - D - (1-32)
        CLKFX_MULTIPLY        => 16,      -- Multiply value on CLKFX outputs - M - (2-32)
        CLKIN_DIVIDE_BY_2     => FALSE,   -- CLKIN divide by two (TRUE/FALSE)
        CLKIN_PERIOD          => 41.667,  -- Input clock period specified in nS
        CLKOUT_PHASE_SHIFT    => "NONE",  -- Output phase shift (NONE, FIXED, VARIABLE)
        CLK_FEEDBACK          => "2X",    -- Feedback source (NONE, 1X, 2X)
 
        DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
        DFS_FREQUENCY_MODE    => "LOW",    -- Unsupported - Do not change value
        DLL_FREQUENCY_MODE    => "LOW",    -- Unsupported - Do not change value
        DSS_MODE              => "NONE",   -- Unsupported - Do not change value
        DUTY_CYCLE_CORRECTION => TRUE,     -- Unsupported - Do not change value
        FACTORY_JF            => X"c080",  -- Unsupported - Do not change value
        PHASE_SHIFT           => 0,        -- Amount of fixed phase shift (-255 to 255)
        STARTUP_WAIT          => FALSE     -- Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
        )                                  
     port map (                            
        CLK0                  => open,     -- 1-bit output: 0 degree clock output
        CLK180                => open,     -- 1-bit output: 180 degree clock output
        CLK270                => open,     -- 1-bit output: 270 degree clock output
        CLK2X                 => clk_48,   -- 1-bit output: 2X clock frequency clock output
        CLK2X180              => open,     -- 1-bit output: 2X clock frequency, 180 degree clock output
        CLK90                 => open,     -- 1-bit output: 90 degree clock output
        CLKDV                 => open,     -- 1-bit output: Divided clock output
        CLKFX                 => clk_12_8, -- 1-bit output: Digital Frequency Synthesizer output (DFS)
        CLKFX180              => open,     -- 1-bit output: 180 degree CLKFX output
        LOCKED                => dcm_lckd, -- 1-bit output: DCM_SP Lock Output
        PSDONE                => open,     -- 1-bit output: Phase shift done output
        STATUS                => open,     -- 8-bit output: DCM_SP status output
        CLKFB                 => dcm_fb,   -- 1-bit input: Clock feedback input
        CLKIN                 => clkx,     -- 1-bit input: Clock input //GG 24MHz
        DSSEN                 => lo,       -- 1-bit input: Unsupported, specify to GND.
        PSCLK                 => lo,       -- 1-bit input: Phase shift clock input
        PSEN                  => lo,       -- 1-bit input: Phase shift enable
        PSINCDEC              => lo,       -- 1-bit input: Phase shift increment/decrement input
        RST                   => lo        -- 1-bit input: Active high reset input
    );
	
	clock_lock <= dcm_lckd;
   
end rtl;



