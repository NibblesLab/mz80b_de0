--
-- counter1.vhd
--
-- Intel 8253 counter module for #1
-- for MZ-80B/2000 on FPGA
--
-- Count only mode 2 with Counter read out
--
-- Nibbles Lab. 2005-2014
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity counter1 is
	Port (
		DI : in std_logic_vector(7 downto 0);
		DO : out std_logic_vector(7 downto 0);
		WRD : in std_logic;
		WRM : in std_logic;
		KCLK : in std_logic;
		RD : in std_logic;
		CLK : in std_logic;
		GATE : in std_logic;
		POUT : out std_logic
	);
end counter1;

architecture Behavioral of counter1 is

--
-- counter
--
signal CREG : std_logic_vector(15 downto 0);
--
-- initialize
--
signal INIV : std_logic_vector(15 downto 0) := (others=>'0');
signal RL : std_logic_vector(1 downto 0);
signal PO : std_logic;
signal WUL : std_logic;
signal WULi : std_logic;
signal RUL : std_logic;
signal NEWM : std_logic;
--
-- count control
--
signal CD : std_logic_vector(15 downto 0);
signal DTEN : std_logic;
signal CEN : std_logic;

begin

	--
	-- Counter control
	--
	process( KCLK ) begin
		if KCLK'event and KCLK='0' then
			if WRM='0' then
				if DI(5 downto 4)="00" then
					CD<=CREG;
				else
					RL<=DI(5 downto 4);
					NEWM<='1';
					WUL<='0';
					WULi<='0';
				end if;
			end if;
			if WRD='0' then
				case RL is
					when "01" =>
						INIV(7 downto 0)<=DI;
						NEWM<='0';
					when "10" =>
						INIV(15 downto 8)<=DI;
						NEWM<='0';
					when "11" =>
						if WUL='0' then
							INIV(7 downto 0)<=DI;
							WULi<='1';
						else
							INIV(15 downto 8)<=DI;
							WULi<='0';
							NEWM<='0';
						end if;
					when others =>
						NEWM<='0';
				end case;
			end if;
			WUL<=WULi;
		end if;
	end process;

	--
	-- Read control
	--
	process( RD, WRM, DI(5 downto 4) ) begin
		if WRM='0' then
			if DI(5 downto 4)="00" then
				DTEN<='1';
			else
				RUL<='0';
			end if;
		elsif RD'event and RD='1' then
			RUL<=not RUL;
			if DTEN='1' and RUL='1' then
				DTEN<='0';
			end if;
		end if;
	end process;

	DO<=CD(7 downto 0)	  when RUL='0' and DTEN='1' else
	    CD(15 downto 8)	  when RUL='1' and DTEN='1' else
	    CREG(7 downto 0)  when RUL='0' and DTEN='0' else
	    CREG(15 downto 8) when RUL='1' and DTEN='0' else (others=>'1');

	--
	-- Count enable
	--
	CEN<='1' when NEWM='0' and GATE='1' else '0';

	--
	-- Count (mode 2)
	--
	process( CLK, GATE, INIV ) begin
		if GATE='0' then
			CREG<=INIV;
			PO<='1';
		elsif CLK'event and CLK='0' then
			if WRM='0' then
				PO<='1';
			elsif CREG="0000000000000010" then
				PO<='0';
			else
				PO<='1';
			end if;
			if CREG="0000000000000001" then
				CREG<=INIV;
			elsif CEN='1' then
				CREG<=CREG-'1';
			end if;
		end if;
	end process;

	POUT<=PO when GATE='1' else '1';

end Behavioral;
