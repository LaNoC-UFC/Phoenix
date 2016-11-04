library IEEE;
use IEEE.std_logic_1164.all;
use work.PhoenixPackage.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use IEEE.numeric_std.all;

entity topNoC is
end;

architecture topNoC of topNoC is

    signal clock : regNrot:=(others=>'0');
    signal reset : std_logic;
    signal clock_rx: regNrot:=(others=>'0');
    signal rx, credit_o: regNrot;
    signal clock_tx, tx, credit_i, testLink_i, testLink_o: regNrot;
    signal data_in, data_out : arrayNrot_regflit;
    signal currentTime: unsigned(4*TAM_FLIT-1 downto 0) := (others=>'0');

begin
    reset <= '1', '0' after CLOCK_PERIOD/2;
    clock <= not clock after CLOCK_PERIOD/2;
    clock_rx <= not clock_rx after CLOCK_PERIOD/2;
    credit_i <= tx;
    testLink_i <= (others=>'0');

    NOC: Entity work.NOC
    port map(
        clock               => clock,
        reset               => reset,
        clock_rxLocal       => clock_rx,
        rxLocal             => rx,
        data_inLocal_flit   => data_in,
        credit_oLocal       => credit_o,
        clock_txLocal       => clock_tx,
        txLocal             => tx,
        data_outLocal_flit  => data_out,
        credit_iLocal       => credit_i
    );

    process (reset, clock(0))
    begin
        if (reset = '1') then
            currentTime <= (others=>'0');
        elsif (rising_edge(clock(0))) then
            currentTime <= currentTime + 1;
        end if;
    end process;

    InputModules: for i in 0 to (NROT-1) generate
        IM : Entity work.inputModule
        generic map(address => ADDRESS_FROM_INDEX(i))
        port map(
            done => rx(i),
            data => data_in(i),
            enable => credit_o(i),
            currentTime => currentTime
        );
    end generate InputModules;

    OutputModules: for i in 0 to (NROT-1) generate
        OM : Entity work.outputModule
        generic map(address => ADDRESS_FROM_INDEX(i))
        port map(
            clock => clock(i),
            tx => tx(i),
            data => data_out(i),
            currentTime => currentTime
        );
    end generate OutputModules;

end topNoC;
