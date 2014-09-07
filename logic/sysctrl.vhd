--
-- sysctrl.vhd
--
-- SHARP MZ-80B/2000 series compatible logic, system control module
-- for Altera DE0
--
-- Nibbles Lab. 2014
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity sysctrl is
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
		-- Others
		URST_x : out std_logic;								-- Universal Reset
		MRST_x : in std_logic;								-- Reset after SDRAM init.
		ARST_x : out std_logic;								-- All Reset
		ZRST	 : out std_logic;								-- Z80 Reset
		CLK50	 : in std_logic;								-- 50MkHz
		SCLK	 : in std_logic;								-- 31.25kHz
		ZBREQ	 : out std_logic;								-- Z80 Bus Request
		ZBACK	 : in std_logic;								-- Z80 Bus Acknowridge
		BOOTM	 : out std_logic;								-- BOOT mode
		F_BTN	 : out std_logic								-- Function Button
  );
end sysctrl;

architecture rtl of sysctrl is

--
-- Reset & Filters
--
signal URSTi : std_logic;		-- Universal Reset
signal FRST : std_logic;
signal BUF : std_logic_vector(7 downto 0) := "00000000";
signal CNT5 : std_logic_vector(4 downto 0);
signal SR_BTN : std_logic_vector(7 downto 0);
signal ZR_BTN : std_logic_vector(7 downto 0);
signal FR_BTN : std_logic_vector(7 downto 0);
signal F_BTNi : std_logic;
--
-- Interrupt
--
signal IRQ_KB : std_logic;
signal IE_KB : std_logic;
signal IKBBUF : std_logic_vector(2 downto 0);
signal IRQ_FB : std_logic;
signal IE_FB : std_logic;
signal IFBBUF : std_logic_vector(2 downto 0);
signal IRQ_CT : std_logic;
signal IE_CT : std_logic;
signal ICTBUF : std_logic_vector(2 downto 0);
--
-- Control for Z80
--
signal ZRSTi : std_logic;
signal BOOTMi : std_logic := '1';

begin

	--
	-- Avalon Bus
	--
	process( RRST_x, RCLK ) begin
		if RRST_x='0' then
			IRQ_KB<='0';
			IRQ_FB<='0';
			IRQ_CT<='0';
			IE_KB<='0';
			IE_FB<='0';
			IE_CT<='0';
			ZBREQ<='1';
			BOOTMi<='1';
			ZRSTi<='0';
		elsif RCLK'event and RCLK='1' then
			-- Edge Sense
			IKBBUF<=IKBBUF(1 downto 0)&(KBEN and ((not ZBACK) or BOOTMi));
			if IKBBUF(2 downto 1)="01" then
				IRQ_KB<=IE_KB;
			end if;
			IFBBUF<=IFBBUF(1 downto 0)&F_BTNi;
			if IFBBUF(2 downto 1)="01" then
				IRQ_FB<=IE_FB;
			end if;
			ICTBUF<=ICTBUF(1 downto 0)&I_CMT;
			if ICTBUF(2 downto 1)="01" then
				IRQ_CT<=IE_CT;
			end if;
			-- Register
			if RCS_x='0' and RWE_x='0' then
				if RADR=X"0005" then	-- MZ_SYS_IREQ
					IRQ_KB<=IRQ_KB and (not RDI(0));
					IRQ_FB<=IRQ_FB and (not RDI(1));
					IRQ_CT<=IRQ_CT and (not RDI(2));
				end if;
				if RADR=X"0006" then	-- MZ_SYS_IENB
					IE_KB<=RDI(0);
					IE_FB<=RDI(1);
					IE_CT<=RDI(2);
				end if;
				if RADR=X"0007" then	-- MZ_SYS_CTRL (Control for Z80)
					ZBREQ<=RDI(0);
					ZRSTi<=RDI(1);
					BOOTMi<=RDI(2);
				end if;
			end if;
		end if;
	end process;

	RDO<="00000"&BUTTON					 when RCS_x='0' and RADR=X"0000" else	-- MZ_SYS_BUTTON
		  SW(7 downto 0)					 when RCS_x='0' and RADR=X"0002" else	-- MZ_SYS_SW70
		  "000000"&SW(9)&SW(8)			 when RCS_x='0' and RADR=X"0003" else	-- MZ_SYS_SW98
		  KBDT								 when RCS_x='0' and RADR=X"0004" else	-- MZ_SYS_KBDT
		  "00000"&IRQ_CT&IRQ_FB&IRQ_KB when RCS_x='0' and RADR=X"0005" else	-- MZ_SYS_IREQ
		  "00000"&IE_CT&IE_FB&IE_KB	 when RCS_x='0' and RADR=X"0006" else	-- MZ_SYS_IENB
		  "0000000"&ZBACK					 when RCS_x='0' and RADR=X"0007" else	-- MZ_SYS_STATUS
		  "00000000";

	INTL<=IRQ_KB or IRQ_FB or IRQ_CT;

	--
	-- Filter and Asynchronous Reset with automatic
	--
	URST_x<=URSTi;
	process( CLK50 ) begin
		if( CLK50'event and CLK50='1' ) then
			if BUF=X"80" then
				URSTi<='1';
			else
				BUF<=BUF+'1';
				URSTi<='0';
			end if;
		end if;
	end process;

	process( URSTi, SCLK ) begin
		if URSTi='0' then
			CNT5<=(others=>'0');
			SR_BTN<=(others=>'1');
			ZR_BTN<=(others=>'1');
			FR_BTN<=(others=>'0');
		elsif SCLK'event and SCLK='1' then
			if CNT5="11111" then
				SR_BTN<=SR_BTN(6 downto 0)&(BUTTON(1) or (not BUTTON(0)));	-- only BUTTON1
				ZR_BTN<=ZR_BTN(6 downto 0)&((not BUTTON(1)) or BUTTON(0));	-- only BUTTON0
				FR_BTN<=FR_BTN(6 downto 0)&(BUTTON(1) or BUTTON(0));			-- both 0&1
				CNT5<=(others=>'0');
			else
				CNT5<=CNT5+'1';
			end if;
		end if;
	end process;
	F_BTNi<='1' when SR_BTN="00000000" else '0';
	F_BTN<=F_BTNi;
	FRST<='0' when FR_BTN="00000000" else '1';
	ARST_x<=URSTi and FRST and MRST_x;
	ZRST<='0' when (ZR_BTN="00000000" and ZBACK='1') or ZRSTi='0' or URSTi='0' else '1';

	BOOTM<=BOOTMi;

end rtl;

