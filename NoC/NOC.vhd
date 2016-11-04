library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.HammingPack16.all;
use work.NoCPackage.all;


entity NOC is
port(
    clock         : in  regNrot;
    reset         : in  std_logic;
    clock_rxLocal : in  regNrot;
    rxLocal       : in  regNrot;
    data_inLocal_flit  : in  arrayNrot_regflit;
    credit_oLocal : out regNrot;
    clock_txLocal : out regNrot;
    txLocal       : out regNrot;
    data_outLocal_flit : out arrayNrot_regflit;
    credit_iLocal : in  regNrot
);
end NOC;

architecture NOC of NOC is

    signal data_inLocal, data_outLocal: arrayNrot_regphit;
    signal retransmission_i, retransmission_o, rx, clock_rx, credit_i, tx, clock_tx, credit_o, testLink_i, testLink_o : arrayNrot_regNport;
    signal data_in, data_out : matrixNrot_Nport_regphit;

begin

    fillLocalFlits: for i in 0 to NROT-1 generate
    begin
        data_inLocal(i)         <= data_inLocal_flit(i) & std_logic_vector(to_unsigned(0,TAM_HAMM));
        data_outLocal_flit(i)   <= data_outLocal(i)(TAM_PHIT-1 downto TAM_HAMM);
    end generate;

    Router: for i in 0 to (NROT-1) generate
        n : Entity work.RouterCC
        generic map( address => ADDRESS_FROM_INDEX(i))
        port map(
            clock                   => clock(i),
            reset                   => reset,

            clock_rx                => clock_rx(i),
            rx                      => rx(i),
            data_in                 => data_in(i),
            credit_o                => credit_o(i),
            clock_tx                => clock_tx(i),

            tx                      => tx(i),
            data_out                => data_out(i),
            credit_i                => credit_i(i),
            testLink_i              => testLink_i(i),
            testLink_o              => testLink_o(i),
            retransmission_i        => retransmission_i(i),
            retransmission_o        => retransmission_o(i)
        );
    end generate Router;

    link1: for i in 0 to (NROT-1) generate
        east: if i < NUM_Y*MAX_X generate
            clock_rx(i)(0)              <= clock_tx(i+NUM_Y)(1);
            rx(i)(0)                    <= tx(i+NUM_Y)(1);
            data_in(i)(0)               <= data_out(i+NUM_Y)(1);
            credit_i(i)(0)              <= credit_o(i+NUM_Y)(1);
            testLink_i(i)(0)            <= testLink_o(i+NUM_Y)(1);
            retransmission_i(i)(0)      <= retransmission_o(i+NUM_Y)(1);
        end generate east;

        west: if i >= NUM_Y generate
            clock_rx(i)(1)                  <= clock_tx(i-NUM_Y)(0);
            rx(i)(1)                        <= tx(i-NUM_Y)(0);
            data_in(i)(1)                   <= data_out(i-NUM_Y)(0);
            credit_i(i)(1)                  <= credit_o(i-NUM_Y)(0);
            testLink_i(i)(1)                <= testLink_o(i-NUM_Y)(0);
            retransmission_i(i)(1)          <= retransmission_o(i-NUM_Y)(0);
        end generate west;

        north: if (i-(i/NUM_Y)*NUM_Y) < MAX_Y generate
            clock_rx(i)(2)                  <= clock_tx(i+1)(3);
            rx(i)(2)                        <= tx(i+1)(3);
            data_in(i)(2)                   <= data_out(i+1)(3);
            credit_i(i)(2)                  <= credit_o(i+1)(3);
            testLink_i(i)(2)                <= testLink_o(i+1)(3);
            retransmission_i(i)(2)          <= retransmission_o(i+1)(3);
        end generate north;

        south: if (i-(i/NUM_Y)*NUM_Y) > MIN_Y generate
            clock_rx(i)(3)              <= clock_tx(i-1)(2);
            rx(i)(3)                    <= tx(i-1)(2);
            data_in(i)(3)               <= data_out(i-1)(2);
            credit_i(i)(3)              <= credit_o(i-1)(2);
            testLink_i(i)(3)            <= testLink_o(i-1)(2);
            retransmission_i(i)(3)      <= retransmission_o(i-1)(2);
        end generate south;
    end generate link1;


    link2 : for i in 0 to (NROT-1) generate
    -- LOCAL port
        clock_rx(i)(LOCAL)              <= clock_rxLocal(i);
        data_in(i)(LOCAL)               <= data_inLocal(i);
        credit_i(i)(LOCAL)              <= credit_iLocal(i);
        rx(i)(LOCAL)                    <= rxLocal(i);

        clock_txLocal(i)                <= clock_tx(i)(LOCAL);
        data_outLocal(i)                <= data_out(i)(LOCAL);
        credit_oLocal(i)                <= credit_o(i)(LOCAL);
        txLocal(i)                      <= tx(i)(LOCAL);

        testLink_i(i)(LOCAL)            <= '0';
        retransmission_i(i)(LOCAL)      <= '0';
    end generate link2;

end NOC;