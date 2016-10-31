--------------------------------------------------------------------------
-- package com tipos basicos
--------------------------------------------------------------------------
library IEEE;
use IEEE.Std_Logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.conv_std_logic_vector;

package PhoenixPackage is

-----------------------------------------------------------------------
-- OCP PARAMETERS
-----------------------------------------------------------------------

------------------ command Enconding - p. 13 ---------------------------
    constant IDLE: Std_Logic_Vector(2 downto 0) :="000";
    constant WR:   Std_Logic_Vector(2 downto 0) :="001";
    constant RD:   Std_Logic_Vector(2 downto 0) :="010";
    constant RDEX: Std_Logic_Vector(2 downto 0) :="011";
    constant BCST: Std_Logic_Vector(2 downto 0) :="111";
-----------------------Response Enconding------------------------------
    constant DVA:  Std_Logic_Vector(1 downto 0) :="01";
    constant ERR:  Std_Logic_Vector(1 downto 0) :="11";
    constant NULO: Std_Logic_Vector(1 downto 0) :="00";
    constant ALVO: Std_Logic_Vector(7 downto 0) :="00000000";

---------------------------------------------------------
-- CONSTANTS INDEPENDENTES
---------------------------------------------------------
    constant CLOCK_PERIOD : time := 20 ns;

    constant NPORT: integer := 5;

    constant EAST  : integer := 0;
    constant WEST  : integer := 1;
    constant NORTH : integer := 2;
    constant SOUTH : integer := 3;
    constant LOCAL : integer := 4;
---------------------------------------------------------
-- CONSTANT DEPENDENTE DA LARGURA DE BANDA DA REDE
---------------------------------------------------------
    constant TAM_FLIT : integer range 1 to 64 := 16;
    constant METADEFLIT : integer range 1 to 32 := (TAM_FLIT/2);
    constant QUARTOFLIT : integer range 1 to 16 := (TAM_FLIT/4);
---------------------------------------------------------
-- CONSTANTS DEPENDENTES DA PROFUNDIDADE DA FILA
---------------------------------------------------------
    constant TAM_BUFFER: integer := 16;
    constant TAM_POINTER : integer range 1 to 32 := 5;

---------------------------------------------------------
-- CONSTANTS DEPENDENTES DO NUMERO DE ROTEADORES
---------------------------------------------------------
    constant NUM_X : integer := 5;
    constant NUM_Y : integer := 5;

    constant NROT: integer := NUM_X*NUM_Y;

    constant MIN_X : integer := 0;
    constant MIN_Y : integer := 0;
    constant MAX_X : integer := NUM_X-1;
    constant MAX_Y : integer := NUM_Y-1;

---------------------------------------------------------
-- CONSTANT TB
---------------------------------------------------------
    constant TAM_LINHA : integer := 500;

---------------------------------------------------------
-- VARIAVEIS DO NOVO HARDWARE
---------------------------------------------------------
    subtype reg21 is std_logic_vector(20 downto 0);
    type buffControl is array(0 to 4) of std_logic_vector((TAM_FLIT-1) downto 0);
    type RouterControl is (invalidRegion, validRegion, faultPort, portError);
    type ArrayRouterControl is array(NPORT downto 0) of RouterControl;

    constant c_WR_ROUT_TAB : integer := 1;
    constant c_WR_FAULT_TAB : integer := 2;
    constant c_RD_FAULT_TAB_STEP1 : integer := 3;
    constant c_RD_FAULT_TAB_STEP2 : integer := 4;
    constant c_TEST_LINKS : integer := 5;

---------------------------------------------------------
-- SUBTIPOS, TIPOS E FUNCOES
---------------------------------------------------------

    subtype reg3 is std_logic_vector(2 downto 0);
    subtype reg8 is std_logic_vector(7 downto 0);
    subtype reg32 is std_logic_vector(31 downto 0);
    subtype regNrot is std_logic_vector((NROT-1) downto 0);
    subtype regNport is std_logic_vector((NPORT-1) downto 0);
    subtype regflit is std_logic_vector((TAM_FLIT-1) downto 0);
    subtype regmetadeflit is std_logic_vector(((TAM_FLIT/2)-1) downto 0);
    subtype regquartoflit is std_logic_vector((QUARTOFLIT-1) downto 0);
    subtype pointer is std_logic_vector((TAM_POINTER-1) downto 0);

    type buff is array(0 to TAM_BUFFER-1) of regflit;

    type arrayNport_reg3 is array((NPORT-1) downto 0) of reg3;
    type arrayNport_reg8 is array((NPORT-1) downto 0) of reg8;
    type arrayNport_regflit is array((NPORT-1) downto 0) of regflit;
    type arrayNrot_reg3 is array((NROT-1) downto 0) of reg3;
    type arrayNrot_regflit is array((NROT-1) downto 0) of regflit;
    type arrayNrot_regmetadeflit is array((NROT-1) downto 0) of regmetadeflit;
    type arrayNrot_regNport is array((NROT-1) downto 0) of regNport;

    function CONV_VECTOR( int: integer ) return std_logic_vector;

    type arrayRegNport is array ((NPORT-1) downto 0) of regNport;

    type routingTable is array(0 to MAX_X, 0 to MAX_Y) of std_logic_vector(NPORT-1 downto 0);

---------------------------------------------------------
-- FUNCOES TB
---------------------------------------------------------
    function CONV_VECTOR( letra : string(1 to TAM_LINHA);  pos: integer ) return std_logic_vector;
    function CONV_HEX( int : integer ) return string;
    function CONV_STRING_4BITS( dado : std_logic_vector(3 downto 0)) return string;
    function CONV_STRING_8BITS( dado : std_logic_vector(7 downto 0)) return string;
    function CONV_STRING_16BITS( dado : std_logic_vector(15 downto 0)) return string;
    function CONV_STRING_32BITS( dado : std_logic_vector(31 downto 0)) return string;
    function INDEX_FROM_ADDRESS (address: std_logic_vector) return integer;
    function to_hstring(value: std_logic_vector) return string;
    function PORT_NAME(value: integer) return string;
    function ADDRESS_FROM_INDEX(index : integer) return regflit;
    function OR_REDUCTION(arrayN : std_logic_vector ) return boolean;

end PhoenixPackage;

package body PhoenixPackage is

    --
    -- dado o index do roteador retorna o endereço correspondente
    --
    function ADDRESS_FROM_INDEX( index: integer) return regflit is
        variable addrX, addrY: regmetadeflit;
        variable addr: regflit;
    begin
        addrX := CONV_STD_LOGIC_VECTOR(index/NUM_Y, METADEFLIT);
        addrY := CONV_STD_LOGIC_VECTOR(index mod NUM_Y, METADEFLIT);
        addr := addrX & addrY;
        return addr;
    end ADDRESS_FROM_INDEX;
       
    function INDEX_FROM_ADDRESS (address: std_logic_vector) return integer is
        variable number: integer := 0;
        alias addrX is address(TAM_FLIT-1 downto METADEFLIT);
        alias addrY is address(METADEFLIT-1 downto 0);
        variable X : integer := CONV_INTEGER(addrX);
        variable Y : integer := CONV_INTEGER(addrY);
    begin
        number := X*NUM_Y + Y;
        return number;
    end INDEX_FROM_ADDRESS;
    --
    -- converte um inteiro em um std_logic_vector(2 downto 0)
    --
    function CONV_VECTOR( int: integer ) return std_logic_vector is
        variable bin: reg3;
    begin
        case(int) is
            when 0 => bin := "000";
            when 1 => bin := "001";
            when 2 => bin := "010";
            when 3 => bin := "011";
            when 4 => bin := "100";
            when 5 => bin := "101";
            when 6 => bin := "110";
            when 7 => bin := "111";
            when others => bin := "000";
        end case;
        return bin;
    end CONV_VECTOR;
    ---------------------------------------------------------
    -- FUNCOES TB
    ---------------------------------------------------------
    --
    -- converte um caracter de uma dada linha em um std_logic_vector
    --
    function CONV_VECTOR( letra:string(1 to TAM_LINHA);  pos: integer ) return std_logic_vector is
        variable bin: std_logic_vector(3 downto 0);
    begin
        case (letra(pos)) is
            when '0' => bin := "0000";
            when '1' => bin := "0001";
            when '2' => bin := "0010";
            when '3' => bin := "0011";
            when '4' => bin := "0100";
            when '5' => bin := "0101";
            when '6' => bin := "0110";
            when '7' => bin := "0111";
            when '8' => bin := "1000";
            when '9' => bin := "1001";
            when 'A' => bin := "1010";
            when 'B' => bin := "1011";
            when 'C' => bin := "1100";
            when 'D' => bin := "1101";
            when 'E' => bin := "1110";
            when 'F' => bin := "1111";
            when others =>  bin := "0000";
        end case;
        return bin;
    end CONV_VECTOR;

-- converte um inteiro em um string
    function CONV_HEX( int: integer ) return string is
        variable str: string(1 to 1);
    begin
        case(int) is
            when 0 => str := "0";
            when 1 => str := "1";
            when 2 => str := "2";
            when 3 => str := "3";
            when 4 => str := "4";
            when 5 => str := "5";
            when 6 => str := "6";
            when 7 => str := "7";
            when 8 => str := "8";
            when 9 => str := "9";
            when 10 => str := "A";
            when 11 => str := "B";
            when 12 => str := "C";
            when 13 => str := "D";
            when 14 => str := "E";
            when 15 => str := "F";
            when others =>  str := "U";
        end case;
        return str;
    end CONV_HEX;

    function CONV_STRING_4BITS(dado : std_logic_vector(3 downto 0)) return string is
        variable str: string(1 to 1);
    begin
        str := CONV_HEX(CONV_INTEGER(dado));
        return str;
    end CONV_STRING_4BITS;

    function CONV_STRING_8BITS(dado : std_logic_vector(7 downto 0)) return string is
        variable str1,str2: string(1 to 1);
        variable str: string(1 to 2);
    begin
        str1 := CONV_STRING_4BITS(dado(7 downto 4));
        str2 := CONV_STRING_4BITS(dado(3 downto 0));
        str := str1 & str2;
        return str;
    end CONV_STRING_8BITS;

    function CONV_STRING_16BITS(dado : std_logic_vector(15 downto 0)) return string is
        variable str1,str2: string(1 to 2);
        variable str: string(1 to 4);
    begin
        str1 := CONV_STRING_8BITS(dado(15 downto 8));
        str2 := CONV_STRING_8BITS(dado(7 downto 0));
        str := str1 & str2;
        return str;
    end CONV_STRING_16BITS;

    function CONV_STRING_32BITS(dado : std_logic_vector(31 downto 0)) return string is
        variable str1,str2: string(1 to 4);
        variable str: string(1 to 8);
    begin
        str1 := CONV_STRING_16BITS(dado(31 downto 16));
        str2 := CONV_STRING_16BITS(dado(15 downto 0));
        str := str1 & str2;
        return str;
    end CONV_STRING_32BITS;

  -- converte hexa para string
    function to_hstring (value     : STD_LOGIC_VECTOR) return STRING is
        constant ne     : INTEGER := (value'length+3)/4;                    -- numero minimo de blocos de 4 bits (truncado)
        variable pad    : STD_LOGIC_VECTOR(0 to (ne*4 - value'length) - 1); -- valores finais, no caso do value nao ser multiplo de 4
        variable ivalue : STD_LOGIC_VECTOR(0 to ne*4 - 1);                  -- o valor em si.
        variable result : STRING(1 to ne);                                  -- blocos de 4 bits
        variable quad   : STD_LOGIC_VECTOR(0 to 3);                         -- um bloco.
    begin
        if value'length < 1 then
            return result;
        else
            if value (value'left) = 'Z' then
                pad := (others => 'Z');
            else
                pad := (others => '0');
            end if;
            ivalue := pad & value;

            for i in 0 to ne-1 loop
                quad := To_X01Z(ivalue(4*i to 4*i+3));
                case quad is
                    when x"0"   => result(i+1) := '0';
                    when x"1"   => result(i+1) := '1';
                    when x"2"   => result(i+1) := '2';
                    when x"3"   => result(i+1) := '3';
                    when x"4"   => result(i+1) := '4';
                    when x"5"   => result(i+1) := '5';
                    when x"6"   => result(i+1) := '6';
                    when x"7"   => result(i+1) := '7';
                    when x"8"   => result(i+1) := '8';
                    when x"9"   => result(i+1) := '9';
                    when x"A"   => result(i+1) := 'A';
                    when x"B"   => result(i+1) := 'B';
                    when x"C"   => result(i+1) := 'C';
                    when x"D"   => result(i+1) := 'D';
                    when x"E"   => result(i+1) := 'E';
                    when x"F"   => result(i+1) := 'F';
                    when "ZZZZ" => result(i+1) := 'Z';
                    when others => result(i+1) := 'X';
                end case;
            end loop;
            return result;
        end if;
    end function to_hstring;

    function PORT_NAME(value: integer) return string is
        variable str: string (1 to 8);
    begin
        case value is
            when EAST   => str(1 to 4) := "EAST";
            when WEST   => str(1 to 4) := "WEST";
            when NORTH  => str(1 to 5) := "NORTH";
            when SOUTH  => str(1 to 5) := "SOUTH";
            when LOCAL  => str(1 to 5) := "LOCAL";
            when others => str(1 to 7) := "INVALID";
        end case;
        return str;
    end function PORT_NAME;
    --
    -- Do a OR operation between all elements in an array
    --
    function OR_REDUCTION( arrayN: in std_logic_vector ) return boolean is
    begin
        return arrayN /= 0;
    end OR_REDUCTION;
end PhoenixPackage;