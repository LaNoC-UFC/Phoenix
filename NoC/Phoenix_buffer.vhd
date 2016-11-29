library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
use work.HammingPack16.all;
use work.NoCPackage.all;

entity Phoenix_buffer is
    generic(
        address: regflit;
        bufLocation: integer
    );
    port(
        clock:      in  std_logic;
        reset:      in  std_logic;
        clock_rx:   in  std_logic;
        rx:         in  std_logic;
        data_in:    in  regFlit;
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
        statusHamming: in reg3
    );
end Phoenix_buffer;

architecture Phoenix_buffer of Phoenix_buffer is

    type fila_out is (S_INIT, S_PAYLOAD, S_SENDHEADER, S_HEADER, S_END, S_END2,C_PAYLOAD,C_SIZE, C_HEADER);
    signal next_state, current_state : fila_out;

    signal buffer_is_not_full: std_logic;
    signal counter_flit: unsigned(regFlit'range);

    signal buffCtrl : buffControl;  -- XY | XY | DIR
    signal codigoControl : unsigned(regFlit'range);
    signal buffCtrlFalha : row_FaultTable_Ports;

    signal c_error : std_logic; -- '0' sem erro para o destino, '1' com erro para o destino
    signal c_direcao: regNport := (others=>'0'); -- registrador com a direcao que esta mandando o pacote
    signal c_createmessage : std_logic; -- sinal usado para criar um pacote de controle com a tabela de falhas
    signal c_Buffer : regflit; -- dado de saida gerado ao criar um pacote de controle (pacote de resposta eh criado quando eh pedido leitura da tabela de falhas)
    signal c_strLinkTstLocal : std_logic; -- sinal do pedido de inicio de teste de links
    signal old_tabelaFalhas : regNport; -- antiga tabela e falhas com 1 bit para cada porta. '0' indica sem falha, '1' indica com falha

    signal retransmission_o: std_logic;
    signal pkt_size: unsigned(regFlit'range);

    signal indexFlitCtrlAux: integer;
    signal has_data: boolean;
    signal is_last_flit: std_logic;
    signal head, tail : regflit;
    signal pull, push: std_logic;
    signal counter: integer;
    signal is_tail: boolean;
    signal number_of_retransmissions: integer;

begin

    circularFifoBuffer : entity work.fifo_buffer
        generic map(
            BUFFER_DEPTH => TAM_BUFFER,
            BUFFER_WIDTH => regflit'length
        )
        port map(
            reset =>     reset,
            clock =>     clock_rx,
            tail =>      tail,
            push =>      push,
            pull =>      pull,
            counter =>   counter,
            head =>      head
        );

    tail <= std_logic_vector(unsigned(data_in) + to_unsigned(number_of_retransmissions, data_in'length)) when is_tail else data_in;
    push <= '1' when rx = '1' and statusHamming /= ED and ((c_strLinkTstAll = '0' and c_strLinkTstNeighbor='0') or bufLocation = LOCAL) else '0';
    has_data <= counter /= 0;
    is_last_flit <= '1' when counter = 1 else '0';

    retransmission_out <= retransmission_o;

    old_tabelaFalhas(LOCAL) <= '0';
    old_tabelaFalhas(EAST) <= c_tabelafalhas(EAST)(3*COUNTERS_SIZE+1);
    old_tabelaFalhas(WEST) <= c_tabelafalhas(WEST)(3*COUNTERS_SIZE+1);
    old_tabelaFalhas(NORTH) <= c_tabelafalhas(NORTH)(3*COUNTERS_SIZE+1);
    old_tabelaFalhas(SOUTH) <= c_tabelafalhas(SOUTH)(3*COUNTERS_SIZE+1);

    -- sinal indica se tem falha no link destino
    c_error <= '1' when unsigned(c_direcao and old_tabelafalhas) /= 0 else '0';

    buffer_is_not_full <= '1' when counter < TAM_BUFFER else '0';
    credit_o <= buffer_is_not_full;
    retransmission_o <= '1' when statusHamming = ED else '0';

    process(reset, clock_rx)
        variable count: integer;
        variable pkt_received: std_logic := '0';
        file my_output : TEXT; 
        variable fstatus: file_open_status := STATUS_ERROR;
        variable my_output_line : LINE;
        variable count_retx: integer := 0;
    begin
        if reset = '1' then
            count := 0;
            pkt_size <= (others=>'0');
            pkt_received := '1';
            is_tail <= false;
            number_of_retransmissions <= 0;
        elsif rising_edge(clock_rx) then
            if (rx = '0' and pkt_received='1') then
                count := 0;
                pkt_received := '0';
                pkt_size <= (others=>'0');
                count_retx := 0;
            end if;

            if (count = pkt_size+1 and pkt_size > 0) then
                is_tail <= true;
            else
                is_tail <= false;
            end if;
        
            if buffer_is_not_full = '1' and rx = '1' and ((c_strLinkTstAll = '0' and c_strLinkTstNeighbor='0') or bufLocation = LOCAL) then
                if (statusHamming /= ED) then
                    if (count = 1) then
                        pkt_size <= unsigned(data_in);
                    end if;
                    count := count + 1;
                else
                    count_retx := count_retx + 1;
                end if;

                if (count = pkt_size+2 and pkt_size > 0) then
                    pkt_received := '1';

                    if (count_retx /= 0) then
                        if(fstatus /= OPEN_OK) then
                            file_open(fstatus, my_output,"retransmission_00"&to_hstring(address)&".txt",WRITE_MODE);
                        end if;
                        write(my_output_line, "Packet in port "&PORT_NAME(bufLocation)&" received "&integer'image(count_retx)&" flits with double error "&time'image(now));
                        writeline(my_output, my_output_line);
                    end if;
                else
                    pkt_received := '0';
                end if;
            end if;
        number_of_retransmissions <= count_retx;
        end if;
    end process;

    data <= head when c_createmessage ='0' else c_Buffer;

    process(reset, clock)
        variable indexFlitCtrl: integer :=0;
        variable varControlCom: integer :=1; -- variavel de comando, para fazer as iteracoes
    begin
        if reset = '1' then
            counter_flit <= (others=>'0');
            codigoControl <= (others=>'0');
            c_direcao <= (others=>'0');
            c_createmessage <= '0';
            c_Buffer <= (others=>'0');
            c_strLinkTstLocal <= '0';
            indexFlitCtrl := 0;
            buffCtrl <= (others=>(others=>'0'));
            buffCtrlFalha <= (others=>(others=>'0'));
            h <= '0';
            data_av <= '0';
            sender <=  '0';
            pull <= '0';
            c_ctrl <= '0';
            c_chipETable <= '0';
            c_ceTF_out <= '0';
        elsif rising_edge(clock) then
            pull <= '0';
            case current_state is
                when S_INIT =>
                    c_chipETable <= '0'; -- desabilita escrita na tabela de roteamento
                    counter_flit <= (others=>'0');
                    data_av <= '0';
                    c_ctrl <= '0';
                    -- se existe dados no buffer a serem transmitidos OU se devo criar um pacote de controle com a  tabela de falhas
                    if has_data or c_createmessage = '1' then
                        -- se o primeiro flit do pacote a ser transmitido possui o bit indicando que eh um pacote de controle E se nesse primeiro flit possui o endereco do roteador em que o buffer se encontra
                        -- OU se devo criar um pacote de controle com a tabela de falhas (este pacote eh criado se for pedido a leitura da tabela de falhas)
                        if((head(head'high)='1') and (head((head'high-1) downto 0)=address((address'high-1) downto 0))) or c_createmessage = '1' then -- PACOTE DE CONTROLE
                            -- se preciso criar um pacote com a tabela de falhas. Comentario antigo: o pacote de controle pare este roteador
                            if c_createmessage = '1' then
                                -- se ultimo pacote de controle recebido foi de leitura da tabela de falhas
                                if codigoControl = c_RD_FAULT_TAB_STEP1 then
                                    c_Buffer <=  '1' & address((address'high-1) downto 0); -- entao crio o primeiro flit do pacote que vai conter a tabela de falhas
                                    h <= '1';         -- requisicao de chaveamento (chavear os dados de entrada para a porta de saida atraves da crossbar)
                                    c_ctrl <= '1'; -- indica que o pacote lido/criado eh de controle
                                    c_direcao <= "10000"; --direcao para a saida Local
                                end if;
                                -- nao irei criar pacote de controle com a tabela de falhas, irei apenas transmitir o pacote do buffer
                            else
                                -- nao preciso tratar erro detectado aqui, pq em ED o flit eh igual a zero, logo nao sera pacote de controle
                                pull <= '1';
                                c_ctrl <= '1'; -- indica que o pacote lido/criado eh de controle
                                c_direcao <= "10000"; -- direcao para o a saida Local
                            end if;
                            -- tenho dados para enviar e nao sao de controle (apenas pacote de dados)
                        else
                            h <= '1';         -- requisicao de chaveamento (chavear os dados de entrada para a porta de saida atraves da crossbar)
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
                    -- atendido/confirmado a requisicao de chaveamento OU se link destino tiver falhar
                    if ack_h = '1' or c_error = '1' then
                        h <= '0'; -- nao preciso mais solicitar o chaveamento pq ele foi ja foi atendido :)
                        data_av <= '1'; -- data available (usado para indicar que exite flit a ser transmitido)
                        sender <= '1'; -- usado para indicar que esta transmitindo (por este sinal sabemos quando termina a transmissao e a porta destino desocupa)
                        pull <= '1';
                    end if;

                when S_SENDHEADER  =>
                    -- se recebeu confirmacao de dado recebido OU o link destino esta com falha
                    if data_ack = '1' or c_error = '1' then
                        if c_createmessage = '0' then
                            -- se receptor nao pediu retransmissao, continua enviando
                            if (retransmission_in='0') then
                                pull <= '1';
                                if has_data then
                                    data_av <= not is_last_flit;
                                else
                                    data_av <= '0';
                                end if;
                            end if;
                            -- irei criar um pacote de controle com a tabela de falhas
                        else
                            -- se ultimo pacote de controle recebido foi pedido de leitura da tabela de falhas
                            if codigoControl = c_RD_FAULT_TAB_STEP1 then
                                counter_flit <= x"000A"; -- 10 flits de payload (code + origem + tabela)
                                c_Buffer <= x"000A"; -- segundo flit do pacote de controle criado (tamanho de pacote)
                                indexFlitCtrl := 0;
                                varControlCom  := 10;
                            end if;
                        end if;
                    end if;

                when S_PAYLOAD =>
                    if (( data_ack = '1' or c_error = '1') and retransmission_in = '1') then
                        -- se nao eh o ultimo flit do pacote E se foi confirmado que foi recebido com sucesso o dado transmitido OU o link destino esta com falha. Comentario antigo: confirmacao do envio de um dado que nao eh o tail
                    elsif counter_flit /= x"1" and ( data_ack = '1' or c_error = '1') then
                        -- se counter_flit eh zero indica que terei que receber o size do payload
                        if counter_flit = x"0" then
                            counter_flit <=  unsigned(head);
                        else
                            counter_flit <= counter_flit - 1;
                        end if;
                        pull <= '1';
                        data_av <= not is_last_flit;
                        -- se eh o ultimo flit do pacote E se foi confirmado que foi recebido com sucesso o dado transmitido OU o link destino esta com falha. Comentario antigo: confirmacao do envio do tail
                    elsif counter_flit = x"1" and (data_ack = '1' or c_error = '1') then
                        pull <= '1';
                        data_av <= '0'; -- como o ultimo flit sera enviado, nao tem mais dados disponiveis
                        sender <= '0'; -- como o ultimo flit sera enviado, nao preciso sinalizar que estou enviando dados
                        -- se tem dado a ser enviado, sinaliza
                    elsif has_data then
                        data_av <= '1'; -- (data available)
                    end if;

                when C_HEADER =>
                    pull <= '1';

                when C_SIZE =>
                    -- detectou dado na fila (tem dados a serem enviados no buffer)   e nao pediu retransmissao
                    if (has_data and retransmission_o='0') then
                        counter_flit <= unsigned(head); -- leitura do segundo flit (tamanho do pacote)
                        pull <= '1';
                        indexFlitCtrl := 0;   -- coloca o indice do flit de controle igual 0 (esse indice eh usado para percorrer os flits de payload de controle). O indice igual a 0 representa o terceito flit do pacote e nele havera o Code (codigo que indica o tipo do pacote de controle)
                        varControlCom  := 1;  -- numero de flits no payload usados para processar o pacote de controle
                    end if;

                when C_PAYLOAD =>
                    c_chipETable <= '0'; -- desabilita escrita na tabela de roteamento
                    if (has_data) and indexFlitCtrl /= varControlCom and c_createmessage = '0' and retransmission_o='0' then
                        pull <= '1';
                    end if;
                    -- indice igual a zero, ou seja, primeiro flit do payload do pacote (onde possui o codigo do pacote de controle)
                    if (indexFlitCtrl = 0 and retransmission_o='0') then
                        codigoControl <= unsigned(head); -- leitura do tipo do pacote de controle (leitura do Code)
                        indexFlitCtrl := indexFlitCtrl + 1; -- incrementa o indice do payload que sera lido
                        counter_flit <= counter_flit - 1; -- decrementa o numero de flits que faltam a ser lidos/processados do pacote
                        -- define qual o tamanho da variavel de comando (tamanho do payload).
                        -- Pode ser entendido como o numero de flits no payload usados para processar o pacote de controle
                        if c_createmessage = '0' then
                            if to_integer(unsigned(head)) = c_WR_ROUT_TAB then
                                varControlCom := 5;
                            elsif to_integer(unsigned(head)) = c_WR_FAULT_TAB then
                                varControlCom := 9; -- code + tabela
                            elsif to_integer(unsigned(head)) = c_RD_FAULT_TAB_STEP1 then
                                varControlCom := 1;
                            elsif to_integer(unsigned(head)) = c_TEST_LINKS  then
                                varControlCom := 1;
                            end if;
                            -- se c_createmessage='1', logo tenho que criar um pacote com a tabela de falhas para o OsPhoenix
                        else
                            -- se ultimo pacote de controle recebido foi pedido de leitura da tabela de falhas
                            if codigoControl = c_RD_FAULT_TAB_STEP1 then
                                varControlCom := 10; -- code + origem + tabela
                                codigoControl <= to_unsigned(c_RD_FAULT_TAB_STEP2, codigoControl'length); -- atualiza codigo com c_RD_FAULT_TAB_STEP2
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
                            c_chipETable <= '1'; -- habilita escrita na tabela de roteamento
                            indexFlitCtrl := 1;
                        else
                            buffCtrl(indexFlitCtrl-1) <= head; -- vai armazenando os dados lido do pacote de controle (o pacote tera uma linha da tabela de roteamento)
                            if (has_data) then
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
                            when 1 => buffCtrlFalha(EAST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= head((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(EAST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                            when 2 => buffCtrlFalha(EAST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= head((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(EAST)((COUNTERS_SIZE-1) downto 0) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                            when 3 => buffCtrlFalha(WEST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= head((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(WEST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                            when 4 => buffCtrlFalha(WEST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= head((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(WEST)((COUNTERS_SIZE-1) downto 0) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                            when 5 => buffCtrlFalha(NORTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= head((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(NORTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                            when 6 => buffCtrlFalha(NORTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= head((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(NORTH)((COUNTERS_SIZE-1) downto 0) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                            when 7 => buffCtrlFalha(SOUTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= head((METADEFLIT+1) downto METADEFLIT); -- leitura dos 2 bits que indicam falha que sera armazenado/atualizado na tabela de falhas
                                buffCtrlFalha(SOUTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador N
                            when 8 => buffCtrlFalha(SOUTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE) <= head((METADEFLIT+COUNTERS_SIZE-1) downto METADEFLIT); -- leitura do contador M
                                buffCtrlFalha(SOUTH)((COUNTERS_SIZE-1) downto 0) <= head(COUNTERS_SIZE-1 downto 0); -- leitura do contador P

                            when others => null;
                        end case;
                        if (has_data) then
                            indexFlitCtrl := indexFlitCtrl + 1;
                            counter_flit <= counter_flit - 1;
                        end if;
                        -- ultimo flit?
                        if counter_flit = 0 then
                            c_ceTF_out <= '1'; -- habilita ce para escrever/atualizar a tabela de falhas
                        end if;
                        -- pedido de leitura da tabela de falhas
                    elsif codigoControl = c_RD_FAULT_TAB_STEP1 then
                        --codigo requerindo a tabela de falhas
                        counter_flit <= counter_flit - 1;
                        -- sinal usado para criar um pacote de controle com a tabela de falhas. Comentario antigo: envia msg para tabela
                        c_createmessage <= '1';
                        -- resposta da leitura da tabela de falhas
                    elsif codigoControl = c_RD_FAULT_TAB_STEP2 then
                        -- code complement. Comentario antigo: codigo para enviar a msg de falhas para o PE
                        if (data_ack = '1') then
                            case (indexFlitCtrl) is
                                when 1 => c_Buffer <= address; -- neste quarto flit havera o endereco do roteador

                                when 2 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-2)) & c_TabelaFalhas(EAST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(EAST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                                when 3 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(EAST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(EAST)((COUNTERS_SIZE-1) downto 0);

                                when 4 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-2)) & c_TabelaFalhas(WEST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(WEST)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                                when 5 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(WEST)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(WEST)((COUNTERS_SIZE-1) downto 0);

                                when 6 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-2)) & c_TabelaFalhas(NORTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(NORTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                                when 7 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(NORTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(NORTH)((COUNTERS_SIZE-1) downto 0);

                                when 8 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-2)) & c_TabelaFalhas(SOUTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(SOUTH)((3*COUNTERS_SIZE-1) downto 2*COUNTERS_SIZE);
                                when 9 => c_Buffer((TAM_FLIT-1) downto METADEFLIT) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(SOUTH)((2*COUNTERS_SIZE-1) downto COUNTERS_SIZE);
                                    c_Buffer((METADEFLIT-1) downto 0) <= std_logic_vector(to_unsigned(0,METADEFLIT-COUNTERS_SIZE)) & c_TabelaFalhas(SOUTH)((COUNTERS_SIZE-1) downto 0);

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
                        end if;
                    end if;

                when S_END =>
                    c_chipETable <= '0';
                    c_ceTF_out <= '0';
                    c_ctrl <= '0';
                    data_av <= '0';
                    c_direcao <= (others=>'0');
                    indexFlitCtrl := 0;
                    pull <= '0';

                when S_END2 => -- estado necessario para permitir a liberacao da porta antes da solicitacao de novo envio
                    data_av <= '0';
                    pull <= '0';
            end case;
            indexFlitCtrlAux <= indexFlitCtrl;
        end if;
    end process;

    c_buffCtrlOut <= buffCtrl;
    c_codigoCtrl <= std_logic_vector(codigoControl);
    c_buffCtrlFalha <= buffCtrlFalha;
    c_strLinkTst <= c_strLinkTstLocal;

    process(current_state, ack_h, indexFlitCtrlAux, has_data, c_createmessage, head, counter_flit, codigoControl, c_stpLinkTst, data_ack, c_error, retransmission_o, retransmission_in)
    begin
        next_state <= current_state;
        case current_state is
            when S_INIT =>
                if has_data or c_createmessage = '1' then
                    if((head(head'high)='1') and (head((head'high-1) downto 0)=address((address'high-1) downto 0))) or c_createmessage = '1' then -- PACOTE DE CONTROLE
                        if c_createmessage = '1' then
                            if codigoControl = c_RD_FAULT_TAB_STEP1 then
                                next_state <= S_HEADER;
                            end if;
                        else
                            next_state <= C_HEADER;
                        end if;
                    else
                        next_state <= S_HEADER;
                    end if;
                end if;

            when S_HEADER =>
                if ack_h = '1' or c_error = '1' then
                    next_state <= S_SENDHEADER;
                end if;

            when S_SENDHEADER  =>
                if data_ack = '1' or c_error = '1' then
                    if c_createmessage = '0' then
                        if (retransmission_in='0') then
                            next_state <= S_PAYLOAD;
                        end if;
                    else
                        if codigoControl = c_RD_FAULT_TAB_STEP1 then
                            next_state <= C_PAYLOAD;
                        end if;
                    end if;
                end if;

            when S_PAYLOAD =>
                if (( data_ack = '1' or c_error = '1') and retransmission_in = '1') then
                elsif counter_flit = x"1" and (data_ack = '1' or c_error = '1') then
                    next_state <= S_END;
                end if;

            when C_HEADER =>
                next_state <= C_SIZE;

            when C_SIZE =>
                if (has_data and retransmission_o='0') then
                    next_state <= C_PAYLOAD;
                end if;

            when C_PAYLOAD =>
                if (indexFlitCtrlAux = 0 and retransmission_o='0') then
                elsif (codigoControl = c_WR_ROUT_TAB and retransmission_o='0') then
                    if indexFlitCtrlAux = 5 and counter_flit = x"1" then
                        next_state <= S_END;
                    end if;
                elsif (codigoControl = c_WR_FAULT_TAB and retransmission_o='0') then
                    if counter_flit = 0 then
                        next_state <= S_END;
                    end if;
                elsif codigoControl = c_RD_FAULT_TAB_STEP1 then
                    next_state <= S_INIT;
                elsif codigoControl = c_RD_FAULT_TAB_STEP2 then
                    if counter_flit = x"0" then
                        next_state <= S_END;
                    end if;
                elsif codigoControl = c_TEST_LINKS then
                    if c_stpLinkTst = '1' then
                        next_state <= S_END;
                    end if;
                end if;

            when S_END =>
                next_state <= S_END2;

            when S_END2 =>
                next_state <= S_INIT;
        end case;
    end process;

    process(reset, clock)
    begin
        if reset = '1' then
            current_state <= S_INIT;
        elsif rising_edge(clock) then
            current_state <= next_state;
        end if;
    end process;

end Phoenix_buffer;
