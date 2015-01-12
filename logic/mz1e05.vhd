--
-- mz1e05.vhd
--
-- Floppy Disk Interface Emulation module
-- for MZ-80B/2000 on FPGA
--
-- Nibbles Lab. 2014
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity mz1e05 is
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
end mz1e05;

architecture RTL of mz1e05 is
--
-- Signals
--
signal CSFDC_x : std_logic;
signal CSDC : std_logic;
signal CSDD : std_logic;
signal CSDE : std_logic;
signal DDEN : std_logic;
signal READY : std_logic;
signal STEP : std_logic;
signal DIRC : std_logic;
signal WG : std_logic;
signal RCOUNT : std_logic_vector(12 downto 0);
--
-- Component
--
component mb8876
	Port (
		-- CPU Signals
		ZCLK	  : in std_logic;
		MR_x	  : in std_logic;
		A		  : in std_logic_vector(1 downto 0);	-- CPU Address Bus
		RE_x	  : in std_logic;								-- CPU Read Signal
		WE_x	  : in std_logic;								-- CPU Write Signal
		CS_x	  : in std_logic;								-- CPU Chip Select
		DALI_x  : in std_logic_vector(7 downto 0);	-- CPU Data Bus(in)
		DALO_x  : out std_logic_vector(7 downto 0);	-- CPU Data Bus(out)
--		DALI	  : in std_logic_vector(7 downto 0);	-- CPU Data Bus(in)
--		DALO	  : out std_logic_vector(7 downto 0);	-- CPU Data Bus(out)
		-- FD signals
		DDEN_x  : in std_logic;								-- Double Density
		IP_x	  : in std_logic;								-- Index Pulse
		READY	  : in std_logic;								-- Drive Ready
		TR00_x  : in std_logic;								-- Track 0
		WPRT_x  : in std_logic;								-- Write Protect
		STEP	  : out std_logic;							-- Head Step In/Out
		DIRC	  : out std_logic;							-- Head Step Direction
		WG		  : out std_logic;							-- Write Gate
		DTCLK	  : in std_logic;								-- Data Clock
		FDI	  : in std_logic_vector(7 downto 0);	-- Read Data
		FDO	  : out std_logic_vector(7 downto 0)	-- Write Data
	);
end component;

begin

	--
	-- Instantiation
	--
	FDC0 : mb8876 Port map(
		-- CPU Signals
		ZCLK => ZCLK,
		MR_x => ZRST_x,
		A => ZADR(1 downto 0),		-- CPU Address Bus
		RE_x => ZRD_x,					-- CPU Read Signal
		WE_x => ZWR_x,					-- CPU Write Signal
		CS_x => CSFDC_x,				-- CPU Chip Select
		DALI_x => ZDI,					-- CPU Data Bus(in)
		DALO_x => ZDO,					-- CPU Data Bus(out)
--		DALI => ZDI,					-- CPU Data Bus(in)
--		DALO => ZDO,					-- CPU Data Bus(out)
		-- FD signals
		DDEN_x => DDEN,				-- Double Density
		IP_x => INDEX_x,				-- Index Pulse
		READY => READY,				-- Drive Ready
		TR00_x => TRACK00,			-- Track 0
		WPRT_x => WPRT_x,				-- Write Protect
		STEP => STEP,					-- Head Step In/Out
		DIRC => DIRC,					-- Head Step Direction
		WG => WG,						-- Write Gate
		DTCLK => DTCLK,				-- Data Clock
		FDI => FDI,						-- Read Data
		FDO => FDO						-- Write Data
	);

	--
	-- Registers
	--
	process( ZRST_x, ZCLK ) begin
		if ZRST_x='0' then
			MOTOR_x<='1';
			HS<='0';
			DS_x<="1111";
			DDEN<='0';
		elsif ZCLK'event and ZCLK='0' then
			if ZWR_x='0' then
				if CSDC='1' then
					MOTOR_x<=not ZDI(7);
					case ZDI(2 downto 0) is
						when "100" => DS_x<="1110";
						when "101" => DS_x<="1101";
						when "110" => DS_x<="1011";
						when "111" => DS_x<="0111";
						when others => DS_x<="1111";
					end case;
				end if;
				if CSDD='1' then
					HS<=not ZDI(0);
				end if;
				if CSDE='1' then
					DDEN<=ZDI(0);
				end if;
			end if;
		end if;
	end process;

	CSFDC_x<='0' when ZIORQ_x='0' and ZADR(7 downto 2)="110110" else '1';
	CSDC<='1' when ZIORQ_x='0' and ZADR=X"DC" else '0';
	CSDD<='1' when ZIORQ_x='0' and ZADR=X"DD" else '0';
	CSDE<='1' when ZIORQ_x='0' and ZADR=X"DE" else '0';

	--
	-- Ready Signal
	--
	process( ZRST_x, SCLK ) begin
		if ZRST_x='0' then
			RCOUNT<=(others=>'0');
			READY<='0';
		elsif SCLK'event and SCLK='0' then
			if INDEX_x='0' then
				RCOUNT<=(others=>'1');
			else
				if RCOUNT="0000000000000" then
					READY<='0';
				else
					RCOUNT<=RCOUNT-'1';
					READY<='1';
				end if;
			end if;
		end if;
	end process;

	--
	-- FDC signals
	--
	STEP_x<=not STEP;
	DIREC<=not DIRC;
	WGATE_x<=not WG;

end RTL;
