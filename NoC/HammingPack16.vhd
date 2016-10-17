library ieee;
use ieee.std_logic_1164.all;
use work.PhoenixPackage.all;

package HammingPack16 is

	--define sizes and types
	--constant TAM_FLIT : integer range 1 to 64 := 16;
	constant TAM_HAMM : integer range 1 to 64 := 6;
	constant TAM_PHIT : integer range 1 to 64 := TAM_FLIT + TAM_HAMM;

	constant HAMM_NPORT: integer := 4; -- 4 portas (EAST,WEST,NORTH,SOUTH)
	constant COUNTERS_SIZE: integer := 5; -- 5 bits cada contador

	subtype reghamm is std_logic_vector((TAM_HAMM-1) downto 0);
	subtype regphit is std_logic_vector((TAM_PHIT-1) downto 0);
	subtype regHamm_Nport is std_logic_vector((HAMM_NPORT-1) downto 0);

	subtype row_FaultTable is std_logic_vector((3*COUNTERS_SIZE+1) downto 0);
	type row_FaultTable_Ports is array ((HAMM_NPORT-1) downto 0) of row_FaultTable;
	type row_FaultTable_Nport_Ports is array ((NPORT-1) downto 0) of row_FaultTable_Ports;

	type array_statusHamming is array ((HAMM_NPORT-1) downto 0) of reg3;
	type arrayNport_regphit is array ((NPORT-1) downto 0) of regphit;
	type arrayNrot_regphit is array ((NROT-1) downto 0) of regphit;
    type matrixNrot_Nport_regphit is array((NROT-1) downto 0) of arrayNport_regphit; -- a -- array(NROT)(NPORT)(TAM_FLIT)
	type arrayNport_reghamm is array((NPORT-1) downto 0) of reghamm;
	type arrayNrot_reghamm is array((NROT-1) downto 0) of reghamm;
	type matrixNrot_Nport_reghamm is array((NROT-1) downto 0) of arrayNport_reghamm; -- a -- array(NROT)(NPORT)(TAM_FLIT)

	--define maks to select bits to xor for each parity
	constant MaskP1  : std_logic_vector(15 downto 0) := "1010110101011011";
	constant MaskP2  : std_logic_vector(15 downto 0) := "0011011001101101";								
	constant MaskP4  : std_logic_vector(15 downto 0) := "1100011110001110";
	constant MaskP8  : std_logic_vector(15 downto 0) := "0000011111110000";  
	constant MaskP16 : std_logic_vector(15 downto 0) := "1111100000000000";  	
	
   	constant NE: std_logic_vector (2 downto 0) := "101"; -- no error 
   	constant EC: std_logic_vector (2 downto 0) := "011"; -- error corrected
   	constant ED: std_logic_vector (2 downto 0) := "111"; -- error detected
   	constant BF: std_logic_vector (2 downto 0) := "000"; -- "stand by" or buffer full

	--function to exclusive-OR all the bits in a std_logic_vector
	function xor_reduce(arg : std_logic_vector) return std_logic;
	
end HammingPack16;	

package body HammingPack16 is

	--function to exclusive-OR all the bits in a std_logic_vector
	function xor_reduce(arg : std_logic_vector) return std_logic is
		variable result : std_logic;
	begin                   
		result := '0';
		for b in arg'range loop
			result := result xor arg(b);
		end loop;
		return result;
	end function xor_reduce;
	
end HammingPack16;	