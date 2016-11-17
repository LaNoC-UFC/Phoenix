library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.NoCPackage.all;
use work.HammingPack16.all;

entity phoenix_buffer_test is
end;

architecture happy_path of phoenix_buffer_test is

    constant PACKAGE_SIZE: integer := TAM_BUFFER-1;
    constant PAYLOAD_SIZE: integer := PACKAGE_SIZE-2;
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
        data_in <= to_unsigned(PAYLOAD_SIZE, data_in'length);
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
        assert data_av = '0' report "Buffer shouldn't have no more data" severity failure;
        assert sender = '0' report "Buffer shouldn't been sending any more" severity failure;
        assert credit_o = '1' report "Buffer should be empty" severity failure;
        -- 
        wait;
    end process;

end happy_path;

architecture data_input_test of phoenix_buffer_test is

    constant PACKAGE_SIZE: integer := TAM_BUFFER-1;
    constant PAYLOAD_SIZE: integer := PACKAGE_SIZE-2;
    signal clock:          std_logic := '0';
    signal reset:          std_logic;
    signal rx:             std_logic;
    signal data_in:        unsigned((TAM_FLIT-1) downto 0);
    signal data: regflit;
    signal credit_o:       std_logic;
    signal h, ack_h, data_av, data_ack, sender: std_logic;
    signal statusHamming: reg3;
    signal c_strLinkTstAll, c_strLinkTstNeighbor, retransmission_out: std_logic;

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
        bufLocation => EAST)
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
        c_strLinkTstNeighbor => c_strLinkTstNeighbor,
        c_strLinkTstAll => c_strLinkTstAll,
        c_stpLinkTst => '0',
        retransmission_in => '0',
        statusHamming => statusHamming,
        retransmission_out => retransmission_out
    );

    process
    begin
        rx <= '0';
        data_in <= to_unsigned(PAYLOAD_SIZE, data_in'length);
        ack_h <= '0';
        data_ack <= '0';
        c_strLinkTstNeighbor <= '0';
        c_strLinkTstAll <= '0';
        statusHamming <= NE;
        wait until reset = '0';
        assert credit_o = '1' report "Buffer should be empty after reset" severity failure;
        assert h = '0' report "No routing request should be made before there's data" severity failure;
        assert data_av = '0' report "Buffer shouldn't have data" severity failure;
        assert sender = '0' report "Buffer shouldn't been sending" severity failure;
        assert retransmission_out = '0' report "Buffer shouldn't been requesting retransmission" severity failure;
        wait_clock_tick;
        -- fill it almost completely
        rx <= '1';
        for i in 1 to PACKAGE_SIZE-2 loop
            wait_clock_tick;
            assert credit_o = '1' report "Buffer should have space left " & integer'image(i) severity failure;
            assert data_av = '0' report "Buffer shouldn't have data" severity failure;
            assert sender = '0' report "Buffer shouldn't been sending" severity failure;
        end loop;
        wait_clock_tick;
        assert credit_o = '1' report "Buffer should have one space left" severity failure;
        -- signal router testing its links
        c_strLinkTstAll <= '1';
        wait_clock_tick;
        assert credit_o = '1' report "Buffer shouldn't accept test flits" severity failure;
        c_strLinkTstAll <= '0';
        -- signal neighbor testing that channel
        c_strLinkTstNeighbor <= '1';
        wait_clock_tick;
        assert credit_o = '1' report "Buffer shouldn't accept test flits" severity failure;
        c_strLinkTstNeighbor <= '0';
        -- signal non recovered flit
        statusHamming <= ED;
        wait_clock_tick;
        assert credit_o = '1' report "Buffer shouldn't accept faulty flits" severity failure;
        assert retransmission_out = '1' report "Buffer should request retransmission" severity failure;
        -- signal recovered flit (fill it)
        statusHamming <= EC;
        wait_clock_tick;
        wait until credit_o'stable;
        assert credit_o = '0' report "Buffer should accept corrected flits" severity failure;
        assert retransmission_out = '0' report "Buffer shouldn'd request retransmission" severity failure;
        -- empty it
        rx <= '0';
        ack_h <= '1';
        wait_clock_tick;
        wait until data_av'stable;
        ack_h <= '0';
        data_ack <= '1';
        assert data_av = '1' report "Buffer should have data" severity failure;
        assert sender = '1' report "Buffer should been sending" severity failure;
        for i in 1 to PACKAGE_SIZE loop
            wait_clock_tick;
        end loop;
        assert data = std_logic_vector(to_unsigned(PAYLOAD_SIZE+1, data'length)) report "Last flit should be increased" severity failure;
        wait_clock_tick;
        assert h = '0' report "No routing request should be made before there's data" severity failure;
        assert data_av = '0' report "Buffer shouldn't have data" severity failure;
        assert sender = '0' report "Buffer shouldn't been sending" severity failure;
        --
        wait;
    end process;

end data_input_test;

architecture data_output_test of phoenix_buffer_test is

    constant PACKAGE_SIZE: integer := TAM_BUFFER-1;
    constant PAYLOAD_SIZE: integer := PACKAGE_SIZE-2;
    signal clock:          std_logic := '0';
    signal reset:          std_logic;
    signal rx:             std_logic;
    signal data_in:        unsigned((TAM_FLIT-1) downto 0);
    signal data: regflit;
    signal credit_o:       std_logic;
    signal h, ack_h, data_av, data_ack, sender: std_logic;
    signal retransmission_in: std_logic;

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
        bufLocation => EAST)
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
        retransmission_in => retransmission_in,
        statusHamming => NE
    );

    process
    begin
        rx <= '0';
        data_in <= to_unsigned(PAYLOAD_SIZE, data_in'length);
        ack_h <= '0';
        data_ack <= '0';
        retransmission_in <= '0';
        wait until reset = '0';
        wait_clock_tick;
        -- push the package head (destination) only
        rx <= '1';
        wait_clock_tick;
        rx <= '0';
        assert credit_o = '1' report "Buffer should have space left" severity failure;
        -- route the package
        wait until h = '1';
        wait_clock_tick;
        ack_h <= '1';
        wait_clock_tick;
        wait until h'stable;
        assert h = '0' report "Request was already been answered" severity failure;
        assert data_av = '1' report "There should be data available" severity failure;
        assert sender = '1' report "Buffer should been sending" severity failure;
        ack_h <= '0';
        -- request retransmission of the package header
        data_ack <= '1';
        retransmission_in <= '1';
        wait_clock_tick;
        assert data_av = '1' report "There should be data available" severity failure;
        -- accept the package header
        retransmission_in <= '0';
        wait_clock_tick;
        wait until data_av'stable;
        assert data_av = '0' report "There should be no data available" severity failure;
        data_ack <= '0';
        -- push one more flit (package size)
        rx <= '1';
        wait_clock_tick;
        wait until data_av'stable;
        assert data_av = '1' report "There should be data available" severity failure;
        rx <= '0';
        -- request retransmission of the package size
        data_ack <= '1';
        retransmission_in <= '1';
        wait_clock_tick;
        assert data_av = '1' report "There should be data available" severity failure;
        -- accept the package size
        retransmission_in <= '0';
        wait_clock_tick;
        wait until data_av'stable;
        assert data_av = '0' report "There should be no data available" severity failure;
        data_ack <= '0';
        --
        wait;
    end process;

end data_output_test;

-- reproduces bug (Issue #60)
architecture empty_buffer_test of phoenix_buffer_test is

    constant PACKAGE_SIZE: integer := TAM_BUFFER-1;
    constant PAYLOAD_SIZE: integer := PACKAGE_SIZE-2;
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
        bufLocation => EAST)
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
        statusHamming => NE
    );

    process
    begin
        rx <= '0';
        data_in <= to_unsigned(PAYLOAD_SIZE, data_in'length);
        ack_h <= '0';
        data_ack <= '0';
        wait until reset = '0';
        wait_clock_tick;
        -- push the package head (destination) only
        rx <= '1';
        wait_clock_tick;
        rx <= '0';
        -- route the package
        wait until h = '1';
        wait_clock_tick;
        ack_h <= '1';
        wait_clock_tick;
        wait until h'stable;
        assert h = '0' report "Request was already been answered" severity failure;
        assert data_av = '1' report "There should be data available" severity failure;
        assert sender = '1' report "Buffer should been sending" severity failure;
        ack_h <= '0';
        -- accept the package header
        data_ack <= '1';
        wait_clock_tick;
        wait until data_av'stable;
        assert data_av = '0' report "There should be no data available" severity failure;
        -- accept others outgoing flits (but there's no more)
        for i in 1 to TAM_BUFFER-1 loop
            wait_clock_tick;
            assert data_av = '0' report "There should be no data available" severity failure;
        end loop;
        --
        wait;
    end process;

end empty_buffer_test;
