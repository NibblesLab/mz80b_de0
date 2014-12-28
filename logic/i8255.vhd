--
-- i8255.vhd
--
-- Intel 8255 (PPI:Programmable Peripheral Interface) partiality compatible module
-- for MZ-80B on FPGA
--
-- Port A : Output, mode 0 only
-- Port B : Input, mode 0 only
-- Port C : Output, mode 0 only, bit set/reset support
--
-- Nibbles Lab. 2005-2014
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity i8255 is
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
end i8255;

architecture Behavioral of i8255 is

--
-- Port Register
--
signal PAi : std_logic_vector(7 downto 0);
--signal PBi : std_logic_vector(7 downto 0);
signal PCi : std_logic_vector(7 downto 0);
--
-- Port Selecter
--
signal SELPA : std_logic;
signal SELPB : std_logic;
signal SELPC : std_logic;
signal SELCT : std_logic;

--
-- Components
--

begin

	--
	-- Port select for Output
	--
	SELPA<='1' when A="00" else '0';
	SELPB<='1' when A="01" else '0';
	SELPC<='1' when A="10" else '0';
	SELCT<='1' when A="11" else '0';

	--
	-- Output
	--
	process( RST, CLK, MZMODE ) begin
		if RST='0' then
			if MZMODE='0' then
				PAi<=X"10";
			else
				PAi<=X"FF";
			end if;
--			PBi<=(others=>'0');
			PCi<=X"58";
		elsif CLK'event and CLK='0' then
			if CS='0' and WR='0' then
				if SELPA='1' then
					PAi<=DI;
				end if;
--				if SELPB='1' then
--					PBi<=DI;
--				end if;
				if SELPC='1' then
					PCi<=DI;
				end if;
				if SELCT='1' and DI(7)='0' then
					case DI(3 downto 1) is
						when "000" => PCi(0)<=DI(0);
						when "001" => PCi(1)<=DI(0);
						when "010" => PCi(2)<=DI(0);
						when "011" => PCi(3)<=DI(0);
						when "100" => PCi(4)<=DI(0);
						when "101" => PCi(5)<=DI(0);
						when "110" => PCi(6)<=DI(0);
						when "111" => PCi(7)<=DI(0);
						when others => PCi<="XXXXXXXX";
					end case;
				end if;
			end if;
		end if;
	end process;

	PA<=PAi;
--	PB<=PBi;
	PC<=PCi;

	--
	-- Input select
	--
	DO<=PAi when RD='0' and CS='0' and SELPA='1' else
		 PB  when RD='0' and CS='0' and SELPB='1' else
		 PCi when RD='0' and CS='0' and SELPC='1' else (others=>'0');

--	LDDAT<=TBLNK&"0000000";

end Behavioral;
