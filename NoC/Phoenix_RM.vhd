---------------------------------------------------------
-- Routing Mechanism
---------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PhoenixPackage.all;
use work.TablePackage.all;

entity routingMechanism is
	generic(address : regmetadeflit := (others=>'0'));
	port(
			clock :   in  std_logic;
			reset :   in  std_logic;
			buffCtrl: in buffControl; -- linha correspondente a tabela de roteamento lido do pacote de controle que sera escrita na tabela
			ctrl :	in std_logic; -- indica se foi lido ou criado de um pacote de controle pelo buffer
			operacao: in regflit; -- codigo de controle do pacote de controle (terceiro flit do pacote de controle)
			ceT: in std_logic; -- chip enable da tabela de roteamento. Indica que sera escrito na tabela de roteamento
			oe :   in  std_logic;
			dest : in reg8;
			inputPort : in integer range 0 to (NPORT-1); -- porta de entrada selecionada pelo arbitro para ser chaveada
			outputPort : out regNPort; -- indica qual porta de saida o pacote sera encaminhado
			find : out RouterControl
		);
end routingMechanism;

architecture behavior of routingMechanism is

-- sinais da máquina de estado
	type state is (S0,S1,S2,S3,S4);
	signal ES, PES : state;
	
	-- sinais da Tabela
	signal ce: std_logic := '0';
	signal data : std_logic_vector(4 downto 0) := (others=>'0');

	signal rowDst, colDst : integer;
	type row is array ((NREG-1) downto 0) of integer;
	signal rowInf, colInf, rowSup, colSup : row;
	signal H : std_logic_vector((NREG-1) downto 0);
	-------------New Hardware---------------
	signal VertInf, VertSup : STD_LOGIC_VECTOR(7 downto 0);
	signal func : STD_LOGIC_VECTOR(7 downto 0);
	signal OP : STD_LOGIC_VECTOR(4 downto 0);
	type arrayIP is array ((NREG-1) downto 0) of std_logic_vector(4 downto 0);
	signal IP : arrayIP;
	signal IP_lido: STD_LOGIC_VECTOR(4 downto 0);
	signal i : integer := 0;

	signal RAM: memory := TAB(ADDRESS_TO_NUMBER_NOIA(address));
	
begin

	rowDst <= TO_INTEGER(unsigned(dest(7 downto 4))) when ctrl = '0' else 0;
	colDst <= TO_INTEGER(unsigned(dest(3 downto 0))) when ctrl = '0' else 0;

	cond: for j in 0 to (NREG - 1) generate

		rowInf(j) <= TO_INTEGER(unsigned(RAM(j)(20 downto 17))) when ctrl = '0' else 0;
		colInf(j) <= TO_INTEGER(unsigned(RAM(j)(16 downto 13))) when ctrl = '0' else 0;
		rowSup(j) <= TO_INTEGER(unsigned(RAM(j)(12 downto 9))) when ctrl = '0' else 0;
		colSup(j) <= TO_INTEGER(unsigned(RAM(j)(8 downto 5))) when ctrl = '0' else 0;

		IP(j) <= RAM(j)(25 downto 21) when ctrl = '0' else (others=>'0');

		H(j) <= '1' when rowDst >= rowInf(j) and rowDst <= rowSup(j) and
			       	   colDst >= colInf(j) and colDst <= colSup(j) and 
			       	   IP(j)(inputPort) = '1' and ctrl = '0' else 
		      '0';

	end generate;

	process(RAM, H, ce, ctrl)
	begin
		data <= (others=>'Z');
		if ce = '1' and ctrl = '0' then
			for i in 0 to (NREG-1) loop
				if H(i) = '1' then
					data <= RAM(i)(4 downto 0);
				end if;
			end loop;
		end if;
	end process;

	func <= operacao(7 downto 0);
	
	IP_lido <= buffCtrl(0)(4 downto 0);
	VertInf <= buffCtrl(1)(7 downto 0);
	VertSup <= buffCtrl(2)(7 downto 0);
	OP <= buffCtrl(3)(4 downto 0);

	process(ceT,ctrl)
	begin
		if ctrl = '0' then
			i <= 0;
		elsif ctrl = '1' and ceT = '1' and func = x"01" then
			RAM(i)(25 downto 21) <= IP_lido(4 downto 0);
			RAM(i)(20 downto 13) <= VertInf(7 downto 0);
			RAM(i)(12 downto 5) <= VertSup(7 downto 0);
			RAM(i)(4 downto 0) <= OP(4 downto 0);
			if (i = NREG-1) then
				i <= 0;
			else
				i <= i + 1;
			end if;
		end if;
	end process;
	
	process(reset,clock)
	begin
		if reset='1' then
			ES<=S0;
		elsif clock'event and clock='0' then
			ES<=PES;
		end if; 
	end process;
	
	------------------------------------------------------------------------------------------------------
	-- PARTE COMBINACIONAL PARA DEFINIR O PRO“XIMO ESTADO DA MAQUINA
	--
	-- S0 -> Este estado espera oe = '1' (operation enabled), indicando que ha um pacote que que deve
	--       ser roteado.
	-- S1 -> Este estado ocorre a leitura na memeria - tabela, a fim de obter as 
	--       definicoes de uma regiao.
	-- S2 -> Este estado verifica se o roteador destino (destRouter) pertence aquela
	--       regiao. Caso ele pertenca, o sinal de RM eh ativado e a maquina de estados
	--       avanca para o proximo estado, caso contrario retorna para o estado S1 e
	--       busca por uma nova regiao.
	-- S3 -> Neste estado o switch control eh avisado (find="01") que foi descoberto por 
	--       qual porta este pacote deve sair. Este estado tambem zera count, valor que 
	--			aponta qual o proximo endereco deve ser lido na memoria.
	-- S4 -> Aguarda oe = '0' e retorna para o estado S0.
	
	process(ES, oe)
	begin
		case ES is
			when S0 => if oe = '1' then PES <= S1; else PES <= S0; end if;
			when S1 => PES <= S2;
			when S2 => PES <= S3;
			when S3 => if oe = '0' then PES <= S0; else PES <= S3; end if;
			when others => PES <= S0;
		end case;
	end process;
	
	------------------------------------------------------------------------------------------------------
	-- executa as acoes correspondente ao estado atual da maquina de estados
	------------------------------------------------------------------------------------------------------
	process(clock)
	begin
		if(clock'event and clock = '1') then
			case ES is
				-- Aguarda oe='1'
				when S0 =>
					find <= invalidRegion;
					
				-- Leitura da tabela
				when S1 =>
					ce <= '1';
					
				-- Informa que achou a porta de saida para o pacote
				when S2 =>
					find <= validRegion;
				-- Aguarda oe='0'
				when S3 =>
					ce <= '0';
					find <= invalidRegion;
				when others =>
					find <= portError;
			end case;
		end if;
	end process;
	outputPort <= data;
end behavior;	