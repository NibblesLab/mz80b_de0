--
-- mz80b_core.vhd
--
-- SHARP MZ-80B/2000 series compatible logic, main module
-- for Altera DE0
--
-- Nibbles Lab. 2013-2014
--

--
-- Slave Memory Map (from NiosII)
--
-- 0000-000F System Control
-- 0010-001F CMT
-- 0040-005F FDD1
-- 0060-007F FDD2
-- C000-C0FF Keymap keymatrix.vhd
-- C800-CFFF CG-ROM videoout.vhd
-- D000-D7FF C-VRAM videoout.vhd
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity mz80b_core is
  port(
		-- Z80 Memory Bus
		ZADR			: out std_logic_vector(22 downto 0);
		ZDI			: in std_logic_vector(7 downto 0);
		ZDO			: out std_logic_vector(7 downto 0);
		ZCS_x			: out std_logic;
		ZWR_x			: out std_logic;
		ZPG_x			: out std_logic;
		-- NiosII Access
		RRST_x		: in std_logic;								-- NiosII Reset
		RCLK			: in std_logic;								-- NiosII Clock
		RADR			: in std_logic_vector(15 downto 0);		-- NiosII Address Bus
		RCS_x			: in std_logic;								-- NiosII Read Signal
		RWE_x			: in std_logic;								-- NiosII Write Signal
		RDI			: in std_logic_vector(7 downto 0);		-- NiosII Data Bus(in)
		RDO			: out std_logic_vector(7 downto 0);		-- NiosII Data Bus(out)
		INTL			: out std_logic;								-- Interrupt Line
		-- Graphic VRAM Access
		GCS_x			: out std_logic;								-- GRAM Request
		GADR			: out std_logic_vector(20 downto 0);	-- GRAM Address
		GWR_x			: out std_logic;				 				-- GRAM Write Signal
		GBE_x			: out std_logic_vector(3 downto 0);		-- GRAM Byte Enable
		GDI			: in std_logic_vector(31 downto 0);		-- Data Bus Input from GRAM
		GDO			: out std_logic_vector(31 downto 0);	-- Data Bus Output to GRAM
		-- FD Buffer RAM I/F
		BCS_x 		: out std_logic;								-- RAM Request
		BADR 		 	: out std_logic_vector(22 downto 0);	-- RAM Address
		BWR_x 		: out std_logic;				 				-- RAM Write Signal
		BDI			: in std_logic_vector(7 downto 0);		-- Data Bus Input from RAM
		BDO			: out std_logic_vector(7 downto 0);		-- Data Bus Output to RAM
		-- Resets
		URST_x		: out std_logic;							-- Universal Reset
		MRST_x		: in std_logic;							-- Reset after SDRAM init.
		ARST_x		: out std_logic;							-- All Reset
		-- Clock Input
		CLOCK_50		: in std_logic;							--	50 MHz
		-- Push Button
		BUTTON		: in std_logic_vector(2 downto 0);	--	Pushbutton[2:0]
		-- Switch
		SW				: in std_logic_vector(9 downto 0);	--	Toggle Switch[9:0]
		-- 7-SEG Dispaly
		HEX0_D		: out std_logic_vector(6 downto 0);	--	Seven Segment Digit 0
		HEX0_DP		: out std_logic;							--	Seven Segment Digit DP 0
		HEX1_D		: out std_logic_vector(6 downto 0);	--	Seven Segment Digit 1
		HEX1_DP		: out std_logic;							--	Seven Segment Digit DP 1
		HEX2_D		: out std_logic_vector(6 downto 0);	--	Seven Segment Digit 2
		HEX2_DP		: out std_logic;							--	Seven Segment Digit DP 2
		HEX3_D		: out std_logic_vector(6 downto 0);	--	Seven Segment Digit 3
		HEX3_DP		: out std_logic;							--	Seven Segment Digit DP 3
		-- LED
		LEDG			: out std_logic_vector(9 downto 0);		--	LED Green[9:0]
		-- PS2
		PS2_KBDAT	: in std_logic;						--	PS2 Keyboard Data
		PS2_KBCLK	: in std_logic;						--	PS2 Keyboard Clock
		-- VGA
		VGA_HS		: out std_logic;							--	VGA H_SYNC
		VGA_VS		: out std_logic;							--	VGA V_SYNC
		VGA_R			: out std_logic_vector(3 downto 0); --	VGA Red[3:0]
		VGA_G			: out std_logic_vector(3 downto 0);	--	VGA Green[3:0]
		VGA_B			: out std_logic_vector(3 downto 0);  	--	VGA Blue[3:0]
		-- GPIO
		GPIO0_CLKIN	: in std_logic_vector(1 downto 0);		--	GPIO Connection 0 Clock In Bus
		GPIO0_CLKOUT: out std_logic_vector(1 downto 0);		--	GPIO Connection 0 Clock Out Bus
		GPIO0_D		: out std_logic_vector(31 downto 0);	--	GPIO Connection 0 Data Bus
		GPIO1_CLKIN	: in std_logic_vector(1 downto 0);		--	GPIO Connection 1 Clock In Bus
		GPIO1_CLKOUT: out std_logic_vector(1 downto 0);		--	GPIO Connection 1 Clock Out Bus
		GPIO1_D		: inout std_logic_vector(31 downto 0)	--	GPIO Connection 1 Data Bus
  );
end mz80b_core;

architecture rtl of mz80b_core is

--
-- T80
--
signal MREQ_x : std_logic;
signal IORQ_x : std_logic;
signal WR_x : std_logic;
signal RD_x : std_logic;
--signal MWR : std_logic;
--signal MRD : std_logic;
signal IWR : std_logic;
signal ZWAIT_x : std_logic;
signal M1 : std_logic;
signal RFSH_x : std_logic;
signal ZADDR : std_logic_vector(15 downto 0);
signal ZDTO : std_logic_vector(7 downto 0);
signal ZDTI : std_logic_vector(7 downto 0);
--signal RAMCS_x : std_logic;
signal RAMDI : std_logic_vector(7 downto 0);
signal BAK_x : std_logic;
signal BREQ_x : std_logic;
--
-- Clocks
--
signal CK4M : std_logic;
signal CK16M : std_logic;
signal CK25M : std_logic;
signal CK3125 : std_logic;
--signal SCLK : std_logic;
--signal HCLK : std_logic;
signal CASCADE01 : std_logic;
signal CASCADE12 : std_logic;
--
-- Decodes, misc
--
--signal CSE_x : std_logic;
--signal CSE2_x : std_logic;
--signal BUF : std_logic_vector(9 downto 0);
signal ZRST : std_logic;
signal ARST : std_logic;
signal CSHSK : std_logic;
signal MZMODE : std_logic;
signal DMODE : std_logic;
signal KBEN : std_logic;
signal KBDT : std_logic_vector(7 downto 0);
signal BOOTM : std_logic;
signal F_BTN : std_logic;
signal I_CMT : std_logic;
signal C_LEDG : std_logic_vector(9 downto 0);
signal I_FDD : std_logic;
signal F_LEDG : std_logic_vector(9 downto 0);
--
-- Avalon Bus
--
signal DO_FDU : std_logic_vector(7 downto 0);
signal DO_CMT : std_logic_vector(7 downto 0);
signal DO_CTRL : std_logic_vector(7 downto 0);
signal DO_VOUT : std_logic_vector(7 downto 0);
signal DO_KMTX : std_logic_vector(7 downto 0);
--
-- Video
--
--signal HBLNK : std_logic;
signal VBLNK : std_logic;
signal HSYNCi : std_logic;
signal HSYNC : std_logic;
signal VSYNC : std_logic;
signal Ri : std_logic;
signal Gi : std_logic;
signal Bi : std_logic;
signal R : std_logic;
signal G : std_logic;
signal B : std_logic;
--signal VGATE : std_logic;
signal CSV_x : std_logic;
signal CSG_x : std_logic;
signal VRAMDO : std_logic_vector(7 downto 0);
--
-- PPI
--
signal CSE0_x : std_logic;
signal DOPPI : std_logic_vector(7 downto 0);
signal PPIPA : std_logic_vector(7 downto 0);
signal PPIPB : std_logic_vector(7 downto 0);
signal PPIPC : std_logic_vector(7 downto 0);
signal BST_x : std_logic;
--
-- PIT
--
signal CSE4_x : std_logic;
signal DOPIT : std_logic_vector(7 downto 0);
signal RST8253_x : std_logic;
--
-- PIO
--
signal CSE8_x : std_logic;
signal DOPIO : std_logic_vector(7 downto 0);
signal INT_x : std_logic;
signal PIOPA : std_logic_vector(7 downto 0);
signal PIOPB : std_logic_vector(7 downto 0);
--
-- FDD,FDC
--
signal DOFDC : std_logic_vector(7 downto 0);
signal DS : std_logic_vector(3 downto 0);
signal HS : std_logic;
signal MOTOR_x : std_logic;
signal INDEX_x : std_logic;
signal TRACK00_x : std_logic;
signal WPRT_x : std_logic;
signal STEP_x : std_logic;
signal DIREC : std_logic;
signal FDO : std_logic_vector(7 downto 0);
signal FDI : std_logic_vector(7 downto 0);
signal WGATE_x : std_logic;
signal DTCLK : std_logic;
--
-- for Debug
--
signal LDDAT : std_logic_vector(7 downto 0);

--
-- Components
--
--component T80s
component T80se
	generic(
		Mode : integer := 0;    -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
		T2Write : integer := 0;  -- 0 => WR_n active in T3, /=0 => WR_n active in T2
		IOWait : integer := 1   -- 0 => Single cycle I/O, 1 => Std I/O cycle
	);
	port(
		RESET_n         : in  std_logic;
		CLK_n           : in  std_logic;
		CLKEN           : in  std_logic;
		WAIT_n          : in  std_logic;
		INT_n           : in  std_logic;
		NMI_n           : in  std_logic;
		BUSRQ_n         : in  std_logic;
		M1_n            : out std_logic;
		MREQ_n          : out std_logic;
		IORQ_n          : out std_logic;
		RD_n            : out std_logic;
		WR_n            : out std_logic;
		RFSH_n          : out std_logic;
		HALT_n          : out std_logic;
		BUSAK_n         : out std_logic;
		A               : out std_logic_vector(15 downto 0);
		DI              : in  std_logic_vector(7 downto 0);
		DO              : out std_logic_vector(7 downto 0)
	);
end component;

component i8255
	Port (
		RST	 : in std_logic;
		CLK	 : in std_logic;
		A		 : in std_logic_vector(1 downto 0);
		CS		 : in std_logic;
		RD		 : in std_logic;
		WR		 : in std_logic;
		DI		 : in std_logic_vector(7 downto 0);
		DO		 : out std_logic_vector(7 downto 0);
		-- Port
		PA		 : out std_logic_vector(7 downto 0);
		PB		 : in std_logic_vector(7 downto 0);
		PC		 : out std_logic_vector(7 downto 0);
		-- Mode
		MZMODE : in std_logic;								-- Hardware Mode
		-- for Debug
		LDDAT  : out std_logic_vector(7 downto 0)
--		LDDAT2 : out std_logic;
--		LDSNS  : out std_logic;
	);
end component;

component i8253
	Port (
		RST : in std_logic;
		CLK : in std_logic;
		A : in std_logic_vector(1 downto 0);
		DI : in std_logic_vector(7 downto 0);
		DO : out std_logic_vector(7 downto 0);
		CS : in std_logic;
		WR : in std_logic;
		RD : in std_logic;
		CLK0 : in std_logic;
		GATE0 : in std_logic;
		OUT0 : out std_logic;
		CLK1 : in std_logic;
		GATE1 : in std_logic;
		OUT1 : out std_logic;
		CLK2 : in std_logic;
		GATE2 : in std_logic;
		OUT2 : out std_logic
	);
end component;

component z8420
	Port (
		-- System
		RST	 : in std_logic;								-- Only Power On Reset
		-- Z80 Bus Signals
		CLK	 : in std_logic;
		BASEL	 : in std_logic;
		CDSEL	 : in std_logic;
		CE		 : in std_logic;
		RD_x	 : in std_logic;
		WR_x	 : in std_logic;
		IORQ_x : in std_logic;
		M1_x	 : in std_logic;
		DI     : in std_logic_vector(7 downto 0);
		DO     : out std_logic_vector(7 downto 0);
		IEI	 : in std_logic;
		IEO	 : out std_logic;
		INT_x	 : out std_logic;
		-- Port
		A		 : out std_logic_vector(7 downto 0);
		B		 : in std_logic_vector(7 downto 0);
		-- for Debug
		LDDAT  : out std_logic_vector(7 downto 0)
--		LDDAT2 : out std_logic;
--		LDSNS  : out std_logic;
	);
end component;

component keymatrix
	Port (
		-- i8255/PIO
		ZRST_x : in std_logic;
		STROBE : in std_logic_vector(3 downto 0);
		STALL	 : in std_logic;
		KDATA	 : out std_logic_vector(7 downto 0);
		-- PS/2 Keyboard Data
		KCLK   : in std_logic;								-- Key controller base clock
		KBEN   : in std_logic;								-- PS/2 Keyboard Data Valid
		KBDT   : in std_logic_vector(7 downto 0);		-- PS/2 Keyboard Data
		-- for Debug
		LDDAT : out std_logic_vector(7 downto 0);
		-- Avalon Bus
		RRST_x : in std_logic;								-- NiosII Reset
		RCLK	 : in std_logic;								-- NiosII Clock
		RADR	 : in std_logic_vector(15 downto 0);	-- NiosII Address Bus
		RCS_x	 : in std_logic;								-- NiosII Read Signal
		RWE_x	 : in std_logic;								-- NiosII Write Signal
		RDI	 : in std_logic_vector(7 downto 0);		-- NiosII Data Bus(in)
		RDO	 : out std_logic_vector(7 downto 0)		-- NiosII Data Bus(out)
	);
end component;

component ps2kb
	Port (
		RST : in std_logic;
		KCLK : in std_logic;
		PS2CK : in std_logic;
		PS2DT : in std_logic;
		DTEN : out std_logic;
		DATA : out std_logic_vector(7 downto 0)
	);
end component;

component videoout
	Port (
		RST    : in std_logic;		-- Reset
		MZMODE : in std_logic;		-- Hardware Mode
		DMODE  : in std_logic;		-- Display Mode
		-- Clocks
		CK50M  : in std_logic;		-- Master Clock(50MHz)
		CK25M  : out std_logic;		-- VGA Clock(12.5MHz)
		CK16M  : out std_logic;		-- 15.6kHz Dot Clock(16MHz)
		CK4M   : out std_logic;		-- CPU/CLOCK Clock(4MHz)
		CK3125 : out std_logic;		-- Music Base Clock(31.25kHz)
		-- CPU Signals
		A      : in std_logic_vector(13 downto 0);	-- CPU Address Bus
		CSV_x  : in std_logic;								-- CPU Memory Request(VRAM)
		CSG_x  : in std_logic;								-- CPU Memory Request(GRAM)
		RD_x   : in std_logic;								-- CPU Read Signal
		WR_x   : in std_logic;								-- CPU Write Signal
		MREQ_x : in std_logic;								-- CPU Memory Request
		IORQ_x : in std_logic;								-- CPU I/O Request
		WAIT_x : out std_logic;								-- CPU Wait Request
		DI     : in std_logic_vector(7 downto 0);		-- CPU Data Bus(in)
		DO     : out std_logic_vector(7 downto 0);	-- CPU Data Bus(out)
		-- Graphic VRAM Access
		GCS_x  : out std_logic;								-- GRAM Request
		GADR   : out std_logic_vector(20 downto 0);	-- GRAM Address
		GWR_x  : out std_logic;				 				-- GRAM Write Signal
		GBE_x  : out std_logic_vector(3 downto 0);	-- GRAM Byte Enable
		GDI	 : in std_logic_vector(31 downto 0);	-- Data Bus Input from GRAM
		GDO	 : out std_logic_vector(31 downto 0);	-- Data Bus Output to GRAM
		-- Video Control from outside
		INV	 : in std_logic;		-- Reverse mode(8255 PA4)
		VGATE  : in std_logic;		-- Video Output Control(8255 PC0)
		CH80   : in std_logic;		-- Text Character Width(Z80PIO A5)
		-- Video Signals
		--HBLANK : out std_logic;		-- Horizontal Blanking
		VBLANK : out std_logic;		-- Vertical Blanking
		HSYNC  : out std_logic;		-- Horizontal Sync
		VSYNC  : out std_logic;		-- Vertical Sync
		ROUT   : out std_logic;		-- Red Output
		GOUT   : out std_logic;		-- Green Output
		BOUT   : out std_logic;		-- Green Output
		-- Avalon Bus
		RRST_x  : in std_logic;								-- NiosII Reset
		RCLK	  : in std_logic;								-- NiosII Clock
		RADR	  : in std_logic_vector(15 downto 0);	-- NiosII Address Bus
		RCS_x	  : in std_logic;								-- NiosII Read Signal
		RWE_x	  : in std_logic;								-- NiosII Write Signal
		RDI	  : in std_logic_vector(7 downto 0);	-- NiosII Data Bus(in)
		RDO	  : out std_logic_vector(7 downto 0);	-- NiosII Data Bus(out)
		-- Control Signal
		BOOTM	 : in std_logic;								-- BOOT Mode
		BACK	 : in std_logic								-- Z80 Bus Acknowlegde
	);
end component;

component ScanConv
	Port (
		CK16M : in STD_LOGIC;		-- MZ Dot Clock
		CK25M : in STD_LOGIC;		-- VGA Dot Clock
		RI    : in STD_LOGIC;		-- Red Input
		GI    : in STD_LOGIC;		-- Green Input
		BI    : in STD_LOGIC;		-- Blue Input
		HSI   : in STD_LOGIC;		-- H-Sync Input(MZ,15.6kHz)
		RO    : out STD_LOGIC;		-- Red Output
		GO    : out STD_LOGIC;		-- Green Output
		BO    : out STD_LOGIC;		-- Blue Output
		HSO   : out STD_LOGIC		-- H-Sync Output(VGA, 31kHz)
	);
end component;

component cmt
	Port (
		-- Avalon Bus
		RRST_x  : in std_logic;								-- NiosII Reset
		RCLK	  : in std_logic;								-- NiosII Clock
		RADR	  : in std_logic_vector(15 downto 0);	-- NiosII Address Bus
		RCS_x	  : in std_logic;								-- NiosII Read Signal
		RWE_x	  : in std_logic;								-- NiosII Write Signal
		RDI	  : in std_logic_vector(7 downto 0);	-- NiosII Data Bus(in)
		RDO	  : out std_logic_vector(7 downto 0);	-- NiosII Data Bus(out)
		-- 7-SEG Dispaly
		HEX0_D  : out std_logic_vector(6 downto 0);	--	Seven Segment Digit 0
		HEX0_DP : out std_logic;							--	Seven Segment Digit DP 0
		HEX1_D  : out std_logic_vector(6 downto 0);	--	Seven Segment Digit 1
		HEX1_DP : out std_logic;							--	Seven Segment Digit DP 1
		HEX2_D  : out std_logic_vector(6 downto 0);	--	Seven Segment Digit 2
		HEX2_DP : out std_logic;							--	Seven Segment Digit DP 2
		HEX3_D  : out std_logic_vector(6 downto 0);	--	Seven Segment Digit 3
		HEX3_DP : out std_logic;							--	Seven Segment Digit DP 3
		-- LED
		LEDG	  : out std_logic_vector(9 downto 0);	--	LED Green[9:0]
		-- Interrupt
		INTO	  : out std_logic;							-- Tape action interrupt
		-- Z80 Bus
		ZCLK	  : in std_logic;
		-- Tape signals
		T_END	  : out std_logic;							-- Sense CMT(Motor on/off)
		OPEN_x  : in std_logic;								-- Open
		PLAY_x  : in std_logic;								-- Play
		STOP_x  : in std_logic;								-- Stop
		FF_x	  : in std_logic;								-- Fast Foward
		REW_x	  : in std_logic;								-- Rewind
		APSS_x  : in std_logic;								-- APSS
		FFREW	  : in std_logic;								-- FF/REW mode
		FMOTOR  : in std_logic;								-- FF/REW start
		FLATCH  : in std_logic;								-- FF/REW latch
		WREADY  : out std_logic;							-- Write enable
		TREADY  : out std_logic;							-- Tape exist
		RDATA	  : out std_logic;							-- to 8255
		-- Status Signal
		SCLK	  : in std_logic;								-- Slow Clock(31.25kHz)
		MZMODE  : in std_logic;								-- Hardware Mode
		DMODE   : in std_logic								-- Display Mode
	);
end component;

component sysctrl
  port(
		-- Avalon Bus
		RRST_x  : in std_logic;								-- NiosII Reset
		RCLK	  : in std_logic;								-- NiosII Clock
		RADR	  : in std_logic_vector(15 downto 0);	-- NiosII Address Bus
		RCS_x	  : in std_logic;								-- NiosII Read Signal
		RWE_x	  : in std_logic;								-- NiosII Write Signal
		RDI	  : in std_logic_vector(7 downto 0);	-- NiosII Data Bus(in)
		RDO	  : out std_logic_vector(7 downto 0);	-- NiosII Data Bus(out)
		-- Push Button
		BUTTON  : in std_logic_vector(2 downto 0);	--	Pushbutton[2:0]
		-- Switch
		SW		  : in std_logic_vector(9 downto 0);	--	Toggle Switch[9:0]
		-- PS/2 Keyboard Data
		KBEN   : in std_logic;								-- PS/2 Keyboard Data Valid
		KBDT   : in std_logic_vector(7 downto 0);		-- PS/2 Keyboard Data
		-- Interrupt
		INTL	 : out std_logic;								-- Interrupt Signal Output
		I_CMT	 : in std_logic;								-- from CMT
		I_FDD	 : in std_logic;								-- from FD unit
		-- Others
		URST_x : out std_logic;								-- Universal Reset
		MRST_x : in std_logic;								-- Reset after SDRAM init.
		ARST_x : out std_logic;								-- All Reset
		ZRST	 : out std_logic;								-- Z80 Reset
		CLK50	 : in std_logic;								-- 50MkHz
		SCLK	 : in std_logic;								-- 31.25kHz
		ZBREQ	 : out std_logic;								-- Z80 Bus Request
		ZBACK	 : in std_logic;								-- Z80 Bus Acknowridge
		BST_x	 : in std_logic;								-- BOOT start request from Z80
		BOOTM	 : out std_logic;								-- BOOT mode
		F_BTN	 : out std_logic								-- Function Button
  );
end component;

component mz1e05
	Port (
		-- CPU Signals
		ZRST_x  : in std_logic;
		ZCLK	  : in std_logic;
		ZADR	  : in std_logic_vector(7 downto 0);	-- CPU Address Bus(lower)
		ZRD_x	  : in std_logic;								-- CPU Read Signal
		ZWR_x	  : in std_logic;								-- CPU Write Signal
		ZIORQ_x : in std_logic;								-- CPU I/O Request
		ZDI	  : in std_logic_vector(7 downto 0);	-- CPU Data Bus(in)
		ZDO	  : out std_logic_vector(7 downto 0);	-- CPU Data Bus(out)
		SCLK	  : in std_logic;								-- Slow Clock
		-- FD signals
		DS_x	  : out std_logic_vector(4 downto 1);	-- Drive Select
		HS		  : out std_logic;							-- Head Select
		MOTOR_x : out std_logic;							-- Motor On
		INDEX_x : in std_logic;								-- Index Hole Detect
		TRACK00 : in std_logic;								-- Track 0
		WPRT_x  : in std_logic;								-- Write Protect
		STEP_x  : out std_logic;							-- Head Step In/Out
		DIREC	  : out std_logic;							-- Head Step Direction
		WGATE_x : out std_logic;							-- Write Gate
		DTCLK	  : in std_logic;								-- Data Clock
		FDI	  : in std_logic_vector(7 downto 0);	-- Read Data
		FDO	  : out std_logic_vector(7 downto 0)	-- Write Data
	);
end component;

component fdunit
	Port (
		-- Avalon Bus
		RRST_x  : in std_logic;								-- NiosII Reset
		RCLK	  : in std_logic;								-- NiosII Clock
		RADR	  : in std_logic_vector(15 downto 0);	-- NiosII Address Bus
		RCS_x	  : in std_logic;								-- NiosII Read Signal
		RWE_x	  : in std_logic;								-- NiosII Write Signal
		RDI	  : in std_logic_vector(7 downto 0);	-- NiosII Data Bus(in)
		RDO	  : out std_logic_vector(7 downto 0);	-- NiosII Data Bus(out)
		-- Interrupt
		INTO	  : out std_logic;							-- Step Pulse interrupt
		-- FD signals
		FCLK	  : in std_logic;
		DS_x	  : in std_logic_vector(4 downto 1);	-- Drive Select
		HS		  : in std_logic;								-- Head Select
		MOTOR_x : in std_logic;								-- Motor On
		INDEX_x : out std_logic;							-- Index Hole Detect
		TRACK00 : out std_logic;							-- Track 0
		WPRT_x  : out std_logic;							-- Write Protect
		STEP_x  : in std_logic;								-- Head Step In/Out
		DIREC	  : in std_logic;								-- Head Step Direction
		WG_x	  : in std_logic;								-- Write Gate
		DTCLK	  : out std_logic;							-- Data Clock
		FDI	  : in std_logic_vector(7 downto 0);	-- Write Data
		FDO	  : out std_logic_vector(7 downto 0);	-- Read Data
		-- LED
		LEDG	  : out std_logic_vector(9 downto 0);	--	LED Green[9:0]
		SCLK	  : in std_logic;								-- Slow Clock
		-- Buffer RAM I/F
		BCS_x  : out std_logic;								-- RAM Request
		BADR   : out std_logic_vector(22 downto 0);	-- RAM Address
		BWR_x  : out std_logic;				 				-- RAM Write Signal
		BDI	 : in std_logic_vector(7 downto 0);		-- Data Bus Input from RAM
		BDO	 : out std_logic_vector(7 downto 0)		-- Data Bus Output to RAM
	);
end component;

begin

	--
	-- Instantiation
	--
	CPU0 : T80se
	generic map(
		Mode => 0,	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
		T2Write => 1,	-- 0 => WR_n active in T3, /=0 => WR_n active in T2
		IOWait => 1	-- 0 => Single cycle I/O, 1 => Std I/O cycle
	)
	port map (
		RESET_n => ZRST,
		CLK_n => CK4M,
		CLKEN => '1',
		WAIT_n => ZWAIT_x,
		INT_n => INT_x,
--		INT_n => '1',
		NMI_n => '1',
		BUSRQ_n => BREQ_x,
		M1_n => M1,
		MREQ_n => MREQ_x,
		IORQ_n => IORQ_x,
		RD_n => RD_x,
		WR_n => WR_x,
		RFSH_n => RFSH_x,
		HALT_n => open,
		BUSAK_n => BAK_x,
		A => ZADDR,
		DI => ZDTI,
		DO => ZDTO
	);

	PPI0 : i8255 port map (
		RST => ZRST,
		CLK => CK4M,
		A => ZADDR(1 downto 0),
		CS => CSE0_x,
		RD	=> RD_x,
		WR => WR_x,
		DI => ZDTO,
		DO => DOPPI,
		-- Port
		PA => PPIPA,
		PB => PPIPB,
		PC => PPIPC,
		-- Mode
		MZMODE => MZMODE,			-- Hardware Mode
		-- for Debug
		LDDAT => LDDAT
--		LDDAT2 => LD(5),
--		LDSNS => LD(6),
	);
	PPIPB(7)<=PIOPB(7);
--	WDATA<=PPIPC(7);
--	REC_x<=PPIPC(6);
--	WRIT_x<=PPIPC(6);
--	KINH<=PPIPC(5);
--	L_FR<=PPIPC(5);
	BST_x<=PPIPC(3);
--	NST<=PPIPC(1);

	CMT0 : cmt port map (
		-- Avalon Bus
		RRST_x => RRST_x,			-- NiosII Reset
		RCLK => RCLK,				-- NiosII Clock
		RADR => RADR,				-- NiosII Address Bus
		RCS_x => RCS_x,			-- NiosII Read Signal
		RWE_x => RWE_x,			-- NiosII Write Signal
		RDI => RDI,					-- NiosII Data Bus(in)
		RDO => DO_CMT,				-- NiosII Data Bus(out)
		-- 7-SEG Dispaly
		HEX0_D => HEX0_D,
		HEX0_DP => HEX0_DP,
		HEX1_D => HEX1_D,
		HEX1_DP => HEX1_DP,
		HEX2_D => HEX2_D,
		HEX2_DP => HEX2_DP,
		HEX3_D => HEX3_D,
		HEX3_DP =>HEX3_DP,
		-- LED
		LEDG => C_LEDG,			--	LED Green[9:0]
		-- Interrupt
		INTO => I_CMT,				-- Tape action interrupt
		-- Z80 Bus
		ZCLK => CK4M,
		-- Tape signals
		T_END => PPIPB(3),		-- Sense CMT(Motor on/off)
		OPEN_x => PPIPC(4),		-- Open
		PLAY_x => PPIPA(2),		-- Play
		STOP_x => PPIPA(3),		-- Stop
		FF_x => PPIPA(1),			-- Fast Foward
		REW_x => PPIPA(0),		-- Rewind
		APSS_x => PPIPA(7),		-- APSS
		FFREW => PPIPA(1),		-- FF/REW mode
		FMOTOR => PPIPA(0),		-- FF/REW start
		FLATCH => PPIPC(5),		-- FF/REW latch
		WREADY => PPIPB(4),		-- Write enable
		TREADY => PPIPB(5),		-- Tape exist
		RDATA => PPIPB(6),		-- to 8255
		-- Status Signal
		SCLK => CK3125,			-- Slow Clock(31.25kHz)
		MZMODE => MZMODE,
		DMODE => DMODE
	);

	PIT0 : i8253 port map (
		RST => ZRST,
		CLK => CK4M,
		A => ZADDR(1 downto 0),
		DI => ZDTO,
		DO => DOPIT,
		CS => CSE4_x,
		WR => WR_x,
		RD => RD_x,
		CLK0 => CK3125,
		GATE0 => RST8253_x,
		OUT0 => CASCADE01,
		CLK1 => CASCADE01,
		GATE1 => RST8253_x,
		OUT1 => CASCADE12,
		CLK2 => CASCADE12,
		GATE2 => '1',
		OUT2 => open
	);

	PIO0 : z8420 port map (
		-- System
		RST => ZRST,								-- Only Power On Reset
		-- Z80 Bus Signals
		CLK => CK4M,
		BASEL => ZADDR(1),
		CDSEL => ZADDR(0),
		CE => CSE8_x,
		RD_x => RD_x,
		WR_x => WR_x,
		IORQ_x => IORQ_x,
		M1_x => M1,
		DI => ZDTO,
		DO => DOPIO,
		IEI => '1',
		IEO => open,
--		INT_x => open,
		INT_x => INT_x,
		-- Port
		A => PIOPA,
		B => PIOPB,
		-- for Debug
		LDDAT => open
--		LDDAT2 : out std_logic;
--		LDSNS  : out std_logic;
	);

	KEY0 : keymatrix port map (
		-- i8255/PIO
		ZRST_x => ZRST,
		STROBE => PIOPA(3 downto 0),
		STALL => PIOPA(4),
		KDATA => PIOPB,
		-- PS/2 Keyboard Data
		KCLK => CK4M,							-- Key controller base clock
		KBEN => KBEN,							-- PS/2 Keyboard Data Valid
		KBDT => KBDT,							-- PS/2 Keyboard Data
		-- for Debug
		LDDAT => LDDAT,
		-- Avalon Bus
		RRST_x => RRST_x,			-- NiosII Reset
		RCLK => RCLK,				-- NiosII Clock
		RADR => RADR,				-- NiosII Address Bus
		RCS_x => RCS_x,				-- NiosII Read Signal
		RWE_x => RWE_x,				-- NiosII Write Signal
		RDI => RDI,					-- NiosII Data Bus(in)
		RDO => DO_KMTX				-- NiosII Data Bus(out)
	);

	PS2RCV : ps2kb port map (
		RST => ARST,
		KCLK => CK4M,
		PS2CK => PS2_KBCLK,
		PS2DT => PS2_KBDAT,
		DTEN => KBEN,
		DATA => KBDT
	);

	VIDEO0 : videoout Port map (
		RST => ZRST,				-- Reset
		MZMODE => MZMODE,			-- Hardware Mode
		DMODE => DMODE,			-- Display Mode
		-- Clocks
		CK50M => CLOCK_50,		-- Master Clock(50MHz)
		CK25M => CK25M,			-- VGA Clock(25MHz)
		CK16M => CK16M,			-- 15.6kHz Dot Clock(16MHz)
		CK4M => CK4M,				-- CPU/CLOCK Clock(4MHz)
		CK3125 => CK3125,			-- Time Base Clock(31.25kHz)
		-- CPU Signals
		A => ZADDR(13 downto 0),-- CPU Address Bus
		CSV_x => CSV_x,			-- CPU Memory Request(VRAM)
		CSG_x => CSG_x,			-- CPU Memory Request(GRAM)
		RD_x => RD_x,				-- CPU Read Signal
		WR_x => WR_x,				-- CPU Write Signal
		MREQ_x => MREQ_x,			-- CPU Memory Request
		IORQ_x => IORQ_x,			-- CPU I/O Request
		WAIT_x => ZWAIT_x,		-- CPU Wait Request
		DI => ZDTO,					-- CPU Data Bus(in)
		DO => VRAMDO,				-- CPU Data Bus(out)
		-- Graphic VRAM Access
		GCS_x =>	GCS_x,			-- GRAM Request
		GADR => GADR,				-- GRAM Address
		GWR_x => GWR_x,			-- GRAM Write Signal
		GBE_x => GBE_x,			-- GRAM Byte Enable
		GDI => GDI,					-- Data Bus Input from GRAM
		GDO => GDO,					-- Data Bus Output to GRAM
		-- Video Control from outside
		INV => PPIPA(4),			-- Reverse mode(8255 PA4)
		VGATE => PPIPC(0),		-- Video Output Control
		CH80 => PIOPA(5),
		-- Video Signals
		--HBLANK => HBLNK,			-- Horizontal Blanking
		VBLANK => PPIPB(0),		-- Vertical Blanking
		HSYNC => HSYNCi,			-- Horizontal Sync
		VSYNC => VSYNC,			-- Vertical Sync
		ROUT => Ri,					-- Red Output
		GOUT => Gi,					-- Green Output
		BOUT => Bi,					-- Blue Output
		-- Avalon Bus
		RRST_x => RRST_x,			-- NiosII Reset
		RCLK => RCLK,				-- NiosII Clock
		RADR => RADR,				-- NiosII Address Bus
		RCS_x => RCS_x,			-- NiosII Read Signal
		RWE_x => RWE_x,			-- NiosII Write Signal
		RDI => RDI,					-- NiosII Data Bus(in)
		RDO => DO_VOUT,			-- NiosII Data Bus(out)
		-- Control Signal
		BOOTM => BOOTM,			-- BOOT Mode
		BACK => BAK_x				-- Z80 Bus Acknowlegde
	);

	SCONV0 : ScanConv Port map (
		CK16M => CK16M,		-- MZ Dot Clock
		CK25M => CK25M,		-- VGA Dot Clock
		RI => Ri,				-- Red Input
		GI => Gi,				-- Green Input
		BI => Bi,				-- Blue Input
		HSI => HSYNCi,			-- H-Sync Input(MZ,15.6kHz)
		RO => R,					-- Red Output
		GO => G,					-- Green Output
		BO => B,					-- Blue Output
		HSO => HSYNC			-- H-Sync Output(VGA, 31kHz)
	);

	CTRL0 : sysctrl port map (
		-- Avalon Bus
		RRST_x => RRST_x,			-- NiosII Reset
		RCLK => RCLK,				-- NiosII Clock
		RADR => RADR,				-- NiosII Address Bus
		RCS_x => RCS_x,			-- NiosII Read Signal
		RWE_x => RWE_x,			-- NiosII Write Signal
		RDI => RDI,					-- NiosII Data Bus(in)
		RDO => DO_CTRL,			-- NiosII Data Bus(out)
		-- Push Button
		BUTTON => BUTTON,			--	Pushbutton[2:0]
		-- Switch
		SW => SW,					--	Toggle Switch[9:0]
		-- PS/2 Keyboard Data
		KBEN => KBEN,				-- PS/2 Keyboard Data Valid
		KBDT => KBDT,				-- PS/2 Keyboard Data
		-- Interrupt
		INTL => INTL,				-- Interrupt Signal Output
		I_CMT => I_CMT,			-- from CMT
		I_FDD => I_FDD,			-- from FD unit
		-- Others
		URST_x => URST_x,			-- Universal Reset
		MRST_x => MRST_x,			-- Reset after SDRAM init.
		ARST_x => ARST,			-- All Reset
		ZRST => ZRST,				-- Z80 Reset
		CLK50 => CLOCK_50,		-- 50MkHz
		SCLK => CK3125,			-- 31.25kHz
		ZBREQ => BREQ_x,			-- Z80 Bus Request
		ZBACK => BAK_x,			-- Z80 Bus Acknowridge
		BST_x => BST_x,			-- BOOT start request from Z80
		BOOTM => BOOTM,			-- BOOT mode
		F_BTN	=> F_BTN				-- Function Button
  );

	FDIF0 : mz1e05 Port map(
		-- CPU Signals
		ZRST_x => ZRST,
		ZCLK => CK4M,
		ZADR => ZADDR(7 downto 0),		-- CPU Address Bus(lower)
		ZRD_x => RD_x,						-- CPU Read Signal
		ZWR_x => WR_x,						-- CPU Write Signal
		ZIORQ_x => IORQ_x,				-- CPU I/O Request
		ZDI => ZDTO,						-- CPU Data Bus(in)
		ZDO => DOFDC,						-- CPU Data Bus(out)
		SCLK => CK3125,					-- Slow Clock
		-- FD signals
		DS_x => DS,							-- Drive Select
		HS => HS,							-- Head Select
		MOTOR_x => MOTOR_x,				-- Motor On
		INDEX_x => INDEX_x,				-- Index Hole Detect
		TRACK00 => TRACK00_x,			-- Track 0
		WPRT_x => WPRT_x,					-- Write Protect
		STEP_x => STEP_x,					-- Head Step In/Out
		DIREC => DIREC,					-- Head Step Direction
		WGATE_x => WGATE_x,				-- Write Gate
		DTCLK => DTCLK,					-- Data Clock
		FDI => FDI,							-- Read Data
		FDO => FDO							-- Write Data
	);

	FDU0 : fdunit Port map(
		-- Avalon Bus
		RRST_x => RRST_x,					-- NiosII Reset
		RCLK => RCLK,						-- NiosII Clock
		RADR => RADR,						-- NiosII Address Bus
		RCS_x => RCS_x,					-- NiosII Read Signal
		RWE_x => RWE_x,					-- NiosII Write Signal
		RDI => RDI,							-- NiosII Data Bus(in)
		RDO => DO_FDU,						-- NiosII Data Bus(out)
		-- Interrupt
		INTO => I_FDD,						-- Step Pulse interrupt
		-- FD signals
		FCLK => CK4M,
		DS_x => DS,							-- Drive Select
		HS => HS,							-- Head Select
		MOTOR_x => MOTOR_x,				-- Motor On
		INDEX_x => INDEX_x,				-- Index Hole Detect
		TRACK00 => TRACK00_x,			-- Track 0
		WPRT_x => WPRT_x,					-- Write Protect
		STEP_x => STEP_x,					-- Head Step In/Out
		DIREC => DIREC,					-- Head Step Direction
		WG_x => WGATE_x,					-- Write Gate
		DTCLK => DTCLK,					-- Data Clock
		FDO => FDI,							-- Read Data
		FDI => FDO,							-- Write Data
		-- LED
		LEDG => F_LEDG,					--	LED Green[9:0]
		SCLK => CK3125,					-- Slow Clock
		-- Buffer RAM I/F
		BCS_x => BCS_x,					-- RAM Request
		BADR => BADR,						-- RAM Address
		BWR_x => BWR_x,				 	-- RAM Write Signal
		BDI => BDI,							-- Data Bus Input from RAM
		BDO => BDO							-- Data Bus Output to RAM
	);

	--
	-- Control Signals
	--
	IWR<=IORQ_x or WR_x;

	--
	-- Data Bus
	--
	ZDTI<=DOPPI or DOPIT or DOPIO or VRAMDO or RAMDI or DOFDC;
	RAMDI<=ZDI when RD_x='0' and MREQ_x='0' and CSV_x='1' and CSG_x='1' else (others=>'0');
--			  HSKDI when CSHSK='0' else ZDI;

	--
	-- Chip Select
	--
	CSV_x<='0' when MZMODE='0' and PIOPA(7)='1' and ZADDR(15 downto 12)="1101" and MREQ_x='0' and PIOPA(6)='0' else			-- $D000 - $DFFF (80B)
			 '0' when MZMODE='0' and PIOPA(7)='1' and ZADDR(15 downto 12)="0101" and MREQ_x='0' and PIOPA(6)='1' else 			-- $5000 - $5FFF (80B)
			 '0' when MZMODE='1' and PIOPA(7)='1' and ZADDR(15 downto 12)="1101" and MREQ_x='0' and PIOPA(6)='1' else '1';		-- $D000 - $DFFF (2000)
	CSG_x<='0' when MZMODE='0' and PIOPA(7)='1' and ZADDR(15 downto 13)="111" and MREQ_x='0' and PIOPA(6)='0' else 			-- $E000 - $FFFF (80B)
			 '0' when MZMODE='0' and PIOPA(7)='1' and ZADDR(15 downto 13)="011" and MREQ_x='0' and PIOPA(6)='1' else 			-- $6000 - $7FFF (80B)
			 '0' when MZMODE='1' and PIOPA(7)='1' and ZADDR(15 downto 14)="11" and MREQ_x='0' and PIOPA(6)='0' else '1';		-- $C000 - $FFFF (2000)
	CSHSK<='0' when ZADDR(7 downto 3)="10001" and IORQ_x='0' else '1';		-- HandShake Port
	CSE0_x<='0' when ZADDR(7 downto 2)="111000" and IORQ_x='0' else '1';		-- 8255
	CSE4_x<='0' when ZADDR(7 downto 2)="111001" and IORQ_x='0' else '1';		-- 8253
	CSE8_x<='0' when ZADDR(7 downto 2)="111010" and IORQ_x='0' else '1';		-- PIO

	--
	-- Video Output
	--
	VGA_HS<=HSYNC;
	VGA_VS<=VSYNC;
	VGA_R<=R&R&R&R;
	VGA_G<=G&G&G&G;
	VGA_B<=B&B&B&B;

	--
	-- Ports
	--
	RDO<=DO_CMT or DO_CTRL or DO_VOUT or DO_KMTX or DO_FDU;
	ZADR<="1111110"&ZADDR;	-- 0x7E0000
	ZPG_x<=BAK_x and ZRST;
	ZCS_x<=MREQ_x when CSV_x='1' and CSG_x='1' and RFSH_x='1' else '1';
	ZDO<=ZDTO;
	ZWR_x<=WR_x;
	ARST_x<=ARST;

	--
	-- Misc
	--
	MZMODE<=SW(9);
	DMODE<=SW(8);

	RST8253_x<='0' when ZADDR(7 downto 2)="111100" and IWR='0' else '1';

	GPIO1_D(31 downto 16)<=(others=>'0');
	GPIO1_D(15)<=PPIPC(2);	-- Sound Output
	GPIO1_D(14)<=PPIPC(2);
	GPIO1_D(13 downto 0)<=(others=>'0');
	GPIO0_CLKOUT<=(others=>'0');
	GPIO0_D<=(others=>'0');
	GPIO1_CLKOUT<=(others=>'0');

	LEDG(9 downto 7)<=(others=>'0');
	LEDG(6 downto 5)<=F_LEDG(6 downto 5);
	LEDG(4)<='0';
	LEDG(3)<=C_LEDG(3);
	LEDG(2)<=PPIPA(5) when MZMODE='0' else '0';	-- SFTLOCK
	LEDG(1)<=PPIPA(6) when MZMODE='0' else '0';	-- GRAPH
	LEDG(0)<=PPIPA(7) when MZMODE='0' else '0';	-- KANA

end rtl;
