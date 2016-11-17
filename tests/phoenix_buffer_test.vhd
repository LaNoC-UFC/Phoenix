library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.NoCPackage.all;

entity phoenix_buffer_test is
end;

architecture happy_path of phoenix_buffer_test is

    signal clock:          std_logic := '0';
    signal reset:          std_logic;
    signal rx:             std_logic;
    signal data_in:        unsigned((TAM_FLIT-1) downto 0);
    signal data: regflit;
    signal credit_o:       std_logic;
    signal h, ack_h, data_av, data_ack, sender: std_logic;

    procedure wait_clock_tick is
    begin
        wait until rising_edge(clock);
    end wait_clock_tick;

begin
    reset <= '1', '0' after CLOCK_PERIOD/4;
    clock <= not clock after CLOCK_PERIOD/2;

    UUT : entity work.Phoenix_buffer
    generic map(
        address => ADDRESS_FROM_INDEX(0),
        bufLocation => LOCAL)
    port map(
        clock => clock,
        reset => reset,
        clock_rx => clock,
        rx => rx,
        data_in => data_in,
        credit_o => credit_o,
        h => h,
        ack_h => ack_h,
        data_av => data_av,
        data => data,
        data_ack => data_ack,
        sender => sender,
        
        c_error_find => validRegion,
        c_error_dir => (others=>'0'),
        c_tabelaFalhas => (others=>(others=>'0')),
        c_strLinkTstOthers => '0',
        c_strLinkTstNeighbor => '0',
        c_strLinkTstAll => '0',
        c_stpLinkTst => '0',
        retransmission_in => '0',
        statusHamming => (others=>'0')
    );

    process
    begin
        rx <= '0';
        data_in <= to_unsigned(30, data_in'length);
        ack_h <= '0';
        data_ack <= '0';
        wait until reset = '0';
        assert credit_o = '1' report "Buffer should be empty after reset" severity failure;
        assert h = '0' report "No routing request should be made before there's data" severity failure;
        assert data_av = '0' report "Buffer shouldn't have data" severity failure;
        assert sender = '0' report "Buffer shouldn't been sending" severity failure;
        wait_clock_tick;
        -- fill it completely
        rx <= '1';
        for i in 1 to TAM_BUFFER-1 loop
            wait_clock_tick;
            assert credit_o = '1' report "Buffer should have space left" severity failure;
            assert data_av = '0' report "Buffer shouldn't have data" severity failure;
            assert sender = '0' report "Buffer shouldn't been sending" severity failure;
        end loop;
        wait_clock_tick;
        assert credit_o = '0' report "Buffer has space left" severity failure;
        assert h = '1' report "A request should have been made" severity failure;
        rx <= '0';
        ack_h <= '1';
        wait_clock_tick;
        wait until h'stable;
        assert h = '0' report "The request was already answered" severity failure;
        assert data_av = '1' report "Buffer has data available" severity failure;
        assert sender = '1' report "Buffer is sending" severity failure;
        ack_h <= '0';
        wait_clock_tick;
        -- empty it completely
        data_ack <= '1';
        for i in 1 to TAM_BUFFER-1 loop
            wait_clock_tick;
            assert data_av = '1' report "Buffer should have data" severity failure;
            assert sender = '1' report "Buffer should been sending" severity failure;
        end loop;
        wait_clock_tick;
        wait until sender'stable;
        assert data_av = '0' report "Buffer shouldn't have no more data" severity failure;
        assert sender = '0' report "Buffer shouldn't been sending any more" severity failure;
        assert credit_o = '1' report "Buffer should be empty" severity failure;
        -- 
        wait;
    end process;

end happy_path;
