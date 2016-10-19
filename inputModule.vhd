library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use STD.textio.all;
use work.PhoenixPackage.all;

entity inputModule is
generic(
    address: regflit
);
port(
    done:           out std_logic;
    data:           out regflit;
    enable:         in std_logic;
    currentTime:    in std_logic_vector(4*TAM_FLIT-1 downto 0)
);
end;

architecture inputModule of inputModule is

    function string_to_int(
        x_str : string;
        radix : positive range 2 to 36 := 10
    ) return integer is
        constant STR_LEN          : integer := x_str'length;
        variable chr_val          : integer;
        variable ret_int          : integer := 0;
        variable do_mult          : boolean := true;
        variable power            : integer := 0;
    begin
        for i in STR_LEN downto 1 loop
            case x_str(i) is
                when '0'       =>   chr_val := 0;
                when '1'       =>   chr_val := 1;
                when '2'       =>   chr_val := 2;
                when '3'       =>   chr_val := 3;
                when '4'       =>   chr_val := 4;
                when '5'       =>   chr_val := 5;
                when '6'       =>   chr_val := 6;
                when '7'       =>   chr_val := 7;
                when '8'       =>   chr_val := 8;
                when '9'       =>   chr_val := 9;
                when 'A' | 'a' =>   chr_val := 10;
                when 'B' | 'b' =>   chr_val := 11;
                when 'C' | 'c' =>   chr_val := 12;
                when 'D' | 'd' =>   chr_val := 13;
                when 'E' | 'e' =>   chr_val := 14;
                when 'F' | 'f' =>   chr_val := 15;
                when others => report "Illegal character for conversion for string to integer" severity failure;
            end case;
            if chr_val >= radix then report "Illagel character at this radix" severity failure; end if;

            if do_mult then
                ret_int := ret_int + (chr_val * (radix**power));
            end if;

            power := power + 1;
        end loop;
        return ret_int;
    end function;

    procedure clear_string(toBeCleared : inout string) is
    begin
        for i in toBeCleared'low to toBeCleared'high loop
            toBeCleared(i) := NUL;
        end loop;
    end clear_string;

    procedure next_integer(
        current_package : in string;
        index : inout integer;
        desired_input_time : out integer
    ) is
        variable str_size: integer := 0;
    begin
        while (current_package(index) /= ' ' and index <= current_package'high) loop
            index := index + 1;
            str_size := str_size + 1;
        end loop;
        desired_input_time := string_to_int(current_package(1 to str_size),16);
        str_size := str_size + 1;
        index := index + 1;
    end next_integer;

    procedure next_regflit(
        current_package : in string;
        index : inout integer;
        result : out regflit
    ) is
    begin
        result :=   CONV_VECTOR(current_package, index) &
                    CONV_VECTOR(current_package, index + 1) &
                    CONV_VECTOR(current_package, index + 2) &
                    CONV_VECTOR(current_package, index + 3);
        index := index + 5;
    end next_regflit;

    impure function next_package(file file_pointer: text) return string is
        variable current_package: string (1 to TAM_LINHA);
        variable current_line : line;
    begin
        readline(file_pointer, current_line);
        clear_string(current_package);
        for i in current_line'low to current_line'high loop
            current_package(i) := current_line(i);
        end loop;
        return current_package;
    end next_package;

begin

    process
        file file_pointer: text;
        variable current_package: string (1 to TAM_LINHA);
        variable char_pointer: integer;
        variable desired_input_time: integer := 0;
        variable actual_input_time: std_logic_vector(4*TAM_FLIT-1 downto 0) := (others=>'0');
        variable package_size: regflit;
        variable current_flit: regflit;
        variable current_flit_index: integer;
        variable is_control_package: std_logic;
    begin
        file_open(file_pointer,"In/in"&to_hstring(address)&".txt",READ_MODE);
        while not endfile(file_pointer) loop
            current_package := next_package(file_pointer);
            char_pointer := current_package'low;
            next_integer(current_package, char_pointer, desired_input_time);

            done <= '0';
            data <= (others=>'0');

            -- wait for injection time
            while not (currentTime >= desired_input_time) loop
                wait for 1 ns;
            end loop;

            current_flit_index := 0;
            is_control_package := '0';

            -- leitura da linha e injetado os flits lidos
            while (current_package(char_pointer) /= NUL) loop

                if (enable = '1') then
                    if (current_flit_index >= 9 and current_flit_index <= 12 and is_control_package = '0') then
                        current_flit := actual_input_time(((13-current_flit_index)*TAM_FLIT-1) downto ((12-current_flit_index)*TAM_FLIT));
                    else
                        next_regflit(current_package, char_pointer, current_flit);
                    end if;

                    if (current_flit_index = 0) then
                        is_control_package := current_flit(TAM_FLIT-1);
                        actual_input_time := currentTime;
                    elsif (current_flit_index = 1 and is_control_package = '0') then
                        current_flit := current_flit + 4; -- reservar +4 espacos para o timestamp de entrada na rede
                        package_size := current_flit;
                    end if;

                    done <= '1';
                    data <= current_flit;
                    current_flit_index := current_flit_index + 1;
                else
                    done <= '0';
                    data <= (others=>'0');
                end if;

                wait for 20 ns; -- clock period
            end loop;

            done <= '0';
            data <= (others=>'0');

        end loop;
    wait;
    end process;

end inputModule;
