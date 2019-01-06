# Pixblasters-MicroDemo

Pixblasters_Light Demo is free software distributed under the terms of the GNU General Public License:
<https://www.gnu.org/licenses/>.

INTRODUCTION:
-------------

The Pixblasters Light Demo is a derivative work from the the Pixblasters MS1 project promoted through the
Crowd Supply crowdfunding platform:

https://www.crowdsupply.com/pixblasters/pixblasters-video-led-controller

The Pixblasters MS1 Video LED Controller is an ultimate FPGA-based video LED controller that enables DIY 
enthusiasts and signage professionals, even those with minimal technical skills, to turn a bunch of 
addressable RGB LED strips into immense video LED displays for different applications. This LED controller 
enables new classes of professionally looking digital signage that cannot be supported by standard rigid 
LED modules. The LED strips can be curved and glued to different surfaces to form giant and economically 
viable video installations that may span the complete buildings. The Pixblasters MS1 video LED controller 
connects to any computer, such as the Raspberry Pi and similar single board computers, and any operating 
system as an ordinary monitor to copy the user selected part of the monitor image to up to 16,384 LEDs at 
60 fps. Multiple daisy-chained MS1 controllers can drive high-resolution LED displays built of hundreds of 
thousands of perfectly synchronized LEDs that display any visual content with absolutely no programming 
required. The controller puts no burden on the driving computer that is free to run digital signage players,
media players, and other video software at the full speed. The LED displays controlled by the Pixblasters 
MS1 can be remotely managed by digital signage software anywhere in the world.

The Pixblasters Light Demo demonstrates some of the Pixblasters MS1 LED controller's features.

KEY IP CORE DESCRIPTION:
------------------------

The pixblaster_light is a key IP core for high-capacity LED controllers. The IP captures video from the 
DVI or the RGB parallel video input and buffers the programmed number of up to 16 video lines 
(max. length 512 pixels). It can crop the input video at an arbitrary position, double-buffer cropped 
image and shift it out serialized and encoded for driving addressable (digital) LED strips. 
The pixblasters_light IP can drive thousands of LEDs at once and at the refresh rate allowable by the 
maximum LED strips communication speed with no help from the processor.

The top level design of the Pixblasters-Light Demo LED controller includes the pixblasters_light
IP core, instantiates the DVI video input receiver and the necessary clocking infrastructure.
The design is fully compatible with the Pixblasters MS1 Video LED Strip Controller board. It can be also
adapted for use with third-party Xilinx FPGA based boards. The supported Pixblasters_Light Demo features:  

  - 16 LED strips controller - 8192 RGB WS2812 LEDs
  - max. 512 LEDs per line
  - supports 60 fps vertical refresh
  - RGB888 pixel format - 16M full colors
  - The LEDs max. display's resolution is 512 x 16 (H x V)
  - The controller crops the input video and shows the selected cropping window
  - The top left corner of the LED video output set by TOP_LEFT_X & TOP_LEFT_Y
  - The length of the LED display line set by LINE_LENGTH (max 512) 
  - Pixblasters MS1 board's chaining, on-board micro and some other advanced features are not supported  

IMPLEMENTATION INSTRUCTIONS:
-----------------------------

The design can be implemented with the FREE Xilinx® ISE® WebPack™, the fully featured front-to-back
FPGA design solution for Linux, Windows XP, and Windows 7. Design is tested with the version 14.7 that
can be downloaded from here: https://www.xilinx.com/products/design-tools/ise-design-suite/ise-webpack.html  

NOTE! The demo design requires the DVI video receiver IP core. The Pixblasters team uses the Xilinx 
Xilinx DVI receiver code. Check-out the Xilinx Application Note XAPP495:
"Implementing a TMDS Video Interface in the Spartan-6 FPGA" at the following link
https://www.xilinx.com/support/documentation/application_notes/xapp495_S6TMDS_Video_Interface

In your designs you can use other DVI receivers, but make sure to provide parallel RGB video input
into the pixblasters_light IP core.

Download the xapp495.zip with the necessary DVI RX source code from here: 
https://secure.xilinx.com/webreg/clickthrough.do?cid=154258 

 1. Unzip the downloaded file and go to the folder \dvi_demo\rtl\rx
 2. Copy all files (listed) from that folder into \Pixblasters-MicroDemo\code\RX_code
      - chnlbond.v
      - decode.v
      - dvi_decoder.v
      - phsaligner.v
      - serdes_1_to_5_diff_data.v
 3. If you don't change the serdes_1_to_5_diff_data.v file as explained in 4., Xilinx ISE 14.7 will
    report the following error "...Mix of blocking and non-blocking assignments to variable <inc_data_int>
	is not a recommended coding practice."
	
 4.	Change the serdes_1_to_5_diff_data.v file as instructed below:
 
      - change line 236 from "in_data_int = debug_in[1];" into "inc_data_int <= debug_in[1];"
	  - change line 273 from ".COUNTER_WRAPAROUND   ("STAY_AT_LIMIT"), //("WRAPAROUND");"
        into ".COUNTER_WRAPAROUND ("WRAPARROUND");" 
 5. From the unzipped folder \dvi_demo\rtl\common copy DRAM16XN.v file to your
    \Pixblasters-MicroDemo\code\RX_code folder  
 6. If you use the code with the Pixblasters MS1 board, use the system.ucf constraints file. If you use
    other HW board, adapt the system.ucf to the specific hardware.
 7. Use the preset ISE project to start the implementation
 8. If you want to check the HW setup with the pre-verified FPGA configuration file, use the
    pixblaster_top.bit file from the /proj folder. 


DEMO CONTROLS:
---------------

The pixblasters_light IP Core does not support all features implemented in the Pixblasters MS1 video LED 
controller board. However, it provides a lot of design freedom to those who want to use it with the custom
made LED displays. The pixblasters_light can select (crop) a specific portion of the input video image and
format it for display on WS2812 RGB LED display. The video selection window is defined with the following 
three VHDL generics:

 1. LINE_LENGTH that defines the length of the display line in pixels - max 512
 2. TOP_LEFT_X  that defines the x coordinate of the LED display's top left pixel
 3. TOP_LEFT_Y  that defines the y coordinate of the LED display's top left pixel
 
Generics MUST be set as follows:

LINE_LENGTH + TOP_LEFT_X ≤ Horizontal Resolution - 1
 
Example - for the 720p (1280 x 720) video input, example valid settings are: 

   LINE_LENGTH = 464
   TOP_LEFT_X  = 815
   TOP_LEFT_Y  = 330
 - These settings instruct the pixblasters_light IP core to display 464 x 16 (HRES x VRES) video with the 
   top left corner at position (815, 330)
   
Example - for the 720p (1280 x 720) video input, example invalid settings are: 

   LINE_LENGTH = 465 - NOTE THE DIFFERENCE
   TOP_LEFT_X  = 815
   TOP_LEFT_Y  = 330
   
   465 + 815 ≤ 1280 - 1 (INVALID!)
   
 - These settings would cause wrongly formatted and displayed video LED image.
   


   
   
   
