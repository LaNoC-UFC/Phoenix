library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use work.HammingPack16.all;
use work.PhoenixPackage.all;

entity HAM_ENC is
port
(
   data_in          : in  regflit; -- data input
   data_out         : out reghamm  -- data output
);
end HAM_ENC;

architecture HAM_ENC of HAM_ENC is

  signal P : Std_logic_vector(5 downto 1); --Hamming bits

begin
  P(1) <= xor_reduce(data_in and MaskP1);
   P(2) <= xor_reduce(data_in and MaskP2);
   P(3) <= xor_reduce(data_in and MaskP4);
   P(4) <= xor_reduce(data_in and MaskP8);
   P(5) <= xor_reduce(data_in and MaskP16);

   data_out <= P & xor_reduce(P & data_in);

end HAM_ENC;