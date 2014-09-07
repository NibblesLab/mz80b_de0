--
-- videoout.vhd
--
-- Video display signal generator
-- for MZ-80B on FPGA
--
-- Nibbles Lab. 2013-2014
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity videoout is
	Port (
		RST    : in std_logic;		-- Reset
		MZMODE : in std_logic;		-- Hardware Mode
		DMODE  : in std_logic;		-- Display Mode
		-- Clocks
		CK50M  : in std_logic;		-- Master Clock(50MHz)
		CK25M  : out std_logic;		-- VGA Clock(25MHz)
		CK16M  : out std_logic;		-- 15.6kHz Dot Clock(16MHz)
		CK4M   : out std_logic;		-- CPU/CLOCK Clock(4MHz)
		CK3125 : out std_logic;		-- Music Base Clock(31.25kHz)
--		CK16Mi  : in std_logic;		-- 15.6kHz Dot Clock(16MHz)
--		CK4Mi   : in std_logic;		-- CPU/CLOCK Clock(4MHz)
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
		BOUT   : out std_logic;		-- Blue Output
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
end videoout;

architecture RTL of videoout is

--
-- Clocks
--
signal CK16Mi  : std_logic;	-- 8MHz
signal CK4Mi   : std_logic;	-- 2MHz
--
-- Registers
--
signal DIV      : std_logic_vector(8 downto 0);		-- Clock Divider
signal HCOUNT   : std_logic_vector(9 downto 0);		-- Counter for Horizontal Signals
signal VCOUNT   : std_logic_vector(8 downto 0);		-- Counter for Vertical Signals
signal VADR     : std_logic_vector(10 downto 0);	-- VRAM Address(selected)
signal VADRC    : std_logic_vector(10 downto 0);	-- VRAM Address
signal GADRC    : std_logic_vector(13 downto 0);	-- GRAM Address
signal GADRi    : std_logic_vector(13 downto 0);	-- GRAM Address(for GRAM Access)
signal VADRL    : std_logic_vector(10 downto 0);	-- VRAM Address(latched)
signal SDAT     : std_logic_vector(7 downto 0);		-- Shift Register to Display
signal SDATB    : std_logic_vector(7 downto 0);		-- Shift Register to Display
signal SDATR    : std_logic_vector(7 downto 0);		-- Shift Register to Display
signal SDATG    : std_logic_vector(7 downto 0);		-- Shift Register to Display
signal S2DAT    : std_logic_vector(7 downto 0);		-- Shift Register to Display(for 40-char)
signal S2DAT0   : std_logic_vector(7 downto 0);		-- Shift Register to Display(for 80B)
signal S2DAT1   : std_logic_vector(7 downto 0);		-- Shift Register to Display(for 80B)
--
-- CPU Access
--
signal MA       : std_logic_vector(11 downto 0);	-- Masked Address
signal CSB4_x   : std_logic;								-- Chip Select (PIO-3039 Color Board)
signal CSF4_x   : std_logic;								-- Chip Select (Background Color)
signal CSF5_x   : std_logic;								-- Chip Select (Display Select for C-Monitor)
signal CSF6_x   : std_logic;								-- Chip Select (Display Select for G-Monitor)
signal CSF7_x   : std_logic;								-- Chip Select (GRAM Select)
signal GCSi_x   : std_logic;								-- Chip Select (GRAM)
signal RCSV		 : std_logic;								-- Chip Select (VRAM, NiosII)
signal RCSC		 : std_logic;								-- Chip Select (CGROM, NiosII)
signal VWEN     : std_logic;								-- WR + MREQ (VRAM)
signal RVWEN	 : std_logic;								-- WR + CS (VRAM, NiosII)
signal RCWEN	 : std_logic;								-- WR + CS (CGROM, NiosII)
signal RDOi		 : std_logic_vector(7 downto 0);		-- Internal Data Bus (VRAM, NiosII)
signal WAITi_x  : std_logic;								-- Wait
signal WAITii_x : std_logic;								-- Wait(delayed)
signal ZGBE_x   : std_logic_vector(3 downto 0);		-- Byte Enable by Z80 access
--
-- Internal Signals
--
signal HDISPEN : std_logic;							-- Display Enable for Horizontal, almost same as HBLANK
signal HBLANKi : std_logic;							-- Horizontal Blanking
signal BLNK		: std_logic;							-- Horizontal Blanking (for wait)
signal XBLNK	: std_logic;							-- Horizontal Blanking (for wait)
signal VDISPEN : std_logic;							-- Display Enable for Vertical, same as VBLANK
signal MB		: std_logic;							-- Display Signal (Mono, Blue)
signal MG		: std_logic;							-- Display Signal (Mono, Green)
signal MR		: std_logic;							-- Display Signal (Mono, Red)
signal BB		: std_logic;							-- Display Signal (Color, Blue)
signal BG		: std_logic;							-- Display Signal (Color, Green)
signal BR		: std_logic;							-- Display Signal (Color, Red)
signal PBGR		: std_logic_vector(2 downto 0);	-- Display Signal (Color)
signal POUT		: std_logic_vector(2 downto 0);	-- Display Signal (Color)
signal VRAMDO  : std_logic_vector(7 downto 0);	-- Data Bus Output for VRAM
signal DCODE   : std_logic_vector(7 downto 0);	-- Display Code, Read From VRAM
signal CGDAT   : std_logic_vector(7 downto 0);	-- Font Data To Display
signal CGADR   : std_logic_vector(10 downto 0);	-- Font Address To Display
signal CCOL    : std_logic_vector(2 downto 0);	-- Character Color
signal BCOL    : std_logic_vector(2 downto 0);	-- Background Color
signal CCOLi   : std_logic_vector(2 downto 0);	-- Character Color(reg)
signal BCOLi   : std_logic_vector(2 downto 0);	-- Background Color(reg)
signal GPRI    : std_logic;
signal GPAGE   : std_logic_vector(2 downto 0);
signal GPAGEi  : std_logic_vector(2 downto 0);
signal GDISPEN : std_logic;
signal GDISPENi : std_logic;
signal GBANK   : std_logic_vector(1 downto 0);
signal INVi    : std_logic;
signal VGATEi  : std_logic;
signal GRAMBDI : std_logic_vector(7 downto 0);	-- Data from GRAM(Blue)
signal GRAMRDI : std_logic_vector(7 downto 0);	-- Data from GRAM(Red)
signal GRAMGDI : std_logic_vector(7 downto 0);	-- Data from GRAM(Green)
signal CH80i   : std_logic;
signal CDISPEN : std_logic;
signal PALET0 : std_logic_vector(2 downto 0);
signal PALET1 : std_logic_vector(2 downto 0);
signal PALET2 : std_logic_vector(2 downto 0);
signal PALET3 : std_logic_vector(2 downto 0);
signal PALET4 : std_logic_vector(2 downto 0);
signal PALET5 : std_logic_vector(2 downto 0);
signal PALET6 : std_logic_vector(2 downto 0);
signal PALET7 : std_logic_vector(2 downto 0);

--
-- Components
--
component cgrom
	PORT
	(
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		rdclock		: IN STD_LOGIC ;
		wraddress		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		wrclock		: IN STD_LOGIC  := '1';
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
end component;

component dpram2k
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		clock_a		: IN STD_LOGIC  := '1';
		clock_b		: IN STD_LOGIC ;
		data_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		q_a		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
end component;

component pll50
	PORT
	(
		inclk0	: IN STD_LOGIC  := '0';
		c0			: OUT STD_LOGIC ;
		c1			: OUT STD_LOGIC ;
		c2			: OUT STD_LOGIC ;
		c3			: OUT STD_LOGIC 
	);
end component;

begin

	--
	-- Instantiation
	--
	VRAM0 : dpram2k PORT MAP (
		address_a	 => VADR,
		address_b	 => RADR(10 downto 0),
		clock_a	 => CK16Mi,
		clock_b	 => RCLK,
		data_a	 => DI,
		data_b	 => RDI,
		wren_a	 => VWEN,
		wren_b	 => RVWEN,
		q_a	 => VRAMDO,
		q_b	 => RDOi
	);

	CGROM0 : cgrom PORT MAP (
		data	 => RDI,
		rdaddress	 => CGADR,
		rdclock	 => CK16Mi,
		wraddress	 => RADR(10 downto 0),
		wrclock	 => RCLK,
		wren	 => RCWEN,
		q	 => CGDAT
	);

	--
	-- Clock Generator
	--
	VCKGEN : pll50 PORT MAP (
			inclk0	 => CK50M,
			c0	 => CK25M,
			c1	 => CK16Mi,
			c2	 => CK4Mi,
			c3	 => CK3125);

	--
	-- Blank & Sync Generation
	--
	process( RRST_x, CK16Mi ) begin

		if RRST_x='0' then
			HCOUNT<="1111111000";
			HBLANKi<='0';
			HDISPEN<='0';
			BLNK<='0';
			HSYNC<='1';
			VDISPEN<='1';
			VSYNC<='1';
			GCSi_x<='1';
			VADRC<=(others=>'0');
			GADRC<=(others=>'0');
			VADRL<=(others=>'0');
		elsif CK16Mi'event and CK16Mi='1' then

			-- Counters
			if HCOUNT=1015 then
				--HCOUNT<=(others=>'0');
				HCOUNT<="1111111000";
				VADRC<=VADRL;				-- Return to Most-Left-Column Address
				if VCOUNT=259 then
					VCOUNT<=(others=>'0');
					VADRC<=(others=>'0');	-- Home Position
					GADRC<=(others=>'0');	-- Home Position
					VADRL<=(others=>'0');
				else
					VCOUNT<=VCOUNT+'1';
				end if;
			else
				HCOUNT<=HCOUNT+'1';
			end if;

			-- Horizontal Signals Decode
			if HCOUNT=0 then
				HDISPEN<=VDISPEN;		-- if V-DISP is Enable then H-DISP Start
			elsif HCOUNT=632 then
				HBLANKi<='1';			-- H-Blank Start
				BLNK<='1';
			elsif HCOUNT=640 then
				HDISPEN<='0';			-- H-DISP End
			elsif HCOUNT=768 then
				HSYNC<='0';				-- H-Sync Pulse Start
			elsif HCOUNT=774 and VCOUNT(2 downto 0)="111" then
				VADRL<=VADRC;			-- Save Most-Left-Column Address
			elsif HCOUNT=859 then
				HSYNC<='1';				-- H-Sync Pulse End
			elsif HCOUNT=992 then
				BLNK<='0';
			elsif HCOUNT=1015 then
				HBLANKi<='0';			-- H-Blank End
			end if;

			-- VRAM Address counter(per 8dot)
			if HBLANKi='0' then
				if (HCOUNT(2 downto 0)="111" and CH80i='1') or (HCOUNT(3 downto 0)="1111" and CH80i='0') then
					VADRC<=VADRC+'1';
				end if;
				if (HCOUNT(2 downto 0)="111" and MZMODE='1') or (HCOUNT(3 downto 0)="1111" and MZMODE='0') then
					GADRC<=GADRC+'1';
				end if;
			end if;

			-- Graphics VRAM Access signal
			if HBLANKi='0' then
				if (HCOUNT(2 downto 0)="000" and MZMODE='1') or (HCOUNT(3 downto 0)="1000" and MZMODE='0') then
				  GCSi_x<='0';
				elsif (HCOUNT(2 downto 0)="111" and MZMODE='1') or (HCOUNT(3 downto 0)="1111" and MZMODE='0') then
				  GCSi_x<='1';
				end if;
			else
				GCSi_x<='1';
			end if;

			-- Get Font/Pattern data and Shift
			if HCOUNT(3 downto 0)="0000" then
				if CH80i='1' then
					SDAT<=CGDAT;
				else
					SDAT<=CGDAT(7)&CGDAT(7)&CGDAT(6)&CGDAT(6)&CGDAT(5)&CGDAT(5)&CGDAT(4)&CGDAT(4);
					S2DAT<=CGDAT(3)&CGDAT(3)&CGDAT(2)&CGDAT(2)&CGDAT(1)&CGDAT(1)&CGDAT(0)&CGDAT(0);
				end if;
				if MZMODE='1' then
					SDATB<=GRAMBDI;
					SDATR<=GRAMRDI;
					SDATG<=GRAMGDI;
				else
					SDATB<=GRAMBDI(3)&GRAMBDI(3)&GRAMBDI(2)&GRAMBDI(2)&GRAMBDI(1)&GRAMBDI(1)&GRAMBDI(0)&GRAMBDI(0);
					S2DAT0<=GRAMBDI(7)&GRAMBDI(7)&GRAMBDI(6)&GRAMBDI(6)&GRAMBDI(5)&GRAMBDI(5)&GRAMBDI(4)&GRAMBDI(4);
					SDATR<=GRAMRDI(3)&GRAMRDI(3)&GRAMRDI(2)&GRAMRDI(2)&GRAMRDI(1)&GRAMRDI(1)&GRAMRDI(0)&GRAMRDI(0);
					S2DAT1<=GRAMRDI(7)&GRAMRDI(7)&GRAMRDI(6)&GRAMRDI(6)&GRAMRDI(5)&GRAMRDI(5)&GRAMRDI(4)&GRAMRDI(4);
				end if;
			elsif HCOUNT(3 downto 0)="1000" then
				if CH80i='1' then
					SDAT<=CGDAT;
				else
					SDAT<=S2DAT;
				end if;
				if MZMODE='1' then
					SDATB<=GRAMBDI;
					SDATR<=GRAMRDI;
					SDATG<=GRAMGDI;
				else
					SDATB<=S2DAT0;
					SDATR<=S2DAT1;
				end if;
			else
				SDAT<=SDAT(6 downto 0)&'0';
				SDATB<='0'&SDATB(7 downto 1);
				SDATR<='0'&SDATR(7 downto 1);
				SDATG<='0'&SDATG(7 downto 1);
			end if;

			-- Vertical Signals Decode
			if VCOUNT=0 then
				VDISPEN<='1';			-- V-DISP Start
			elsif VCOUNT=200 then
				VDISPEN<='0';			-- V-DISP End
			elsif VCOUNT=219 then
				VSYNC<='0';				-- V-Sync Pulse Start
			elsif VCOUNT=223 then
				VSYNC<='1';				-- V-Sync Pulse End
			end if;

		end if;

	end process;

	--
	-- Control Registers
	--
	process( RST, CK4Mi ) begin
		if RST='0' then
			BCOLi<=(others=>'0');
			CCOLi<=(others=>'1');
			GPRI<='0';
			GPAGEi<="000";
			GDISPENi<='0';
			CDISPEN<='1';
			GBANK<="00";
			PALET0<="000";
			PALET1<="111";
			PALET2<="111";
			PALET3<="111";
			PALET4<="111";
			PALET5<="111";
			PALET6<="111";
			PALET7<="111";
		elsif CK4Mi'event and CK4Mi='0' then
			if WR_x='0' then
				if MZMODE='1' then		-- MZ-2000
					-- Background Color
					if CSF4_x='0' then
						BCOLi<=DI(2 downto 0);
					end if;
					-- Character Color and Priority
					if CSF5_x='0' then
						CCOLi<=DI(2 downto 0);
						GPRI<=DI(3);
					end if;
					-- Display Graphics and Pages
					if CSF6_x='0' then
						GPAGEi<=DI(2 downto 0);
						GDISPENi<=not DI(3);
					end if;
					-- Select Accessable Graphic Banks
					if CSF7_x='0' then
						GBANK<=DI(1 downto 0);
					end if;
				else							-- MZ-80B
					-- Color Control(PIO-3039)
					if CSB4_x='0' then
						if DI(6)='1' then
							CDISPEN<=DI(7);
						else
							case DI(2 downto 0) is
								when "000" => PALET0<=DI(5 downto 3);
								when "001" => PALET1<=DI(5 downto 3);
								when "010" => PALET2<=DI(5 downto 3);
								when "011" => PALET3<=DI(5 downto 3);
								when "100" => PALET4<=DI(5 downto 3);
								when "101" => PALET5<=DI(5 downto 3);
								when "110" => PALET6<=DI(5 downto 3);
								when "111" => PALET7<=DI(5 downto 3);
								when others => PALET0<=DI(5 downto 3);
							end case;
						end if;
					end if;
					-- Select Accessable Graphic Banks and Outpu Pages
					if CSF4_x='0' then
						GBANK<=DI(0)&(not DI(0));
						GPAGEi(1 downto 0)<=DI(2 downto 1);
					end if;
				end if;
			end if;
		end if;
	end process;

	--
	-- Timing Conditioning and Wait
	--
	process( MREQ_x ) begin
		if MREQ_x'event and MREQ_x='0' then
			XBLNK<=BLNK;
		end if;
	end process;

	process( CK4Mi ) begin
		if CK4Mi'event and CK4Mi='1' then
			WAITii_x<=WAITi_x;
		end if;
	end process;
	WAITi_x<='0' when (CSV_x='0' or CSG_x='0') and XBLNK='0' and BLNK='0' else '1';
	WAIT_x<=WAITi_x and WAITii_x;

	--
	-- Mask by Mode
	--
	ZGBE_x<="1110" when GBANK="01" else
			  "1101" when GBANK="10" else
			  "1011" when GBANK="11" else "1111";
	GBE_x<=ZGBE_x when BLNK='1' else "1000";
	GWR_x<=WR_x when BLNK='1' else '1';
	GCS_x<=CSG_x when BLNK='1' else GCSi_x;
	RCSV<='0' when RCS_x='0' and RADR(15 downto 11)="11010" else '1';
	RCSC<='0' when RCS_x='0' and RADR(15 downto 11)="11001" else '1';
	VWEN<='1' when WR_x='0' and CSV_x='0' and BLNK='1' else '0';
	RVWEN<=not(RWE_x or RCSV);
	RCWEN<=not(RWE_x or RCSC);
	CSB4_x<='0' when A(7 downto 0)=X"B4" and IORQ_x='0' else '1';
	CSF4_x<='0' when A(7 downto 0)=X"F4" and IORQ_x='0' else '1';
	CSF5_x<='0' when A(7 downto 0)=X"F5" and IORQ_x='0' else '1';
	CSF6_x<='0' when A(7 downto 0)=X"F6" and IORQ_x='0' else '1';
	CSF7_x<='0' when A(7 downto 0)=X"F7" and IORQ_x='0' else '1';
	CCOL<=CCOLi when BACK='1' else "111";
	BCOL<=BCOLi when BACK='1' else "000";
	INVi<=INV when BOOTM='0' and BACK='1' else '1';
	VGATEi<=VGATE when BOOTM='0' and BACK='1' else '0';
	GPAGE<=GPAGEi when BOOTM='0' and BACK='1' else "000";
	GDISPEN<='0' when BOOTM='1' or BACK='0' else
				'1' when MZMODE='0' else GDISPENi;
	CH80i<=CH80 when BOOTM='0' and BACK='1' else '0';

	--
	-- Bus Select
	--
	VADR<=A(10 downto 0) when CSV_x='0' and BLNK='1' else VADRC;
	GADRi<=A(13 downto 0) when CSG_x='0' and BLNK='1' and MZMODE='1' else
			 '0'&A(12 downto 0) when CSG_x='0' and BLNK='1' and MZMODE='0' else GADRC;
	GADR<="1111101"&GADRi;	-- 0x7D0000
	DCODE<=DI when CSV_x='0' and BLNK='1' and WR_x='0' else VRAMDO;
	DO<=VRAMDO when RD_x='0' and CSV_x='0' else
		 GDI(7 downto 0) when RD_x='0' and CSG_x='0' and GBANK="01" else
		 GDI(15 downto 8) when RD_x='0' and CSG_x='0' and GBANK="10" else
		 GDI(23 downto 16) when RD_x='0' and CSG_x='0' and GBANK="11" else (others=>'0');
	CGADR<=DCODE&VCOUNT(2 downto 0);
	GRAMBDI<=GDI(7 downto 0) when GPAGE(0)='1' else (others=>'0');
	GRAMRDI<=GDI(15 downto 8) when GPAGE(1)='1' else (others=>'0');
	GRAMGDI<=GDI(23 downto 16) when GPAGE(2)='1' else (others=>'0');
	GDO<="00000000"&DI&DI&DI;

	--
	-- Color Decode
	--
	-- Monoclome Monitor
--	MB<=SDAT(7) when HDISPEN='1' and VGATEi='0' else '0';
--	MR<=SDAT(7) when HDISPEN='1' and VGATEi='0' else '0';
	MB<='0';
	MR<='0';
	MG<=not (SDAT(7) or (GDISPEN and (SDATB(0) or SDATR(0) or SDATG(0)))) when HDISPEN='1' and VGATEi='0' and INVi='0' else
		 SDAT(7) or (GDISPEN and (SDATB(0) or SDATR(0) or SDATG(0))) when HDISPEN='1' and VGATEi='0' and INVi='1' else '0';
	-- Color Monitor(MZ-2000)
	process( HDISPEN, VGATEi, GPRI, SDAT(7), SDATB(0), SDATR(0), SDATG(0), CCOL, BCOL ) begin
		if HDISPEN='1' and VGATEi='0' then
			if SDAT(7)='0' and SDATB(0)='0' then
				BB<=BCOL(0);
			else
				if GPRI='0' then
					if SDAT(7)='1' then
						BB<=CCOL(0);
					else
						BB<='1';	-- SDATB(0)='1'
					end if;
				else 	--GPRI='1'
					if SDATB(0)='1' then
						BB<='1';
					else
						BB<=CCOL(0);	-- SDAT(7)='1'
					end if;
				end if;
			end if;
			if SDAT(7)='0' and SDATR(0)='0' then
				BR<=BCOL(1);
			else
				if GPRI='0' then
					if SDAT(7)='1' then
						BR<=CCOL(1);
					else
						BR<='1';	-- SDATR(0)='1'
					end if;
				else	--GPRI='1' then
					if SDATR(0)='1' then
						BR<='1';
					else
						BR<=CCOL(1);	-- SDAT(7)='1'
					end if;
				end if;
			end if;
			if SDAT(7)='0' and SDATG(0)='0' then
				BG<=BCOL(2);
			else
				if GPRI='0' then
					if SDAT(7)='1' then
						BG<=CCOL(2);
					else
						BG<='1';	-- SDATG(0)='1'
					end if;
				else	--GPRI='1' then
					if SDATG(0)='1' then
						BG<='1';
					else
						BG<=CCOL(2);	-- SDAT(7)='1'
					end if;
				end if;
			end if;
		else
			BB<='0';
			BR<='0';
			BG<='0';
		end if;
	end process;
	-- Color Monitor(PIO-3039)
	POUT<=(SDAT(7) and CDISPEN)&SDATR(0)&SDATB(0);
	process(POUT, PALET0, PALET1, PALET2, PALET3, PALET4, PALET5, PALET6, PALET7) begin
		case POUT is
			when "000" => PBGR<=PALET0;
			when "001" => PBGR<=PALET1;
			when "010" => PBGR<=PALET2;
			when "011" => PBGR<=PALET3;
			when "100" => PBGR<=PALET4;
			when "101" => PBGR<=PALET5;
			when "110" => PBGR<=PALET6;
			when "111" => PBGR<=PALET7;
			when others => PBGR<=PALET7;
		end case;
	end process;

	--
	-- Output
	--
	CK16M<=CK16Mi;
	CK4M<=CK4Mi;
	VBLANK<=VDISPEN;
	--HBLANK<=HBLANKi;
	ROUT<=MR when DMODE='0' or BOOTM='1' or BACK='0' else
			BR when DMODE='1' and MZMODE='1' else PBGR(0);
	GOUT<=MG when DMODE='0' or BOOTM='1' or BACK='0' else
			BG when DMODE='1' and MZMODE='1' else PBGR(1);
	BOUT<=MB when DMODE='0' or BOOTM='1' or BACK='0' else
			BB when DMODE='1' and MZMODE='1' else PBGR(2);
	RDO<=RDOi when RADR(15 downto 11)="11010" and RCS_x='0' else (others=>'0');

end RTL;
