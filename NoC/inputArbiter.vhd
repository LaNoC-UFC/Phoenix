library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use work.NoCPackage.all;
use work.TablePackage.all;

entity inputArbiter is
port(
    requests : in regNport;
    enable : in std_logic;
    nextPort : out integer range 0 to (NPORT-1);
    ready : out std_logic
);
end inputArbiter;

architecture RoundRobin of inputArbiter is

    signal lastPort : integer range 0 to (NPORT-1) := EAST;

begin

    process(enable)
        variable designedPort : integer range 0 to (NPORT-1);
    begin
        if(enable'event and enable = '1') then
            case lastPort is
                when LOCAL=>
                    if requests(EAST)='1' then designedPort := EAST;
                    elsif requests(WEST)='1' then designedPort := WEST;
                    elsif requests(NORTH)='1' then designedPort := NORTH;
                    elsif requests(SOUTH)='1' then designedPort := SOUTH;
                    else designedPort := LOCAL; end if;
                when EAST=>
                    if requests(WEST)='1' then designedPort := WEST;
                    elsif requests(NORTH)='1' then designedPort := NORTH;
                    elsif requests(SOUTH)='1' then designedPort := SOUTH;
                    elsif requests(LOCAL)='1' then designedPort := LOCAL;
                    else designedPort := EAST; end if;
                when WEST=>
                    if requests(NORTH)='1' then designedPort := NORTH;
                    elsif requests(SOUTH)='1' then designedPort := SOUTH;
                    elsif requests(LOCAL)='1' then designedPort := LOCAL;
                    elsif requests(EAST)='1' then designedPort := EAST;
                    else designedPort := WEST; end if;
                when NORTH=>
                    if requests(SOUTH)='1' then designedPort := SOUTH;
                    elsif requests(LOCAL)='1' then designedPort := LOCAL;
                    elsif requests(EAST)='1' then designedPort := EAST;
                    elsif requests(WEST)='1' then designedPort := WEST;
                    else designedPort := NORTH; end if;
                when SOUTH=>
                    if requests(LOCAL)='1' then designedPort := LOCAL;
                    elsif requests(EAST)='1' then designedPort := EAST;
                    elsif requests(WEST)='1' then designedPort := WEST;
                    elsif requests(NORTH)='1' then designedPort := NORTH;
                    else designedPort := SOUTH; end if;
            end case;
            lastPort <= designedPort;
            nextPort <= designedPort;
        end if;
    end process;

    ready <= enable;

end RoundRobin;