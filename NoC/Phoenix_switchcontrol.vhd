library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.HammingPack16.all;
use work.NoCPackage.all;

entity SwitchControl is
    generic(address : regflit := (others=>'0'));
port(
    clock :   in  std_logic;
    reset :   in  std_logic;
    h :       in  regNport; -- solicitacoes de chaveamento
    ack_h :   out regNport; -- resposta para as solitacoes de chaveamento
    data :    in  arrayNport_regflit; -- dado do buffer (contem o endereco destino)
    c_ctrl : in std_logic; -- indica se foi lido ou criado de um pacote de controle pelo buffer
    c_CodControle : in regflit; -- codigo de controle do pacote de controle (terceiro flit do pacote de controle)
    c_BuffCtrl : in buffControl; -- linha correspondente a tabela de roteamento lido do pacote de controle que sera escrita na tabela
    c_buffTabelaFalhas_in: in row_FaultTable_Nport_Ports;
    c_ce : in std_logic; -- chip enable da tabela de roteamento. Indica que sera escrito na tabela de roteamento
    c_ceTF_in :  in  regNport; -- ce (chip enable) para escrever/atualizar a tabela de falhas
    c_error_dir: out regNport; -- indica qual direcao/porta de saida o pacote sera encaminhado
    c_error_ArrayFind: out ArrayRouterControl; -- indica se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
    c_tabelaFalhas : out row_FaultTable_Ports; -- tabela de falhas atualizada/final
    c_strLinkTst : in regNport; -- (start link test) indica que houve um pacote de controle do tipo TEST_LINKS para testar os links
    c_faultTableFDM    : in regNPort; -- tabela de falhas gerado pelo teste de links
    sender :  in  regNport;
    free :    out regNport; -- portas de saida que estao livres
    mux_in :  out arrayNport_reg3;
    mux_out : out arrayNport_reg3;
    row_FaultTablePorts_in: in row_FaultTable_Ports; -- linhas a serem escritas na tabela (do FFPM)
    write_FaultTable: in regHamm_Nport); -- sinal para indicar escrita na tabela (do FPPM)
end SwitchControl;

architecture RoutingTable of SwitchControl is

    type state is (S0,S1,S2,S3,S4,S5);
    signal ES, PES: state;

-- sinais do arbitro
    signal ask: std_logic := '0';
    signal sel,prox: integer range 0 to (NPORT-1) := 0;
    signal incoming: reg3 := (others=> '0');
    signal header : regflit := (others=> '0');
    signal ready, enable : std_logic;
    
-- sinais do controle
    signal indice_dir: integer range 0 to (NPORT-1) := 0;
    signal auxfree: regNport := (others=> '0');
    signal source:  arrayNport_reg3 := (others=> (others=> '0'));
    signal sender_ant: regNport := (others=> '0');
    signal dir: std_logic_vector(NPORT-1 downto 0):= (others=> '0');

-- sinais de controle da tabela
    signal find: RouterControl;
    signal ceTable: std_logic := '0';

-- sinais de controle de atualizacao da tabela de falhas
    signal c_ceTF : std_logic := '0';
    signal c_buffTabelaFalhas : row_FaultTable_Ports := (others=>(others=>'0'));
    --sinais da Tabela de Falhas
    signal tabelaDeFalhas : row_FaultTable_Ports := (others=>(others=>'0'));
    signal c_checked: regNPort:= (others=>'0');
    signal c_checkedArray: arrayRegNport :=(others=>(others=>'0'));
    signal dirBuff : std_logic_vector(NPORT-1 downto 0):= (others=> '0');
    signal strLinkTstAll : std_logic := '0';
    signal ant_c_ceTF_in: regNPort:= (others=>'0');

    signal selectedOutput : integer := 0;
    signal isOutputSelected : std_logic;

begin
    ask <= '1' when OR_REDUCTION(h) else '0';
    incoming <= CONV_VECTOR(sel);
    header <= data(to_integer(unsigned(incoming)));

    InputArbiter : entity work.inputArbiter
    port map(
        requests => h,
        enable => enable,
        nextPort => prox,
        ready => ready
    );

    ------------------------------------------------------------
    --gravacao da tabela de falhas
    ------------------------------------------------------------
    --registrador para tabela de falhas
    process(reset,clock)
    begin
        if reset='1' then
            tabelaDeFalhas <= (others=>(others=>'0'));
        elsif clock'event and clock='0' then
            ant_c_ceTF_in <= c_ceTF_in;

            -- se receber um pacote de controle para escrever/atualizar a tabela, escreve na tabela conforme a tabela recebida no pacote
            if c_ceTF='1' then
                tabelaDeFalhas <= c_buffTabelaFalhas;

            -- se tiver feito o teste dos links, atualiza a tabela de falha conforme o resultado do teste
            elsif strLinkTstAll = '1' then
                --tabelaDeFalhas <= c_faultTableFDM;
                tabelaDeFalhas(EAST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= c_faultTableFDM(EAST) & '0';
                tabelaDeFalhas(WEST)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= c_faultTableFDM(WEST) & '0';
                tabelaDeFalhas(NORTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= c_faultTableFDM(NORTH) & '0';
                tabelaDeFalhas(SOUTH)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) <= c_faultTableFDM(SOUTH) & '0';

            -- escrita na tabela de falhas pelo FPPM
            elsif (unsigned(write_FaultTable) /= 0) then

                -- escreve apenas se o sinal de escrit tiver ativo e se o sttus do link tiver uma severidade maior ou igual a contida na tabela
                for i in 0 to HAMM_NPORT-1 loop
                    if (write_FaultTable(i) = '1' and row_FaultTablePorts_in(i)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) >= tabelaDeFalhas(i)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE)) then
                        tabelaDeFalhas(i) <= row_FaultTablePorts_in(i);
                    end if;
                end loop;

            end if;
        end if;
    end process;

    -- '1' se em algum buffer houve o pedido de teste de link (por causa do pacote de controle do tipo TEST_LINKS)
    strLinkTstAll <= '1' when OR_REDUCTION(c_strLinkTst) else '0';


    -- "merge" das telas recebidas
    process(c_ceTF_in)
        variable achou: regHamm_Nport := (others=>'0');
    begin

        for i in 0 to NPORT-1 loop
            if (ant_c_ceTF_in(i)='1' and c_ceTF_in(i)='0') then
                achou := (others=>'0');
                exit;
            end if;
        end loop;

        -- pergunta para cada buffer quais que desejam escrever na tabela e, conforme os que desejam, copia as linhas da tabela do buffer que tiver como falha
        for i in 0 to NPORT-1 loop
            for j in 0 to HAMM_NPORT-1 loop
                if (achou(j)='0' and c_ceTF_in(i)='1' and c_buffTabelaFalhas_in(i)(j)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) = "10") then
                    c_buffTabelaFalhas(j) <= c_buffTabelaFalhas_in(i)(j);
                    achou(j) := '1';
                end if;
            end loop;
        end loop;

        -- pergunta para cada buffer quais que desejam escrever na tabela e, conforme os que desejam, copia as linhas da tabela do buffer que tiver como tendencia de falha
        for i in 0 to NPORT-1 loop
            for j in 0 to HAMM_NPORT-1 loop
                if (achou(j)='0' and c_ceTF_in(i)='1' and c_buffTabelaFalhas_in(i)(j)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) = "01") then
                    c_buffTabelaFalhas(j) <= c_buffTabelaFalhas_in(i)(j);
                    achou(j) := '1';
                end if;
            end loop;
        end loop;

        -- pergunta para cada buffer quais que desejam escrever na tabela e, conforme os que desejam, copia as linhas da tabela do buffer que tiver como sem falha
        for i in 0 to NPORT-1 loop
            for j in 0 to HAMM_NPORT-1 loop
                if (achou(j)='0' and c_ceTF_in(i)='1' and c_buffTabelaFalhas_in(i)(j)((3*COUNTERS_SIZE+1) downto 3*COUNTERS_SIZE) = "00") then
                    c_buffTabelaFalhas(j) <= c_buffTabelaFalhas_in(i)(j);
                    achou(j) := '1';
                end if;
            end loop;
        end loop;
    end process;

    -- '1' se em algum buffer tiver habilita o ce para escrever/atualizar a tabela de falhas
    c_ceTF <= '1' when OR_REDUCTION(c_ceTF_in) else '0';

    process(clock,reset)
    begin
        c_error_ArrayFind <= (others=>invalidRegion);
        c_error_ArrayFind(sel) <= find;
    end process;

    c_error_dir <= dir;
    c_tabelafalhas <= tabelaDeFalhas;

    RoutingMechanism : entity work.routingMechanism
    generic map(address => address)
    port map(
            clock => clock,
            reset => reset,
            buffCtrl => c_BuffCtrl, -- linha correspondente a tabela de roteamento lido do pacote de controle que sera escrita na tabela
            ctrl=> c_Ctrl, -- indica se foi lido ou criado de um pacote de controle pelo buffer
            operacao => c_CodControle, -- codigo de controle do pacote de controle (terceiro flit do pacote de controle)
            ceT => c_ce, -- chip enable da tabela de roteamento. Indica que sera escrito na tabela de roteamento
            oe => ceTable, -- usado para solicitar direcao/porta destino para a tabela de roteamento
            dest => header, -- primeiro flit/header do pacote (contem o destino do pacote)
            inputPort => sel, -- porta de entrada selecionada pelo arbitro para ser chaveada
            outputPort => dir, -- indica qual porta de saida o pacote sera encaminhado
            find => find -- indica se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
        );

    OutputArbiter : entity work.outputArbiter
    port map(
         freePort                => auxfree,
         enable                  => '1',
         enablePort              => dir,
         isOutputSelected        => isOutputSelected,
         selectedOutput          => selectedOutput
     );

    process(reset,clock)
    begin
        if reset='1' then
            ES<=S0;
        elsif clock'event and clock='1' then
            ES<=PES;
        end if;
    end process;

    process(ES, ask, auxfree, find, selectedOutput, isOutputSelected)
    begin
        case ES is
            when S0 => PES <= S1;
            when S1 =>
                if ask='1' then
                    PES <= S2;
                else
                    PES <= S1;
                end if;
            when S2 => PES <= S3;
            when S3 =>
                if address = header and auxfree(LOCAL)='1' then
                    indice_dir <= LOCAL;
                    PES <= S4;
                elsif(find = validRegion)then
                    if (isOutputSelected = '1') then
                        indice_dir <= selectedOutput;
                        PES <= S4;
                    else
                        PES <= S1;
                    end if;
                elsif(find = portError)then
                    PES <= S1;
                else
                    PES <= S3;
                end if;
            when S4 => PES <= S5;
            when S5 => PES <= S1;
        end case;
    end process;

    ------------------------------------------------------------------------------------------------------
    -- executa as acoes correspondente ao estado atual da maquina de estados
    ------------------------------------------------------------------------------------------------------
    process(clock)
    begin
        if clock'event and clock='1' then
            case ES is

                -- Zera variaveis
                when S0 =>
                    ceTable <= '0';
                    sel <= 0;
                    ack_h <= (others => '0');
                    auxfree <= (others=> '1');
                    sender_ant <= (others=> '0');
                    mux_out <= (others=>(others=>'0'));
                    source <= (others=>(others=>'0'));

                -- Chegou um header
                when S1=>
                    enable <= ask;
                    ceTable <= '0';
                    ack_h <= (others => '0');

                -- Seleciona quem tera direito a requisitar roteamento
                when S2=>
                    sel <= prox;
                    enable <= not ready;
                -- Aguarda resposta da Tabela
                when S3 =>
                    if address /= header then
                        ceTable <= '1';
                    end if;

                when S4 =>
                    source(to_integer(unsigned(incoming))) <= CONV_VECTOR(indice_dir);
                    mux_out(indice_dir) <= incoming;
                    auxfree(indice_dir) <= '0';
                    ack_h(sel) <= '1';

                when others =>
                    ack_h(sel) <= '0';
                    ceTable <= '0';
            end case;

            sender_ant <= sender;

            for i in EAST to LOCAL loop
                if sender(i) = '0' and  sender_ant(i) = '1' then
                    auxfree(to_integer(unsigned(source(i)))) <= '1';
                end if;
            end loop;
        end if;
    end process;

    mux_in <= source;
    free <= auxfree;

end RoutingTable;
