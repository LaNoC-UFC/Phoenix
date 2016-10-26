library IEEE;
use IEEE.std_logic_1164.all;
use STD.textio.all;
use work.PhoenixPackage.all;
use work.HammingPack16.all;

entity fault_injector_test is
end;

architecture fault_injector_test of fault_injector_test is

    constant NUMBER_ITERACTIONS : integer := 1000;
    signal clock:          std_logic := '0';
    signal reset:          std_logic;
    signal tx:             regNport := (others=>'0');
    signal data_in:        arrayNport_regphit := (others=>(others=>'0'));
    signal data_out:       arrayNport_regphit;
    signal credit:         regNport := (others=>'0');

begin
    reset <= '1', '0' after CLOCK_PERIOD/4;
    clock <= not clock after CLOCK_PERIOD/2;

    UUT : entity work.FaultInjector
    generic map(address => ADDRESS_FROM_INDEX(0))
    port map(
        clock => clock,
        reset => reset,
        tx => tx,
        data_in => data_in,
        data_out => data_out,
        credit => credit
    );

    process
        variable fault_count : integer := 0;
        file file_pointer : text;
        variable port_line : LINE;
    begin
        -- write file with desired fault rate
        file_open(file_pointer, "fault_" & to_hstring(ADDRESS_FROM_INDEX(0)) & ".txt", WRITE_MODE);
        write(port_line, string'("0.03 EAST"));
        writeline(file_pointer, port_line);
        file_close(file_pointer);

        tx(EAST) <= '1';
        credit(EAST) <= '1';
        wait until reset = '0';
        for i in 1 to NUMBER_ITERACTIONS loop
            wait until clock'event and clock = '1';
            if data_in(EAST) /= data_out(EAST) then
                fault_count := fault_count + 1;
            end if;
        end loop;
        report "Percentage of fault = " & real'image((real(fault_count)*100.0)/real(NUMBER_ITERACTIONS)) & "%.";
        wait;

    end process;

end fault_injector_test;
