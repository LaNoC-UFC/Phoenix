---------------------------------------------------------------------------------------
--                            BUFFER
--                        --------------
--                   RX ->|            |-> H
--              DATA_IN ->|            |<- ACK_H
--             CLOCK_RX ->|            |
--             CREDIT_O <-|            |-> DATA_AV
--                        |            |-> DATA
--                        |            |<- DATA_ACK
--                        |            |
--                        |            |
--                        |            |=> SENDER
--                        |            |   all ports
--                        --------------
--
--  Quando o algoritmo de chaveamento resulta no bloqueio dos flits de um pacote,
--  ocorre uma perda de desempenho em toda rede de interconexao, porque os flits sao
--  bloqueados nao somente na chave atual, mas em todas as intermediarias.
--  Para diminuir a perda de desempenho foi adicionada uma fila em cada porta de
--  entrada da chave, reduzindo as chaves afetadas com o bloqueio dos flits de um
--  pacote. E importante observar que quanto maior for o tamanho da fila menor sera o
--  numero de chaves intermediarias afetadas.
--  As filas usadas contem dimensao e largura de flit parametrizaveis, para altera-las
--  modifique as constantes TAM_BUFFER e TAM_FLIT no arquivo "Phoenix_packet.vhd".
--  As filas funcionam como FIFOs circulares. Cada fila possui dois ponteiros: first e
--  last. First aponta para a posicao da fila onde se encontra o flit a ser consumido.
--  Last aponta para a posicao onde deve ser inserido o proximo flit.
---------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.PhoenixPackage.all;
use work.HammingPack16.all;
use ieee.std_logic_arith.CONV_STD_LOGIC_VECTOR;
use STD.textio.all;

-- interface da Phoenix_buffer
entity Phoenix_buffer is
   generic(address : regflit := (others=>'0');
      bufLocation: integer := 0);
port(
   clock:      in  std_logic;
   reset:      in  std_logic;
   clock_rx:   in  std_logic;
   rx:         in  std_logic;
   data_in:    in  regflit;
   credit_o:   out std_logic;
   h:          out std_logic; -- requisicao de chaveamento
   c_ctrl:         out std_logic; -- indica se foi lido ou criado de um pacote de controle pelo buffer
   c_buffCtrlOut:out buffControl; -- linha da tabela de roteamento lida do pacote de controle que sera escrita na tabela de roteamento
   c_buffCtrlFalha:out row_FaultTable_Ports; -- tabela de falhas lida do pacote de controle que solicitou escrever/atualizar a tabela
   c_codigoCtrl:   out regFlit; -- tipo do pacote de controle (leitura do Code). Terceiro flit do pacote de controle
   c_chipETable: out std_logic;  -- chip enable da tabela de roteamento
   c_ceTF_out: out std_logic; -- ce (chip enable) para escrever/atualizar a tabela de falhas
   c_error_find: in RouterControl; -- indica se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
   c_error_dir : in regNport; -- indica qual destino/porta de saida o pacote sera encaminhado
   c_tabelaFalhas :in row_FaultTable_Ports; -- tabela de falhas atualizada/final
   ack_h:      in  std_logic; -- resposta da requisicao de chaveamento
   data_av:    out std_logic;
   data:       out regflit;
   data_ack:   in  std_logic;
   sender:     out std_logic;
   c_strLinkTst: out std_logic;   -- (start link test) indica que houve um pacote de controle do tipo TEST_LINKS para testar os links. Comentario antigo: send to router (testa as falhas)
   c_strLinkTstOthers: in std_logic; -- indica se algum vizinho pediu para testar o link
   c_strLinkTstNeighbor: in std_logic; -- indica se o vizinho pediu para testar o link
   c_strLinkTstAll: in std_logic; -- se algum buffer fez o pedido de teste de links
   c_stpLinkTst: in std_logic; -- (stop link test) indica se algum vizinho pediu para testar o link. Gerado pelo FaultDetection
   retransmission_in: in std_logic;
   retransmission_out: out std_logic;
   statusHamming: in reg3);
end Phoenix_buffer;

architecture Phoenix_buffer of Phoenix_buffer is

type fila_out is (S_INIT, S_PAYLOAD, S_SENDHEADER, S_HEADER, S_END, S_END2,C_PAYLOAD,C_SIZE);
signal EA : fila_out;

signal buf: buff := (others=>(others=>'0'));
signal first,last: pointer := (others=>'0');
signal tem_espaco: std_logic := '0';
signal counter_flit: regflit := (others=>'0');

signal eh_controle : std_logic := '0';
signal buffCtrl : buffControl := (others=>(others=>'0'));  -- XY | XY | DIR
signal codigoControl : regflit:= (others=>'0');
signal buffCtrlFalha : row_FaultTable_Ports := (others=>(others=>'0'));
signal ceTF_out : std_logic := '0';

signal c_error : std_logic := '0'; -- '0' sem erro para o destino, '1' com erro para o destino
signal c_direcao: regNport :=(others=>'0'); -- registrador com a direcao que esta mandando o pacote
signal c_createmessage : std_logic := '0'; -- sinal usado para criar um pacote de controle com a tabela de falhas
signal c_Buffer : regflit := (others=>'0'); -- dado de saida gerado ao criar um pacote de controle (pacote de resposta eh criado quando eh pedido leitura da tabela de falhas)
signal c_strLinkTstLocal : std_logic := '0'; -- sinal do pedido de inicio de teste de links
signal old_tabelaFalhas : regNport :=(others=>'0'); -- antiga tabela e falhas com 1 bit para cada porta. '0' indica sem falha, '1' indica com falha

signal discard: std_logic := '0'; -- sinal que indica para voltar a maquina de estados (usada para envio do pacote) para votlar a o estado inicial, pois o pacote sera descartado
signal last_retransmission: regflit := (others=>'0');
signal counter_flit_up: regflit := (others=>'0');
signal last_count_rx: regflit := (others=>'0');
signal retransmission_o: std_logic := '0';
signal pkt_size: regflit := (others=>'0');


begin

   retransmission_out <= retransmission_o;

   old_tabelaFalhas(LOCAL) <= '0';
   old_tabelaFalhas(EAST) <= c_tabelafalhas(EAST)(3*COUNTERS_SIZE+1);
   old_tabelaFalhas(WEST) <= c_tabelafalhas(WEST)(3*COUNTERS_SIZE+1);
   old_tabelaFalhas(NORTH) <= c_tabelafalhas(NORTH)(3*COUNTERS_SIZE+1);
   old_tabelaFalhas(SOUTH) <= c_tabelafalhas(SOUTH)(3*COUNTERS_SIZE+1);

   -- sinal indica se tem falha no link destino
   c_error <= '1' when (c_direcao and old_tabelafalhas) /= 0 else '0';

   -------------------------------------------------------------------------------------------
   -- ENTRADA DE DADOS NA FILA
   -------------------------------------------------------------------------------------------

   -- Verifica se existe espaco na fila para armazenamento de flits.
   -- Se existe espaco na fila o sinal tem_espaco_na_fila eh igual a 1.
   process(reset, clock_rx)
   begin
      if reset = '1' then
         tem_espaco <= '1';
      elsif clock_rx'event and clock_rx = '1' then
         if not ((first = x"0" and last = TAM_BUFFER - 1) or (first = last + 1)) then
            tem_espaco <= '1';
         else
            tem_espaco <= '0';
         end if;
      end if;
   end process;

   credit_o <= tem_espaco;

   -- O ponteiro last eh inicializado com o valor zero quando o reset eh ativado.
   -- Quando o sinal rx eh ativado indicando que existe um flit na porta de entrada. Eh
   -- verificado se existe espaco na fila para armazena-lo. Se existir espaco na fila o
   -- flit recebido eh armazenado na posicao apontada pelo ponteiro last e o mesmo eh
   -- incrementado. Quando last atingir o tamanho da fila, ele recebe zero.
   process(reset, clock_rx)
      variable count: integer;
      variable ignore: std_logic := '0';
      variable pkt_received: std_logic := '0';

      file my_output : TEXT open WRITE_MODE is "retransmission_00"&to_hstring(address)&".txt";
      variable my_output_line : LINE;
      variable count_retx: integer;
      variable total_count_retx: regflit;
   begin
      if reset = '1' then
         last <= (others=>'0');
         count := 0;
         ignore := '0';
         discard <= '0';
         last_count_rx <= (others=>'0');
         pkt_size <= (others=>'0');
         pkt_received := '1';

      elsif clock_rx'event and clock_rx = '0' then
         if (rx = '0' and (pkt_received='1' or ignore='1')) then
            count := 0;
            ignore := '0';
            discard <= '0';
            last_count_rx <= (others=>'1');
            pkt_received := '0';
            pkt_size <= (others=>'0');
            count_retx := 0;
         end if;

         -- se tenho espaco e se tem alguem enviando, armazena, mas
         -- nao queremos armazenar os flits recebidos durante o teste de link, entao
         -- se meu roteador esta testando os links ou se o link ligado a este buffer esta sendo testando pelo vizinho, irei ignorar os flits durante o teste
         -- o buffer local que eh conectado ao link local (assumido que nunca falha) nunca sera testado
         if tem_espaco = '1' and rx = '1' and ((c_strLinkTstAll = '0' and c_strLinkTstNeighbor='0') or bufLocation = LOCAL) then

            -- "ignore" eh um auxiliar usado para indicar que estou ignorando os flits que estao chegando, pois
            -- o pacote foi descartado. O descarte eh feito ao descartar os flits que ja chegaram (voltando o ponteiro de maneira que possa sobreescrever os flits ja recebidos) e
            -- ignorando os flits subsequentes.
            if (ignore = '0') then

               -- se nao deu erro, esta tudo normal. Posso armazenar o flit no buffer e incrementar o ponteiro
               if (statusHamming /= ED) then
                  retransmission_o <= '0';
                  -- modifica o ultimo flit do pacote para armazenar o numero de retransmissoes
                  if (count = pkt_size+1 and pkt_size > 0) then
                     total_count_retx := data_in;
                     total_count_retx := total_count_retx + count_retx;
                     buf(CONV_INTEGER(last)) <= total_count_retx;
                  else
                     buf(CONV_INTEGER(last)) <= data_in; -- armazena o flit
                  end if;

                  if (count = 1) then
                     pkt_size <= data_in;
                  end if;

                  --incrementa o last
                  if last = TAM_BUFFER - 1 then
                    last <= (others=>'0');
                  else
                    last <= last + 1;
                  end if;

                  count := count + 1;

               -- detectado erro e nao corrigido. Posso tentar mais uma vez pedindo retransmissao...
               else
                  count_retx := count_retx + 1;
                  last_count_rx <= CONV_STD_LOGIC_VECTOR(count,TAM_FLIT);

                  -- desiste se deu erro duas vezes no mesmo flit
                  if (last_count_rx = count and count /= 1) then
                     retransmission_o <= '0';
                     buf(CONV_INTEGER(last)) <= data_in; -- armazena o flit (mesmo com falha)
                     --incrementa o last
                     if last = TAM_BUFFER - 1 then
                       last <= (others=>'0');
                     else
                       last <= last + 1;
                     end if;

                     count := count + 1;
                  else
                     retransmission_o <= '1';
                  end if;
               end if;

               -- se estou no segundo flit recebido e, mesmo depois de pedir retransmissao dele, veio com falha
               if (count = 1 and statusHamming = ED and last_count_rx = 1) then

                  ignore := '1';
                  retransmission_o <= '0';

                  -- volta uma posicao o ponteiro last e sinaliza com discard em '1' para reiniciar a maquina de estados que
                  -- ja estava iniciando o envio do pacote
                  if (last = 0) then
                     last <= CONV_STD_LOGIC_VECTOR(TAM_BUFFER-1, TAM_POINTER);
                     if (first = TAM_BUFFER - 1) then
                        discard <= '1';
                     else
                        discard <= '0';
                     end if;
                  else
                     last <= last - 1;
                     if (first = last-1) then
                        discard <= '1';
                     else
                        discard <= '0';
                     end if;
                  end if;

               end if; -- end if do if (count = 1...

               if (count = pkt_size+2 and pkt_size > 0) then
                  pkt_received := '1';

                  if (bufLocation /= LOCAL) then
                     write(my_output_line, "Packet in port "&PORT_NAME(bufLocation)&" received "&integer'image(count_retx)&" flits with double error "&time'image(now));
                     writeline(my_output, my_output_line);
                  end if;
               else
                  pkt_received := '0';
               end if;

            -- deixar so um ciclo o discard em '1'
            else
               discard <= '0';
            end if;
         end if;
      end if;
   end process;
   -------------------------------------------------------------------------------------------
   -- SAIDA DE DADOS NA FILA
   -------------------------------------------------------------------------------------------

   -- disponibiliza o dado para transmissao. Se nao estiver criando um pacote de controle, envia normalmente o dado do buffer, caso contrario envia dado criado (c_buffer)
   data <= buf(CONV_INTEGER(first)) when c_createmessage ='0' else c_Buffer;

   -- Quando sinal reset eh ativado a maquina de estados avanca para o estado S_INIT.
   -- No estado S_INIT os sinais counter_flit (contador de flits do corpo do pacote), h (que
   -- indica requisicao de chaveamento) e data_av (que indica a existencia de flit a ser
   -- transmitido) sao inicializados com zero. Se existir algum flit na fila, ou seja, os
   -- ponteiros first e last apontarem para posicoes diferentes, a maquina de estados avanca
   -- para o estado S_HEADER.
   -- No estado S_HEADER eh requisitado o chaveamento (h='1'), porque o flit na posicao
   -- apontada pelo ponteiro first, quando a maquina encontra-se nesse estado, eh sempre o
   -- header do pacote. A maquina permanece neste estado ate que receba a confirmacao do
   -- chaveamento (ack_h='1') entao o sinal h recebe o valor zero e a maquina avanca para
   -- S_SENDHEADER.
   -- Em S_SENDHEADER eh indicado que existe um flit a ser transmitido (data_av='1'). A maquina de
   -- estados permanece em S_SENDHEADER ate receber a confirmacao da transmissao (data_ack='1')
   -- entao o ponteiro first aponta para o segundo flit do pacote e avanca para o estado S_PAYLOAD.
   -- No estado S_PAYLOAD eh indicado que existe um flit a ser transmitido (data_av='1') quando
   -- eh recebida a confirmacao da transmissao (data_ack='1') eh verificado qual o valor do sinal
   -- counter_flit. Se counter_flit eh igual a um, a maquina avanca para o estado S_INIT. Caso
   -- counter_flit seja igual a zero, o sinal counter_flit eh inicializado com o valor do flit, pois
   -- este ao numero de flits do corpo do pacote. Caso counter_flit seja diferente de um e de zero
   -- o mesmo eh decrementado e a maquina de estados permanece em S_PAYLOAD enviando o proximo flit
   -- do pacote.
   process(reset, clock)
      variable indexFlitCtrl: integer :=0;
      variable varControlCom: integer :=1; -- variavel de comando, para fazer as iteracoes
   begin
      if reset = '1' then
         counter_flit <= (others=>'0');
         counter_flit_up <= (others=>'0');
         h <= '0';
         data_av <= '0';
         sender <=  '0';
         first <= (others=>'0');
         eh_controle <= '0';
         c_chipETable <= '0';
         EA <= S_INIT;
      elsif clock'event and clock = '1' then
         case EA is
            when S_INIT =>
               c_chipETable <= '0'; -- desabilita escrita na tabela de roteamento
               counter_flit <= (others=>'0');
               counter_flit_up <= (others=>'0');
               data_av <= '0';
               eh_controle <= '0';
               last_retransmission <= (others=>'0');

               -- se existe dados no buffer a serem transmitidos (por causa dos ponteiros first e last diferentes) OU se devo criar um pacote de controle com a  tabela de falhas
               if first /= last or c_createmessage = '1' then

                  -- se o primeiro flit do pacote a ser transmitido possui o bit indicando que eh um pacote de controle E se nesse primeiro flit possui o endereco do roteador em que o buffer se encontra
                  -- OU se devo criar um pacote de controle com a tabela de falhas (este pacote eh criado se for pedido a leitura da tabela de falhas)
                  if((buf(CONV_INTEGER(first))(TAM_FLIT-1)='1') and (buf(CONV_INTEGER(first))((TAM_FLIT-2) downto 0)=address((TAM_FLIT-2) downto 0))) or c_createmessage = '1' then -- PACOTE DE CONTROLE

                     -- se preciso criar um pacote com a tabela de falhas. Comentario antigo: o pacote de controle pare este roteador
                     if c_createmessage = '1' then

                        -- se ultimo pacote de controle recebido foi de leitura da tabela de falhas
                        if codigoControl = c_RD_FAULT_TAB_STEP1 then
                           c_Buffer <=  '1' & address((TAM_FLIT-2) downto 0); -- entao crio o primeiro flit do pacote que vai conter a tabela de falhas
                           h <= '1';         -- requisicao de chaveamento (chavear os dados de entrada para a porta de saida atraves da crossbar)
                           EA <= S_HEADER;   -- maquina de estados avanca para o estado S_HEADER
                           eh_controle <= '1'; -- indica que o pacote lido/criado eh de controle
                           c_direcao <= "10000"; --direcao para a saida Local
                        end if;

                     -- nao irei criar pacote de controle com a tabela de falhas, irei apenas transmitir o pacote do buffer
                     else
                        -- incrementa ponteiro first (ponteiro usado para envio)
                        -- nao preciso tratar erro detectado aqui, pq em ED o flit eh igual a zero, logo nao sera pacote de controle
                        if first = TAM_BUFFER - 1 then
                           first <= (others=>'0');
                        else
                           first <= first + 1;
                        end if;

                        EA <= C_SIZE; -- maquina de estados avanca para o estado S_SIZE (estado onde eh lido o tamanho do pacote)
                        eh_controle <= '1'; -- indica que o pacote lido/criado eh de controle
                        c_direcao <= "10000"; -- direcao para o a saida Local
                     end if;

                  -- tenho dados para enviar e nao sao de controle (apenas pacote de dados)
                  else
                    h <= '1';         -- requisicao de chaveamento (chavear os dados de entrada para a porta de saida atraves da crossbar)
                    EA <= S_HEADER;   -- maquina de estados avanca para o estado S_HEADER
                  end if;

               -- entao nao tenho dados no buffer para enviar nem preciso criar um pacote de controle
               else
                  h <= '0'; -- nao pede/solicita chaveamento pq nao preciso enviar nada
               end if;


            when S_HEADER =>

               -- se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
               if (c_error_find = validRegion) then
                  c_direcao <= c_error_dir; -- direcao/porta de saida da tabela de roteamento
               end if;

               if (discard = '1') then
                  h <= '0';
                  EA <= S_INIT;
               end if;

               -- atendido/confirmado a requisicao de chaveamento OU se link destino tiver falhar
               if ack_h = '1' or c_error = '1' then
                  EA <= S_SENDHEADER;
                  h <= '0'; -- nao preciso mais solicitar o chaveamento pq ele foi ja foi atendido :)
                  data_av <= '1'; -- data available (usado para indicar que exite flit a ser transmitido)
                  sender <= '1'; -- usado para indicar que esta transmitindo (por este sinal sabemos quando termina a transmissao e a porta destino desocupa)
               end if;

            when S_SENDHEADER  =>
               -- se recebeu confirmacao de dado recebido OU o link destino esta com falha
               if data_ack = '1' or c_error = '1' then

                  -- incrementa pointeiro first (usado para transmitir flit) e sinaliza que tem dado disponivel
                  if c_createmessage = '0' then

                     -- se receptor nao pediu retransmissao, continua enviando
                     if (retransmission_in='0') then

                        EA <= S_PAYLOAD;
                        if first = TAM_BUFFER - 1 then
                           first <= (others=>'0');
                           if last /= 0 then   data_av <= '1';
                           else data_av <= '0';
                           end if;
                        else
                           first <= first + 1;
                           if first + 1 /= last then data_av <= '1';
                           else data_av <= '0';
                           end if;
                        end if;

                     -- solicitou reenvio do pacote, logo ponteiro nao sera incrementado e dado sera enviado novamente
                     else
                        last_retransmission <= (0=>'1', others=>'0'); -- 1
                        --assert last_retransmission /= 1 report "sender detectou que nao conseguiu transmitir flit correto. Pacote descartado. Flit "&integer'image(CONV_INTEGER(last_retransmission));
                     end if;


                  -- irei criar um pacote de controle com a tabela de falhas
                  else
                     -- se ultimo pacote de controle recebido foi pedido de leitura da tabela de falhas
                     if codigoControl = c_RD_FAULT_TAB_STEP1 then
                        counter_flit <= x"000A"; -- 10 flits de payload (code + origem + tabela)
                        c_Buffer <= x"000A"; -- segundo flit do pacote de controle criado (tamanho de pacote)
                        EA <= C_PAYLOAD;
                        indexFlitCtrl := 0;
                        varControlCom  := 10;
                     end if;
                  end if;
               end if;

            when S_PAYLOAD =>
               -- se tiver que retransmitir, nao incrementa ponteiro first
               if (( data_ack = '1' or c_error = '1') and retransmission_in = '1') then
                  if (counter_flit = 0) then
                     last_retransmission <= (1=>'1', others=>'0'); -- 2
                     --assert last_retransmission /= 2 report "sender detectou que nao conseguiu transmitir flit correto. Pacote descartado. Flit "&integer'image(CONV_INTEGER(last_retransmission));
                  else
                     last_retransmission <= counter_flit_up;
                     --assert last_retransmission /= counter_flit_up report "sender detectou que nao conseguiu transmitir flit correto. Pacote descartado. Flit "&integer'image(CONV_INTEGER(last_retransmission));
                  end if;

               -- se nao eh o ultimo flit do pacote E se foi confirmado que foi recebido com sucesso o dado transmitido OU o link destino esta com falha. Comentario antigo: confirmacao do envio de um dado que nao eh o tail
               elsif counter_flit /= x"1" and ( data_ack = '1' or c_error = '1') then

                  -- se counter_flit eh zero indica que terei que receber o size do payload
                  if counter_flit = x"0" then
                     counter_flit <=  buf(CONV_INTEGER(first));
                     counter_flit_up <= (1=>'1', others=>'0'); -- 2
                  else
                     counter_flit <= counter_flit - 1;
                     counter_flit_up <= counter_flit_up + 1;
                  end if;

                  -- incrementa pointeiro first (usado para transmitir flit) e sinaliza que tem dado disponivel
                  if first = TAM_BUFFER - 1 then
                     first <= (others=>'0');
                     if last /= 0 then
                        data_av <= '1'; -- (data available)
                     else
                        data_av <= '0';
                     end if;
                  else
                     first <= first + 1;
                     if first + 1 /= last then
                        data_av <= '1';
                     else
                        data_av <= '0';
                     end if;
                  end if;

               -- se eh o ultimo flit do pacote E se foi confirmado que foi recebido com sucesso o dado transmitido OU o link destino esta com falha. Comentario antigo: confirmacao do envio do tail
               elsif counter_flit = x"1" and (data_ack = '1' or c_error = '1') then
                  -- Incrementa pointeiro de envio. Comentario antigo: retira um dado do buffer
                  if first = TAM_BUFFER - 1 then
                     first <= (others=>'0');
                  else
                     first <= first + 1;
                  end if;
                  data_av <= '0'; -- como o ultimo flit sera enviado, nao tem mais dados disponiveis
                  sender <= '0'; -- como o ultimo flit sera enviado, nao preciso sinalizar que estou enviando dados
                  EA <= S_END; -- -- como o ultimo flit sera enviado, posso ir para o estado S_END

               -- se tem dado a ser enviado, sinaliza
               elsif first /= last then
                  data_av <= '1'; -- (data available)
               end if;

            when C_SIZE =>
               -- detectou dado na fila (tem dados a serem enviados no buffer)   e nao pediu retransmissao
               if (first /= last and retransmission_o='0') then
                  counter_flit <= buf(CONV_INTEGER(first)); -- leitura do segundo flit (tamanho do pacote)

                  -- incrementa o pointeiro first (pointeiro usado para envio)
                  if first = TAM_BUFFER - 1 then
                     first <= (others=>'0');
                  else
                     first <= first + 1;
                  end if;
                  EA <= C_PAYLOAD;
                  indexFlitCtrl := 0;   -- coloca o indice do flit de controle igual 0 (esse indice eh usado para percorrer os flits de payload de controle). O indice igual a 0 representa o terceito flit do pacote e nele havera o Code (codigo que indica o tipo do pacote de controle)
                  varControlCom  := 1;  -- numero de flits no payload usados para processar o pacote de controle
               end if;

            when C_PAYLOAD =>

               c_chipETable <= '0'; -- desabilita escrita na tabela de roteamento

               if (first /= last) and indexFlitCtrl /= varControlCom and c_createmessage = '0' and retransmission_o='0' then

                  if first = TAM_BUFFER - 1 then
                     first <= (others=>'0');
                  else
                     first <= first + 1;
                  end if;

               end if;

               -- indice igual a zero, ou seja, primeiro flit do payload do pacote (onde possui o codigo do pacote de controle)
               if (indexFlitCtrl = 0 and retransmission_o='0') then
                        codigoControl <= buf(CONV_INTEGER(first)); -- leitura do tipo do pacote de controle (leitura do Code)
                        indexFlitCtrl := indexFlitCtrl + 1; -- incrementa o indice do payload que sera lido
                        counter_flit <= counter_flit - 1; -- decrementa o numero de flits que faltam a ser lidos/processados do pacote

                        -- define qual o tamanho da variavel de comando (tamanho do payload).
                        -- Pode ser entendido como o numero de flits no payload usados para processar o pacote de controle
                        if c_createmessage = '0' then
                           if(CONV_INTEGER(buf(CONV_INTEGER(first))) = c_WR_ROUT_TAB) then
                              varControlCom := 5;
                           elsif(CONV_INTEGER(buf(CONV_INTEGER(first))) = c_WR_FAULT_TAB) then
                              varControlCom := 9; -- code + tabela
                           elsif(CONV_INTEGER(buf(CONV_INTEGER(first))) = c_RD_FAULT_TAB_STEP1) then
                              varControlCom := 1;
                           elsif(CONV_INTEGER(buf(CONV_INTEGER(first))) = c_TEST_LINKS ) then
                              varControlCom := 1;
                           end if;

                        -- se c_createmessage='1', logo tenho que criar um pacote com a tabela de falhas para o OsPhoenix
                        else
                           -- se ultimo pacote de controle recebido foi pedido de leitura da tabela de falhas
                           if codigoControl = c_RD_FAULT_TAB_STEP1 then
                              varControlCom := 10; -- code + origem + tabela
                              codigoControl <= CONV_STD_LOGIC_VECTOR(c_RD_FAULT_TAB_STEP2, TAM_FLIT); -- atualiza codigo com c_RD_FAULT_TAB_STEP2
                              c_Buffer <= x"0004"; -- terceiro flit do pacote de controle criado que contem o tipo do pacote (code/codigo)
                           end if;
                        end if;

               -- escrita de linha na tabela de roteamento. Comentario antigo: codigo para atualizar tabela de roteamento.
               -- a linha do pacote de roteamento eh divida em 3 flits: o primeiro flit tem o XY do ponto inferior, o segundo flit tem o XY do ponto superior,
               -- o terceiro flit contem os 5 bits que indica a direcao/porta de saida dos pacotes conforme a regiao
               elsif (codigoControl = c_WR_ROUT_TAB and retransmission_o='0') then

                        -- terminou de processar todos os flits do pacote de controle
                        if indexFlitCtrl = 5 then
                           counter_flit <= counter_flit - 1;
                           if counter_flit = x"1" then
                              EA <= S_END;
                           end if;
                           c_chipETable <= '1'; -- habilita escrita na tabela de roteamento
                           indexFlitCtrl := 1;
                        else
                           buffCtrl(indexFlitCtrl-1) <= buf(CONV_INTEGER(first)); -- vai armazenando os dados lido do pacote de controle (o pacote tera uma linha da tabela de roteamento)

                           if (first /= last) then
                              if indexFlitCtrl /= 4 then
                                 counter_flit <= counter_flit - 1;
                              end if;
                              indexFlitCtrl := indexFlitCtrl + 1;
                           end if;

                           c_chipETable <= '0';
                        end if;

               -- escrita na tabela de falhas (irei ler a tabela recebido no pacote de controle). Comentario antigo: codigo para atualizar tabela de portas com falhas
               elsif (codigoControl = c_WR_FAULT_TAB and retransmission_o='0') then

                        case (indexFlitCtrl) is
                           when 1 => buffCtrlFalha(EAST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(EAST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                           when 2 => buffCtrlFalha(EAST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(EAST)((COUNTERS_SIZE-1) downto 0) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                           when 3 => buffCtrlFalha(WEST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(WEST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                           when 4 => buffCtrlFalha(WEST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(WEST)((COUNTERS_SIZE-1) downto 0) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                           when 5 => buffCtrlFalha(NORTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(NORTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                           when 6 => buffCtrlFalha(NORTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(NORTH)((COUNTERS_SIZE-1) downto 0) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                           when 7 => buffCtrlFalha(SOUTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(SOUTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                           when 8 => buffCtrlFalha(SOUTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= buf(CONV_INTEGER(first))((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(SOUTH)((COUNTERS_SIZE-1) downto 0) <= buf(CONV_INTEGER(first))(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                           when others => null;
                        end case;

                        if (first /= last) then
                           indexFlitCtrl := indexFlitCtrl + 1;
                           counter_flit <= counter_flit - 1;
                        end if;

                        -- ultimo flit?
                        if counter_flit = 0 then
                           ceTF_out <= '1'; -- habilita ce para escrever/atualizar a tabela de falhas
                           EA <= S_END;
                        end if;



               -- pedido de leitura da tabela de falhas
               elsif codigoControl = c_RD_FAULT_TAB_STEP1 then
                        --codigo requerindo a tabela de falhas
                        counter_flit <= counter_flit - 1;
                        EA <= S_INIT;
                        -- sinal usado para criar um pacote de controle com a tabela de falhas. Comentario antigo: envia msg para tabela
                        c_createmessage <= '1';

               -- resposta da leitura da tabela de falhas
               elsif codigoControl = c_RD_FAULT_TAB_STEP2 then

                         -- code complement. Comentario antigo: codigo para enviar a msg de falhas para o PE

                        if (data_ack = '1') then

                           case (indexFlitCtrl) is
                              when 1 => c_Buffer <= address; -- neste quarto flit havera o endereco do roteador

                              when 2 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-2) & c_TabelaFalhas(EAST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(EAST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                              when 3 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(EAST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(EAST)((COUNTERS_SIZE-1) downto 0);

                              when 4 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-2) & c_TabelaFalhas(WEST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(WEST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                              when 5 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(WEST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(WEST)((COUNTERS_SIZE-1) downto 0);

                              when 6 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-2) & c_TabelaFalhas(NORTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(NORTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                              when 7 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(NORTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(NORTH)((COUNTERS_SIZE-1) downto 0);

                              when 8 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-2) & c_TabelaFalhas(SOUTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(SOUTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                              when 9 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(SOUTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                   c_Buffer((METADEFLIT-1) downto 0) <= CONV_STD_LOGIC_VECTOR(0,METADEFLIT-COUNTERS_SIZE) & c_TabelaFalhas(SOUTH)((COUNTERS_SIZE-1) downto 0);

                              when others => null;
                           end case;

                           counter_flit <= counter_flit - 1; -- decrementa o numero de payloads que faltam processar
                           indexFlitCtrl := indexFlitCtrl + 1; -- incrementa o indice do payload

                        end if;

                        -- se enviou todos os flits
                        if counter_flit = x"0" then
                              c_createmessage <= '0'; -- nao preciso mais sinalizar para criar um pacote, pq ele ja foi criado e enviado :)
                              data_av <= '0'; -- ja enviei o pacote, entao nao tem mais dados disponiveis
                              sender <= '0'; -- ja enviei o pacote, nao preciso sinalizar que estou enviando
                              EA <= S_END;

                        -- se tem dado a ser enviado, sinalizado que existe dados disponiveis
                        else
                           data_av <= '1'; -- (data available)
                        end if;

               -- se o pacote gerado pelo OsPhoenix eh um pacote de controle do tipo TEST_LINKS.
               elsif codigoControl = c_TEST_LINKS then
                     -- pede para verificar os links aos vizinhos caso nenhum vizinho tenha pedido o teste de link. Comentario antigo: codigo para testar falhas e gravar na tabela de falhas do switchControl
                     -- SE nenhum vizinho pediu o teste de link ENTAO...
                     if c_strLinkTstOthers = '0' then
                        c_strLinkTstLocal <= '1'; -- pede para iniciar o teste de links
                     end if;

                     -- se terminou o teste de links
                     if c_stpLinkTst = '1' then
                        c_strLinkTstLocal <= '0'; -- nao preciso mais pedir para iniciar o teste de link pq ele ja acabou :)
                        EA <= S_END;
                     end if;
               end if;

            when S_END =>
               c_chipETable <= '0';
               ceTF_out <= '0';
               eh_controle <= '0';
               data_av <= '0';
               c_direcao <= (others=>'0');
               indexFlitCtrl := 0;
               EA <= S_END2;

            when S_END2 => -- estado necessario para permitir a liberacao da porta antes da solicitacao de novo envio
               data_av <= '0';
               EA <= S_INIT;
         end case;
      end if;
   end process;

   ------------New Hardware------------
   c_ctrl <= eh_controle;
   c_buffCtrlOut <= buffCtrl;
   c_codigoCtrl <= codigoControl;
   c_buffCtrlFalha <= buffCtrlFalha;
   c_ceTF_out <= ceTF_out;
   c_strLinkTst <= c_strLinkTstLocal;

end Phoenix_buffer;