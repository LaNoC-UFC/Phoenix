library IEEE;
use IEEE.std_logic_1164.all;
use STD.textio.all;
use ieee.numeric_std.all;
use work.NoCPackage.all;

entity outputModule is
    generic(
        address: regflit
    );
    port(
        clock:          in std_logic;
        tx:             in std_logic;
        data:           in regflit;
        currentTime:    in unsigned(4*TAM_FLIT-1 downto 0)
    );
end;

architecture outputModule of outputModule is
begin

    process(clock)
        variable current_flit_index : integer := 0;
        variable package_size : unsigned(TAM_FLIT-1 downto 0) := (others=>'0');
        file file_pointer : TEXT;
        variable fstatus: file_open_status := STATUS_ERROR;
        variable current_line : LINE;
        variable desired_input_time: unsigned ((TAM_FLIT*4)-1 downto 0) := (others=>'0');
        variable actual_input_time: unsigned ((TAM_FLIT*4)-1 downto 0) := (others=>'0');
        variable tail_arrival_time: unsigned ((TAM_FLIT*4)-1 downto 0) := (others=>'0');
        variable package_latency: integer;
        variable is_control_package: std_logic;
    begin
        if (clock'event and clock = '0') then
            if tx = '1' then
                -- head
                if (current_flit_index = 0) then
                    write(current_line, string'(to_hstring(data)) & " ");
                    is_control_package := data(TAM_FLIT-1);
                -- size
                elsif (current_flit_index = 1) then
                    write(current_line, string'(to_hstring(data)) & " ");
                    package_size := unsigned(data) + 2;
                -- payload
                elsif (current_flit_index < package_size - 1) then

                    if (current_flit_index >= 3 and current_flit_index <= 6 and is_control_package = '0') then
                        desired_input_time((TAM_FLIT*(7-current_flit_index)-1) downto (TAM_FLIT*(6-current_flit_index))) := unsigned(data);
                    end if;

                    if (current_flit_index >= 9 and current_flit_index <= 12 and is_control_package = '0') then
                        actual_input_time((TAM_FLIT*(13-current_flit_index)-1) downto (TAM_FLIT*(12-current_flit_index))) := unsigned(data);
                    end if;

                    if (current_flit_index = 2 or current_flit_index = 7 or current_flit_index = 8) then
                        write(current_line, string'(to_hstring(data)) & " ");
                    end if;
                -- tail
                else
                    if (is_control_package = '0') then
                        tail_arrival_time := currentTime;
                        write(current_line, " " & string'(integer'image(to_integer(signed(actual_input_time)))));
                        package_latency := to_integer(signed(tail_arrival_time-desired_input_time));
                        write(current_line, " " & string'(integer'image(package_latency)));

                        if(fstatus /= OPEN_OK) then
                            file_open(fstatus, file_pointer,"Out/out"&to_hstring(address)&".txt",WRITE_MODE);
                        end if;
                        writeline(file_pointer, current_line);
                    end if;
                    current_flit_index := -1;
                end if;
                current_flit_index := current_flit_index + 1;
            end if;
        end if;
    end process;

end outputModule;
