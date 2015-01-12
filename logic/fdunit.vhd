--
-- fdunit.vhd
--
-- Floppy Disk Drive Unit Emulation module
-- for MZ-80B/2000 on FPGA
--
-- Nibbles Lab. 2014
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity fdunit is
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
end fdunit;

architecture RTL of fdunit is
--
-- Floppy Signals
--
signal RDO0 : std_logic_vector(7 downto 0);
signal RDO1 : std_logic_vector(7 downto 0);
signal IDX_0 : std_logic;
signal IDX_1 : std_logic;
signal TRK00_0 : std_logic;
signal TRK00_1 : std_logic;
signal WPRT_0 : std_logic;
signal WPRT_1 : std_logic;
signal FDO0 : std_logic_vector(7 downto 0);
signal FDO1 : std_logic_vector(7 downto 0);
signal DTCLK0 : std_logic;
signal DTCLK1 : std_logic;
--
-- Indicator
--
signal LEDG1 : std_logic;
signal LEDG0 : std_logic;
--
-- Control
--
signal INT0 : std_logic;
signal INT1 : std_logic;
--
-- Memory Access
--
signal BCS0_x : std_logic;
signal BCS1_x : std_logic;
signal BADR0 : std_logic_vector(22 downto 0);
signal BADR1 : std_logic_vector(22 downto 0);
signal BWR0_x : std_logic;
signal BWR1_x : std_logic;
signal BDO0 : std_logic_vector(7 downto 0);
signal BDO1 : std_logic_vector(7 downto 0);
--
-- Component
--
component fd55b
	generic
	(
		DS_SW : std_logic_vector(4 downto 1) := "1111";
		REG_ADDR : std_logic_vector(15 downto 0) := "0000000000000000"
	);
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
		LEDG	  : out std_logic;							--	LED Green
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

	FDD0 : fd55b generic map (
		DS_SW => "1110",
		REG_ADDR => X"0040"
	)
	Port map (
		-- Avalon Bus
		RRST_x => RRST_x,			-- NiosII Reset
		RCLK => RCLK,				-- NiosII Clock
		RADR => RADR,				-- NiosII Address Bus
		RCS_x => RCS_x,			-- NiosII Read Signal
		RWE_x => RWE_x,			-- NiosII Write Signal
		RDI => RDI,					-- NiosII Data Bus(in)
		RDO => RDO0,				-- NiosII Data Bus(out)
		-- Interrupt
		INTO => INT0,				-- Step Pulse interrupt
		-- FD signals
		FCLK => FCLK,
		DS_x => DS_x,				-- Drive Select
		HS => HS,					-- Head Select
		MOTOR_x => MOTOR_x,		-- Motor On
		INDEX_x => IDX_0,			-- Index Hole Detect
		TRACK00 => TRK00_0,		-- Track 0
		WPRT_x => WPRT_0,			-- Write Protect
		STEP_x => STEP_x,			-- Head Step In/Out
		DIREC => DIREC,			-- Head Step Direction
		WG_x => WG_x,				-- Write Gate
		DTCLK => DTCLK0,			-- Data Clock
		FDI => FDI,					-- Write Data
		FDO => FDO0,				-- Read Data
		-- LED
		LEDG => LEDG0,				--	LED Green[9:0]
		SCLK => SCLK,				-- Slow Clock
		-- Buffer RAM I/F
		BCS_x => BCS0_x,			-- RAM Request
		BADR => BADR0,				-- RAM Address
		BWR_x => BWR0_x,			-- RAM Write Signal
		BDI => BDI,					-- Data Bus Input from RAM
		BDO => BDO0					-- Data Bus Output to RAM
	);

	FDD1 : fd55b generic map (
		DS_SW => "1101",
		REG_ADDR => X"0050"
	)
	Port map (
		-- Avalon Bus
		RRST_x => RRST_x,			-- NiosII Reset
		RCLK => RCLK,				-- NiosII Clock
		RADR => RADR,				-- NiosII Address Bus
		RCS_x => RCS_x,			-- NiosII Read Signal
		RWE_x => RWE_x,			-- NiosII Write Signal
		RDI => RDI,					-- NiosII Data Bus(in)
		RDO => RDO1,				-- NiosII Data Bus(out)
		-- Interrupt
		INTO => INT1,				-- Step Pulse interrupt
		-- FD signals
		FCLK => FCLK,
		DS_x => DS_x,				-- Drive Select
		HS => HS,					-- Head Select
		MOTOR_x => MOTOR_x,		-- Motor On
		INDEX_x => IDX_1,			-- Index Hole Detect
		TRACK00 => TRK00_1,		-- Track 0
		WPRT_x => WPRT_1,			-- Write Protect
		STEP_x => STEP_x,			-- Head Step In/Out
		DIREC => DIREC,			-- Head Step Direction
		WG_x => WG_x,				-- Write Gate
		DTCLK => DTCLK1,			-- Data Clock
		FDI => FDI,					-- Write Data
		FDO => FDO1,				-- Read Data
		-- LED
		LEDG => LEDG1,				--	LED Green[9:0]
		SCLK => SCLK,				-- Slow Clock
		-- Buffer RAM I/F
		BCS_x => BCS1_x,			-- RAM Request
		BADR => BADR1,				-- RAM Address
		BWR_x => BWR1_x,			-- RAM Write Signal
		BDI => BDI,					-- Data Bus Input from RAM
		BDO => BDO1					-- Data Bus Output to RAM
	);

	INDEX_x<=IDX_0 and IDX_1;
	TRACK00<=TRK00_0 and TRK00_1;
	WPRT_x<=WPRT_0 and WPRT_1;
	FDO<=FDO0 or FDO1;
	DTCLK<=DTCLK0 or DTCLK1;
	LEDG<="000"&LEDG1&LEDG0&"00000";
	BCS_x<=BCS0_x and BCS1_x;
	BADR<=BADR0 or BADR1;
	BWR_x<=BWR0_x and BWR1_x;
	BDO<=BDO0 or BDO1;

	RDO<=RDO0 or RDO1;
	INTO<=INT0 or INT1;

end RTL;
