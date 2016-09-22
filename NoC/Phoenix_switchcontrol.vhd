library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use work.PhoenixPackage.all;
use work.HammingPack16.all;

entity SwitchControl is
	generic(address : regmetadeflit := (others=>'0'));
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
	c_faultTableFDM	: in regNPort; -- tabela de falhas gerado pelo teste de links
	sender :  in  regNport;
	free :    out regNport; -- portas de saida que estao livres
	mux_in :  out arrayNport_reg3;
	mux_out : out arrayNport_reg3;
	row_FaultTablePorts_in: in row_FaultTable_Ports; -- linhas a serem escritas na tabela (do FFPM)
	write_FaultTable: in regHamm_Nport); -- sinal para indicar escrita na tabela (do FPPM)
end SwitchControl;

architecture RoutingTable of SwitchControl is

	type state is (S0,S1,S2,S3,S4,S5,S6,S7);
	signal ES, PES: state;

-- sinais do arbitro
	signal ask: std_logic := '0';
	signal sel,prox: integer range 0 to (NPORT-1) := 0;
	signal incoming: reg3 := (others=> '0');
	signal header : regflit := (others=> '0');

-- sinais do controle
	signal indice_dir: integer range 0 to (NPORT-1) := 0;
	signal tx,ty: regquartoflit := (others=> '0');
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
begin
	ask <= '1' when (h(LOCAL)='1' or h(EAST)='1' or h(WEST)='1' or h(NORTH)='1' or h(SOUTH)='1') else '0';
	incoming <= CONV_VECTOR(sel);
	header <= data(CONV_INTEGER(incoming));

	-- escolhe uma das portas que solicitou chaveamento
	process(sel, h)
	begin
		case sel is
			when LOCAL=>
				if h(EAST)='1' then prox<=EAST;
				elsif h(WEST)='1' then prox<=WEST;
				elsif h(NORTH)='1' then prox<=NORTH;
				elsif h(SOUTH)='1' then prox<=SOUTH;
				else prox<=LOCAL; end if;
			when EAST=>
				if h(WEST)='1' then prox<=WEST;
				elsif h(NORTH)='1' then prox<=NORTH;
				elsif h(SOUTH)='1' then prox<=SOUTH;
				elsif h(LOCAL)='1' then prox<=LOCAL;
				else prox<=EAST; end if;
			when WEST=>
				if h(NORTH)='1' then prox<=NORTH;
				elsif h(SOUTH)='1' then prox<=SOUTH;
				elsif h(LOCAL)='1' then prox<=LOCAL;
				elsif h(EAST)='1' then prox<=EAST;
				else prox<=WEST; end if;
			when NORTH=>
				if h(SOUTH)='1' then prox<=SOUTH;
				elsif h(LOCAL)='1' then prox<=LOCAL;
				elsif h(EAST)='1' then prox<=EAST;
				elsif h(WEST)='1' then prox<=WEST;
				else prox<=NORTH; end if;
			when SOUTH=>
				if h(LOCAL)='1' then prox<=LOCAL;
				elsif h(EAST)='1' then prox<=EAST;
				elsif h(WEST)='1' then prox<=WEST;
				elsif h(NORTH)='1' then prox<=NORTH;
				else prox<=SOUTH; end if;
		end case;
	end process;

	tx <= header((METADEFLIT - 1) downto QUARTOFLIT); -- coordenada X do destino
	ty <= header((QUARTOFLIT - 1) downto 0); -- coordernada Y do destino
	
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
			elsif (write_FaultTable /= 0) then

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
	strLinkTstAll <= c_strLinkTst(0) or c_strLinkTst(1) or c_strLinkTst(2) or c_strLinkTst(3) or c_strLinkTst(4);
	

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
	c_ceTF <= ( c_ceTF_in(EAST)  OR
		    c_ceTF_in(WEST)  OR
		    c_ceTF_in(SOUTH) OR
		    c_ceTF_in(NORTH) OR
		    c_ceTF_in(LOCAL));
	------------------------------------------------------------
	
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
			dest => header((METADEFLIT - 1) downto 0), -- primeiro flit/header do pacote (contem o destino do pacote)
			inputPort => sel, -- porta de entrada selecionada pelo arbitro para ser chaveada
			outputPort => dir, -- indica qual porta de saida o pacote sera encaminhado
			find => find -- indica se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
		);

	process(reset,clock)
	begin
		if reset='1' then
			ES<=S0;
		elsif clock'event and clock='0' then
			ES<=PES;
		end if; 
	end process;

	------------------------------------------------------------------------------------------------------
	-- PARTE COMBINACIONAL PARA DEFINIR O PROXIMO ESTADO DA MAQUINA
	--
	-- SO -> O estado S0 eh o estado de inicializacao da maquina. Este estado somente eh	
	--       atingido quando o sinal reset eh ativado.
	-- S1 -> O estado S1 eh o estado de espera por requisicao de chaveamento. Quando o
	--       arbitro recebe uma ou mais requisicoes, o sinal ask eh ativado fazendo a
	--       maquina avancar para o estado S2.
	-- S2 -> No estado S2 a porta de entrada que solicitou chaveamento eh selecionada. Se
	--       houver mais de uma, aquela com maior prioridade eh a selecionada. Se o destino
	--	 for o proprio roteador pula para o estado S4, caso contrario segue o fluxo
	--	 normal.
	-- S3 -> Este estado eh muito parecido com o do algoritmo XY, a diferenca eh que ele
	--		 verifica o destino do pacote atraves de uma tabela e nao por calculos.
	--		    4       3       2      1      0
	-- dir -> 	| Local | South | North | West | East |
	process(ES,ask,h,tx,ty,auxfree,dir,find)
	begin

		case ES is
			when S0 => PES <= S1;
			when S1 => if ask='1' then PES <= S2; else PES <= S1; end if;
			when S2 => PES <= S3;
			when S3 => 
					if address = header((METADEFLIT - 1) downto 0) and auxfree(LOCAL)='1' then PES<=S4;

					-- se terminou de achar uma porta de saida para o pacote conforme a tabela de roteamento
					elsif(find = validRegion)then

						if (h(sel)='0') then -- se desistiu de chavear (por causa do descarte do pacote)
							PES <= S1;

						-- se a porta de sai eh EAST e se ela estiver livre
  				     		elsif    (dir(EAST)='1' and  auxfree(EAST)='1') then
							indice_dir <= EAST ; 
					    		PES<=S5;
					  	elsif (dir(WEST)='1' and  auxfree(WEST)='1') then
							indice_dir <= WEST; 
					    		PES<=S5;
	  				 	elsif (dir(NORTH)='1' and  auxfree(NORTH)='1' ) then
							indice_dir <= NORTH; 
					    		PES<=S6;
					  	elsif (dir(SOUTH)='1' and  auxfree(SOUTH)='1' ) then
							indice_dir <= SOUTH; 
					   		PES<=S6;
			  		  	else PES<=S1;
					end if;
					elsif(find = portError)then
						PES <= S1;
					else
						PES<=S3;
					end if;
			when S4 => PES<=S7;
			when S5 => PES<=S7;
			when S6 => PES<=S7;
			when S7 => PES<=S1;
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
					ceTable <= '0';
					ack_h <= (others => '0');

				-- Seleciona quem tera direito a requisitar roteamento
				when S2=>
					sel <= prox;

				-- Aguarda resposta da Tabela					
				when S3 =>
					if address /= header((METADEFLIT - 1) downto 0) then
						ceTable <= '1';
					end if;

				-- Estabelece a conexao com a porta LOCAL
				when S4 =>
					source(CONV_INTEGER(incoming)) <= CONV_VECTOR(LOCAL); -- sinal para a crossbar
					mux_out(LOCAL) <= incoming; -- sinal para crossbar
					auxfree(LOCAL) <= '0'; -- conexao estabelecida, logo porta ocupado
					ack_h(sel)<='1'; -- responde que houve chaveamento com sucesso

				-- Estabelece a conexao com a porta EAST ou WEST
				when S5 =>
					source(CONV_INTEGER(incoming)) <= CONV_VECTOR(indice_dir);
					mux_out(indice_dir) <= incoming;
					auxfree(indice_dir) <= '0';
					ack_h(sel)<='1';

				-- Estabelece a conexao com a porta NORTH ou SOUTH
				when S6 =>
					source(CONV_INTEGER(incoming)) <= CONV_VECTOR(indice_dir);
					mux_out(indice_dir) <= incoming;
					auxfree(indice_dir) <= '0';
					ack_h(sel)<='1';

				when others => 
					ack_h(sel)<='0';
					ceTable <= '0';
			end case;

			sender_ant(LOCAL) <= sender(LOCAL);
			sender_ant(EAST)  <= sender(EAST);
			sender_ant(WEST)  <= sender(WEST);
			sender_ant(NORTH) <= sender(NORTH);
			sender_ant(SOUTH) <= sender(SOUTH);

			-- se uma porta estava transmitindo dados e agora nao esta mais, entao a porta ficou livre
			if sender(LOCAL)='0' and  sender_ant(LOCAL)='1' then auxfree(CONV_INTEGER(source(LOCAL))) <='1'; end if;
			if sender(EAST) ='0' and  sender_ant(EAST)='1'  then auxfree(CONV_INTEGER(source(EAST)))  <='1'; end if;
			if sender(WEST) ='0' and  sender_ant(WEST)='1'  then auxfree(CONV_INTEGER(source(WEST)))  <='1'; end if;
			if sender(NORTH)='0' and  sender_ant(NORTH)='1' then auxfree(CONV_INTEGER(source(NORTH))) <='1'; end if;
			if sender(SOUTH)='0' and  sender_ant(SOUTH)='1' then auxfree(CONV_INTEGER(source(SOUTH))) <='1'; end if;

		end if;
	end process;


	mux_in <= source;
	free <= auxfree;


end RoutingTable;