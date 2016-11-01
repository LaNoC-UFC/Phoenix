----------------------------------------------------------------
--                              CROSSBAR
--                          --------------
--               DATA_AV ->|              |
--               DATA_IN ->|              |
--              DATA_ACK <-|              |-> TX
--                SENDER ->|              |-> DATA_OUT
--                  FREE ->|              |<- CREDIT_I
--                TAB_IN ->|              |
--               TAB_OUT ->|              |
--                          --------------
----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.PhoenixPackage.all;
use ieee.numeric_std.all;

entity Phoenix_crossbar is
port(
   data_av:               in  regNport;
   data_in:               in  arrayNport_regflit;
   data_ack:              out regNport;
   sender:                in  regNport;
   free:                  in  regNport;
   tab_in:                in  arrayNport_reg3;
   tab_out:               in  arrayNport_reg3;
   tx:                    out regNport;
   data_out:              out arrayNport_regflit;
   credit_i:              in  regNport;
   retransmission_i:      in  regNport;
   retransmission_in_buf: out regNport);
end Phoenix_crossbar;

architecture Phoenix_crossbar of Phoenix_crossbar is

begin

    MUXS: for i in EAST to LOCAL generate
        tx(i)   <= data_av(to_integer( unsigned(tab_out(i)))) when free(i) = '0' else '0';
        data_out(i) <= data_in(to_integer( unsigned(tab_out(i)))) when free(i) = '0' else (others=>'0');
        data_ack(i) <= credit_i(to_integer( unsigned(tab_in(i)))) when data_av(i) = '1' else '0';
        retransmission_in_buf(i) <= retransmission_i(to_integer( unsigned(tab_in(i)))) when data_av(i)='1' else '0';
    end generate MUXS;

end Phoenix_crossbar;
