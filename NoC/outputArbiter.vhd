library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.PhoenixPackage.all;

entity outputArbiter is
port(
    freePort : in regNport;
    enable : in std_logic;
    enablePort : in regNport;
    isOutputSelected : out std_logic;
    selectedOutput : out integer
);
end;

architecture outputArbiter of outputArbiter is
begin

    process(freePort, enablePort, enable)
        variable auxDone : std_logic;
        variable auxSelected : integer;
    begin
        auxDone := '0';
        auxSelected := 0;
        if(enable = '1') then
            for i in EAST to LOCAL-1 loop
                if(enablePort(i) = '1' and freePort(i) = '1') then
                    auxSelected := i;
                    auxDone := '1';
                    exit;
                end if;
            end loop;
        end if;
        isOutputSelected <= auxDone;
        selectedOutput <= auxSelected;
    end process;

end outputArbiter;
