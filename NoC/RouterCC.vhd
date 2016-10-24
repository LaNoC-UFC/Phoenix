---------------------------------------------------------------------------------------
--                                    ROUTER
--
--
--                                    NORTH         LOCAL
--                      -----------------------------------
--                      |             ******       ****** |
--                      |             *FILA*       *FILA* |
--                      |             ******       ****** |
--                      |          *************          |
--                      |          *  ARBITRO  *          |
--                      | ******   *************   ****** |
--                 WEST | *FILA*   *************   *FILA* | EAST
--                      | ******   *  CONTROLE *   ****** |
--                      |          *************          |
--                      |             ******              |
--                      |             *FILA*              |
--                      |             ******              |
--                      -----------------------------------
--                                    SOUTH
--
--  As chaves realizam a transferência de mensagens entre ncleos.
--  A chave possui uma lógica de controle de chaveamento e 5 portas bidirecionais:
--  East, West, North, South e Local. Cada porta possui uma fila para o armazenamento
--  temporário de flits. A porta Local estabelece a comunicação entre a chave e seu
--  ncleo. As demais portas ligam a chave à chaves vizinhas.
--  Os endereços das chaves são compostos pelas coordenadas XY da rede de interconexão,
--  onde X sãa posição horizontal e Y a posição vertical. A atribuição de endereços é
--  chaves é necessária para a execução do algoritmo de chaveamento.
--  Os módulos principais que compõem a chave são: fila, árbitro e lógica de
--  chaveamento implementada pelo controle_mux. Cada uma das filas da chave (E, W, N,
--  S e L), ao receber um novo pacote requisita chaveamento ao árbitro. O árbitro
--  seleciona a requisição de maior prioridade, quando existem requisições simultâneas,
--  e encaminha o pedido de chaveamento é lógica de chaveamento. A lógica de
--  chaveamento verifica se é possível atender é solicitação. Sendo possível, a conexão
--  é estabelecida e o árbitro é informado. Por sua vez, o árbitro informa a fila que
--  começa a enviar os flits armazenados. Quando todos os flits do pacote foram
--  enviados, a conexão é concluída pela sinalização, por parte da fila, através do
--  sinal sender.
---------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.PhoenixPackage.all;
use work.HammingPack16.all;
use STD.textio.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
USE ieee.math_real.ALL;   -- for UNIFORM, TRUNC functions

entity RouterCC is
generic( address: regflit);
port(
   clock:            in  std_logic;
   reset:            in  std_logic;
   testLink_i:       in  regNport;
   credit_i:         in  regNport;
   clock_rx:         in  regNport;
   rx:               in  regNport;
   data_in:          in  arrayNport_regphit;
   retransmission_i: in  regNPort;
   testLink_o:       out regNport;
   credit_o:         out regNport;
   clock_tx:         out regNport;
   tx:               out regNport;
   data_out:         out arrayNport_regphit;
   retransmission_o: out regNPort);
end RouterCC;

architecture RouterCC of RouterCC is

signal h, ack_h, data_av, sender, data_ack: regNport := (others=>'0');
signal data: arrayNport_regflit := (others=>(others=>'0'));
signal mux_in, mux_out: arrayNport_reg3 := (others=>(others=>'0'));
signal free: regNport := (others=>'0');
signal retransmission_in_buf: regNport := (others=>'0');
signal retransmission_out: regNPort:= (others=>'0'); -- sinal que solicita retransmissao do flit, pois o Decoder nao conseguiu arrumar o erro

------------New Hardware------------
signal c_ctrl : std_logic;
signal c_CodControle : regflit;
signal c_BuffCtrl : buffControl;
signal c_ceTR : std_logic; --[c_ce][T]abela[R]oteamento
signal c_ceTF : regNport := (others=>'0'); --[c_ce][T]abela[F]alhas
signal c_BuffTabelaFalhas : row_FaultTable_Nport_Ports := (others=>(others=>(others=>'0')));
signal c_erro_ArrayFind : ArrayRouterControl;
signal c_erro_dir : regNport;
signal c_tabela_falhas: row_FaultTable_Ports;
signal c_test_link_out: regNport;
signal c_data_test: regFlit;
signal credit_i_A : regNport;
signal credit_o_A : regNport;
signal data_out_A : arrayNport_regflit;
signal c_stpLinkTst : regNport;
signal c_strLinkTst : regNport;
signal c_faultTableFDM : regNport;
signal c_strLinkTstOthers : regNport := (others=>'0');
signal c_strLinkTstAll: std_logic := '0';

-- sinais do FPPM
signal row_FaultTablePorts_out: row_FaultTable_Ports := (others=>(others=>'0')); -- linha a ser escrita na tabela de falhas
signal write_FaultTable: regHamm_Nport := (others=>'0'); -- sinal para indicar escrita na tabela de falhas
signal statusHamming: array_statusHamming; --  status da decodificacao (sem erro, erro corrigido, erro detectado)

-- sinais para o Hamming Code
-- saida (Encode)
signal dataOutHamming: arrayNport_regphit; -- dado de saida codificado (dado + paridade)
signal data_out_B: arrayNport_regflit; -- dado de saida

-- entrada (Decode)
signal parity_dataOutHamming: arrayNport_reghamm; -- paridade do dado de saida
signal dataInHamming: arrayNport_regflit; -- dado de entrada (sem paridade)
signal parity_dataInHamming: arrayNport_reghamm; -- paridade de entrada
signal dataDecoded: arrayNport_regflit; -- dado corrigido
signal parityDecoded: arrayNport_reghamm; -- paridade corrigida
signal statusDecoded: arrayNport_reg3; --  status da decodificacao (sem erro, erro corrigido, erro detectado)

signal aux_tx: regNport;

begin
   tx <= aux_tx;

   dataDecoded(LOCAL) <= data_in(LOCAL)(TAM_PHIT-1 downto TAM_HAMM); -- nao tem Hamming nos links locais
   parityDecoded(LOCAL) <= (others=>'0'); -- nao tem Hamming nos links locais
   statusDecoded(LOCAL) <= (others=>'0');
   parity_dataOutHamming(LOCAL) <= (others=>'0');

   FPPM_cast: for i in 0 to HAMM_NPORT-1 generate
   begin
      statusHamming(i) <= statusDecoded(i);
   end generate;

   retransmission_o <= retransmission_out;
   retransmission_out(LOCAL) <= '0';

   HammingData: for i in 0 to NPORT-1 generate
   begin
      dataOutHamming(i) <= data_out_B(i) & parity_dataOutHamming(i);
      dataInHamming(i) <= data_in(i)(TAM_PHIT-1 downto TAM_HAMM);
      parity_dataInHamming(i) <= data_in(i)(TAM_HAMM-1 downto 0);
   end generate;

   -- manda testLink_o = '1' para todas portas de saida QUANDO algum buffer detectar pacote de controle do tipo TEST_LINKS
   testLink_o <= (others=>'1') when c_strLinkTst /= x"0"
         else (others=>'0');

   -- manda aos buffers c_strLinkTstOthers = '1' QUANDO receber de algum roteador vizinho pedir para testar o link
   c_strLinkTstOthers <= (others=>'1') when testLink_i /= x"0"
         else (others=>'0');

    Faulter : Entity work.FaultInjector
    generic map(address => address)
    port map(
        clock => clock,
        reset => reset,
        tx => aux_tx,
        restransmit => retransmission_i,
        data_in => dataOutHamming,
        data_out => data_out,
        credit => credit_i
    );

    InputBuffers : for i in EAST to (LOCAL-1) generate
        IB : entity work.Phoenix_buffer
        generic map(
            address => address,
            bufLocation => i
        )
        port map(
            clock => clock,
            reset => reset,
            data_in => dataDecoded(i),
            rx => rx(i),
            h => h(i), -- requisicao de chaveamento
            c_buffCtrlFalha => c_BuffTabelaFalhas(i), -- tabela de falhas lida do pacote de controle que solicitou escrever/atualizar a tabela
            c_ceTF_out => c_ceTF(i), -- ce (chip enable) para escrever/atualizar a tabela de falhas
            c_error_Find => c_erro_ArrayFind(i), -- indica se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
            c_error_dir => c_erro_dir, -- indica qual destino/porta de saida o pacote sera encaminhado
            c_tabelaFalhas => c_tabela_falhas, -- tabela de falhas atualizada/final
            c_strLinkTst => c_strLinkTst(i), -- (start link test) indica que houve um pacote de controle do tipo TEST_LINKS para testar os links.q
            c_stpLinkTst => c_stpLinkTst(i), -- (stop link test) indica o fim do teste do link
            c_strLinkTstOthers => c_strLinkTstOthers(i), -- indica se algum vizinho pediu para testar o link
            c_strLinkTstNeighbor => testLink_i(i), -- indica se o vizinho pediu para testar o link
            c_strLinkTstAll => c_strLinkTstAll, -- se algum buffer fez o pedido de teste de link
            ack_h => ack_h(i), -- resposta da requisicao de chaveamento
            data_av => data_av(i),
            data => data(i),
            sender => sender(i),
            clock_rx => clock_rx(i),
            data_ack => data_ack(i),
            credit_o => credit_o_A(i),
            retransmission_in => retransmission_in_buf(i),
            retransmission_out => retransmission_out(i),
            statusHamming => statusHamming(i)
        );
    end generate InputBuffers;

    LocalBuffer : Entity work.Phoenix_buffer
    generic map(
        address => address,
        bufLocation => LOCAL
    )
    port map(
        clock => clock,
        reset => reset,
        data_in => dataDecoded(LOCAL),
        rx => rx(LOCAL),
        h => h(LOCAL),
        c_ctrl=> c_ctrl, -- (exclusivo do buffer local) indica se foi lido ou criado de um pacote de controle pelo buffer
        c_buffCtrlOut=> c_BuffCtrl, -- (exclusivo do buffer local) linha da tabela de roteamento lida do pacote de controle que sera escrita na tabela de roteamento
        c_codigoCtrl=> c_CodControle, -- (exclusivo do buffer local) codigo de controle do pacote de controle (terceiro flit do pacote de controle)
        c_chipETable => c_ceTR, -- (exclusivo do buffer local) chip enable da tabela de roteamento
        c_buffCtrlFalha => c_BuffTabelaFalhas(LOCAL),
        c_ceTF_out => c_ceTF(LOCAL),
        c_error_Find => c_erro_ArrayFind(LOCAL),
        c_error_dir => c_erro_dir,
        c_tabelaFalhas => c_tabela_falhas,
        c_strLinkTst => c_strLinkTst(LOCAL),
        c_stpLinkTst => c_stpLinkTst(LOCAL),
        c_strLinkTstOthers => c_strLinkTstOthers(LOCAL),
        c_strLinkTstNeighbor => testLink_i(LOCAL),
        c_strLinkTstAll => c_strLinkTstAll,
        ack_h => ack_h(LOCAL),
        data_av => data_av(LOCAL),
        data => data(LOCAL),
        sender => sender(LOCAL),
        clock_rx => clock_rx(LOCAL),
        data_ack => data_ack(LOCAL),
        credit_o => credit_o_A(LOCAL),
        retransmission_in => retransmission_in_buf(LOCAL),
        retransmission_out => retransmission_out(LOCAL),
        statusHamming => (others=>'0')
    );

   FaultDetection: Entity work.FaultDetection
   port map(
      clock => clock,
      reset => reset,
      c_strLinkTst => c_strLinkTst, -- (start link test) indica que houve um pacote de controle do tipo TEST_LINKS para testar os links
      c_strLinkTstAll => c_strLinkTstAll, -- se algum buffer fez o pedido de teste de links
      c_stpLinkTst => c_stpLinkTst, -- (stop link test) indica o fim do teste dos links
      test_link_inA => testLink_i, -- sinal testLink_i dos roteadores vizinhos que indica teste de link (desta maneira o roteador sabe que precisa revolver o dado recebido durante o teste do link)
      data_outA => data_out_A, -- data_out normal. Dado que sera encaminhado para as portas de saida, caso nao esteja em teste
      data_inA => dataDecoded, -- dado(flit) recebido nas portas de entrada dos buffers
      credit_inA => credit_i,
      credit_outA => credit_o_A,
      data_outB => data_out_B, -- dado que sera encaminhado para as portas de saida (pode ser encaminhado data_out normal ou dados para teste de link)
      credit_inB => credit_i_A,
      c_faultTableFDM => c_faultTableFDM, -- tabela de falhas ('0' indica sem falha, '1' indica falha)
      credit_outB =>credit_o);


   SwitchControl : Entity work.SwitchControl
   generic map(address => address)
   port map(
      clock => clock,
      reset => reset,
      h => h, -- solicitacoes de chaveamento
      ack_h => ack_h, -- resposta para as solitacoes de chaveamento
      data => data, -- dado do buffer (contem o endereco destino)
      c_Ctrl => c_ctrl, -- indica se foi lido ou criado de um pacote de controle pelo buffer
      c_buffTabelaFalhas_in=> c_BuffTabelaFalhas, -- tabela de falhas recebida no roteador por um pacote de controle do tipo WR_FAULT_TABLE
      c_CodControle => c_CodControle, -- codigo de controle do pacote de controle (terceiro flit do pacote de controle)
      c_BuffCtrl => c_BuffCtrl, -- linha da tabela de roteamento lida do pacote de controle que sera escrita na tabela de roteamento
      c_ce => c_ceTR, -- chip enable da tabela de roteamento. Indica que sera escrito na tabela de roteamento
      c_ceTF_in => c_ceTF, -- ce (chip enable) para escrever/atualizar a tabela de falhas
      c_error_ArrayFind => c_erro_ArrayFind, -- indica se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
      c_error_dir => c_erro_dir, -- indica qual porta de saida o pacote sera encaminhado
      c_tabelaFalhas => c_tabela_falhas, -- tabela de falhas atualizada/final
      c_strLinkTst => c_strLinkTst, -- (start link test) indica que houve um pacote de controle do tipo TEST_LINKS para testar os links
      c_faultTableFDM => c_faultTableFDM, -- tabela de falhas gerado pelo teste de links
      sender => sender,
      free => free, -- portas de saida que estao livres
      mux_in => mux_in,
      mux_out => mux_out,
      row_FaultTablePorts_in => row_FaultTablePorts_out, -- linhas a serem escritas na tabela (do FFPM)
      write_FaultTable => write_FaultTable); -- sinal para indicar escrita na tabela (do FPPM)

   CrossBar : Entity work.Phoenix_crossbar
   port map(
      data_av => data_av,
      data_in => data,
      data_ack => data_ack,
      sender => sender,
      free => free,
      tab_in => mux_in,
      tab_out => mux_out,
      tx => aux_tx,
      data_out => data_out_A,
      credit_i => credit_i_A,
      retransmission_i => retransmission_i,
      retransmission_in_buf => retransmission_in_buf);

   FPPM: Entity work.FPPM
    port map(
        clock => clock,
        reset_in => reset,
        rx => rx((HAMM_NPORT-1) downto 0),
        statusHamming => statusHamming,
        write_FaultTable => write_FaultTable,
        row_FaultTablePorts_out => row_FaultTablePorts_out);

    HammingEncode : for i in EAST to LOCAL-1 generate
        HE: entity work.HAM_ENC
        port map(
            data_in => data_out_B(i),
            data_out => parity_dataOutHamming(i)
        );
    end generate HammingEncode;

    HammingDecode : for i in EAST to LOCAL-1 generate
        HD : entity work.HAM_DEC
        port map(
            data_in => dataInHamming(i),
            parity_in => parity_dataInHamming(i),
            data_out => dataDecoded(i),
            parity_out => parityDecoded(i),
            credit_out => statusDecoded(i)
        );
    end generate HammingDecode;

   CLK_TX : for i in 0 to(NPORT-1) generate
      clock_tx(i) <= clock;
   end generate CLK_TX;

end RouterCC;