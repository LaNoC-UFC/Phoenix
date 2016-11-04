----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    19:39:07 06/27/2013
-- Design Name:
-- Module Name:    FaultDetection - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use ieee.numeric_std.all;
use work.NoCPackage.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
--
--       IN    ____________    OUT
--            |            |
--    data_inA|------------| dataInB
--            |            |
--            |____________|
--                     compTest  test_link_in  test_link_out    <---sinais de controle
--            ____________\/____________\/___________\/________
--           |                                         |
--  data_out'|
--
--


entity FaultDetection is
   Port(
         clock :   in  std_logic;
         reset :   in  std_logic;
         c_strLinkTst: in regNport;     -- (start link test) indica que houve um pacote de controle do tipo TEST_LINKS para testar os links. Comentario antigo:sinal de teste local para exterior
         c_strLinkTstAll: out std_logic;  -- se algum buffer fez o pedido de teste de link
         c_stpLinkTst: out regNport;    -- (stop link test) indica o fim do teste do link
         test_link_inA   : in regNport; -- sinal testLink_i dos roteadores vizinhos que indica teste de link (desta maneira o roteador sabe que precisa revolver o dado recebido durante o teste do link). Comentario antigo: sinal de teste exterior para local
         data_outA      : in arrayNport_regflit; -- data_out normal. Dado que sera encaminhado para as portas de saida, caso nao esteja em teste
         data_inA      : in arrayNport_regflit; -- dado(flit) recebido nas portas de entrada dos buffers (para analisar o dado recebido no teste de links)
         credit_inA      : in regNport;
         credit_outA      : in regNport;
         data_outB      : out arrayNport_regflit; -- dado que sera encaminhado para as portas de saida (pode ser encaminhado data_out normal ou dados para teste de link)
         credit_inB      : out regNport;
         c_faultTableFDM   : out regNPort; -- tabela de falhas ('0' indica sem falha, '1' indica falha)
         credit_outB      : out regNport);
end FaultDetection;

-- str(send to router)

architecture Behavioral of FaultDetection is

signal stopLinkTest: std_logic;
type testLinks is (S_INIT, S_FIRSTDATA, S_SECONDDATA,S_END);
signal EA : testLinks;
signal compTest : std_logic := '0';
signal tmp : regNport := (others=>'Z');
signal fillOne : regFlit := (others=>'1');
signal fillZero : regFlit := (others=>'0');
signal strLinkTstAll : std_logic := '0';
signal faultTableReg : regNPort :=(others=>'0');

begin

   c_stpLinkTst <= (others=>'1') when stopLinkTest = '1' else (others=>'0');
   c_faultTableFDM <= faultTableReg;
   c_strLinkTstAll <= strLinkTstAll;

   -- '1' se em algum buffer houve o pedido de teste de link (por causa do pacote de controle do tipo TEST_LINKS)
   strLinkTstAll <= c_strLinkTst(EAST) or c_strLinkTst(WEST) or c_strLinkTst(NORTH) or c_strLinkTst(SOUTH) or c_strLinkTst(LOCAL);

   -- link LOCAL eh considerado sempre sem falha. Nao passa pelo teste de links
   credit_outB(LOCAL) <= credit_outA(LOCAL);
   credit_inB(LOCAL) <= credit_inA(LOCAL);
   data_outB(LOCAL) <= data_outA(LOCAL);

   ALL_MUX : for i in 0 to (NPORT-2) generate -- para 4 portas (EAST, WEST, NORTH, SOUTH)
      credit_outB(i) <= credit_outA(i) when (strLinkTstAll or test_link_inA(i)) = '0' else '0';
      credit_inB(i) <= credit_inA(i) when (strLinkTstAll or test_link_inA(i)) = '0' else '0';

      data_outB(i) <= data_outA(i) when strLinkTstAll = '0' and test_link_inA(i) = '0' else --passagem do data_out normal
            data_inA(i)   when test_link_inA(i) = '1' and strLinkTstAll = '0' else -- retransmissao do dado de test_link
            (others=>'1') when strLinkTstAll ='1' and compTest = '1' else --envio do dado(1) de test_link
            (others=>'0') when strLinkTstAll ='1' and compTest = '0' else --envio do dado(2) de test_link
            (others=>'Z');

      tmp(i) <= '0'   when compTest = '1' and (data_inA(i) xor fillOne) = std_logic_vector(to_unsigned(0, fillOne'length)) else -- '0' QUANDO estiver enviando dado com todos os bits em '1' E receber o mesmo dado que enviou (todos os bits em '1')
              '1'   when compTest = '1' else -- '1' QUANDO estiver enviando dado com todos os bits em '1' (nao recebe o mesmo dado que enviou, logo tem falha)
              '0'   when compTest = '0' and (data_inA(i) xor fillZero) = std_logic_vector(to_unsigned(0, fillZero'length)) else -- '0' QUANDO estiver enviando dado com todos os bits em '0' E receber o mesmo dado que enviou (todos os bits em '0')
              '1'   when compTest = '0' else  -- '1' QUANDO estiver enviando dado com todos os bits em '1' (nao recebe o mesmo dado que enviou, logo tem falha)
              'Z';
   end generate ALL_MUX;

   --maquina de estados para transmitir e receber os dados
   process(clock,reset)
   begin
      if reset = '1' then
         stopLinkTest <= '0';
         compTest <= '0';
         EA <= S_INIT;
      elsif (clock'event and clock='1') then
         case EA is
            when S_INIT =>
               -- verifica em algum buffer houve o pedido de teste de link
               if strLinkTstAll = '1' then
                  stopLinkTest <= '0';
                  compTest <= '0'; --auxiliar (indica que os dados enviados serao tudo '0')
                  EA <= S_FIRSTDATA;
               end if;

            -- envio do primeiro dado (todos os bits em 0). Caso receber os mesmos dados enviados (todos os bits em 0), armazeno '0' na tabela. '1' indica falha
            when S_FIRSTDATA =>
               faultTableReg(EAST) <= tmp(EAST);
               faultTableReg(WEST) <= tmp(WEST);
               faultTableReg(NORTH) <= tmp(NORTH);
               faultTableReg(SOUTH) <= tmp(SOUTH);
               --faultTableReg(LOCAL) <= tmp(LOCAL);
               faultTableReg(LOCAL) <= '0';
               compTest <= '1'; --auxiliar (indica que os dados enviados serao tudo '1')
               EA <= S_SECONDDATA;

            -- envio do segundo dado (todos os bits em 1). Caso receber os mesmos dados enviados (todos os bits em 0) e se nao tiver tido problema no primeiro envio, a tabela sera '0'. '1' indica falha
            when S_SECONDDATA =>
               faultTableReg(EAST) <= faultTableReg(EAST) or tmp(EAST);
               faultTableReg(WEST) <= faultTableReg(WEST) or tmp(WEST);
               faultTableReg(NORTH) <= faultTableReg(NORTH) or tmp(NORTH);
               faultTableReg(SOUTH) <= faultTableReg(SOUTH) or tmp(SOUTH);
               faultTableReg(LOCAL) <= '0';
               --faultTableReg(LOCAL) <= faultTableReg(LOCAL) or tmp(LOCAL);
               stopLinkTest <= '1'; -- indica fim
               EA <= S_END;

            when S_END =>
               stopLinkTest <= '0';
               EA <= S_INIT;

            when others =>
               EA <= S_INIT;
         end case;
      end if;
   end process;
end Behavioral;