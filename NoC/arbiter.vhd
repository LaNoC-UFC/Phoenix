library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity arbiter is
    generic(
        SIZE : positive
    );
    port(
        requests :              in std_logic_vector(SIZE-1 downto 0);
        enable :                in std_logic;
        isOutputSelected :      out std_logic;
        selectedOutput :        out natural range 0 to (SIZE-1)
    );
end;

architecture FixedPriorityArbiter of arbiter is
begin

    process(requests, enable)
        variable auxDone : std_logic;
        variable auxSelected : integer range 0 to (SIZE-1);
    begin
        auxDone := '0';
        auxSelected := 0;
        if(enable = '1') then
            for i in requests'low to requests'high loop
                if requests(i) = '1' then
                    auxSelected := i;
                    auxDone := '1';
                    exit;
                end if;
            end loop;
        end if;
        isOutputSelected <= auxDone;
        selectedOutput <= auxSelected;
    end process;

end FixedPriorityArbiter;

architecture RoundRobinArbiter of arbiter is
    signal lastPort : integer range 0 to (SIZE-1);
begin
    process(enable)
        variable SelectedPort : integer range 0 to (SIZE-1) := 0;
        variable requestCheck : integer range 0 to (SIZE-1);
    begin        
        if rising_edge(enable) then
            requestCheck := lastPort;
            SelectedPort := lastPort;
            for i in requests'low to requests'high loop
                if(requestCheck = SIZE-1) then
                    requestCheck := 0;
                else
                    requestCheck := requestCheck + 1;
                end if;

                if(requests(requestCheck) = '1') then
                    SelectedPort := requestCheck;
                    exit;
                end if;
            end loop;
            lastPort <= SelectedPort;
            selectedOutput <= SelectedPort;
        end if;
    end process;
    isOutputSelected <= enable;
end RoundRobinArbiter;
