library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use work.PhoenixPackage.regNport;
use work.HammingPack16.all;


entity FPPM is
port
(
	clock                   : in  std_logic;
	reset_in                : in  std_logic; -- reset geral da NoC
	rx                      : in  regHamm_Nport; -- rx (sinal que indica que estou recebendo transmissao)
	statusHamming           : in  array_statusHamming; -- status (sem erro, erro corrigido, erro detectado) das 4 portas (EAST,WEST,NORTH,SOUTH)
	write_FaultTable        : out regHamm_Nport; -- sinal para indicar escrita na tabela de falhas
	row_FaultTablePorts_out : out row_FaultTable_Ports -- linha a ser escrita na tabela de falhas
);
end FPPM;

architecture FPPM of FPPM is
	-- CUIDADO! Os contadores tem apenas COUNTERS_SIZE bits!
	constant N: integer range 1 to 31 := 8;
	constant M: integer range 1 to 31 := 4;
	constant P: integer range 1 to 31 := 30;

	constant COUNTER_UPDATE_TABLE: integer := 1; -- numero de flits recebidos necessarios para atualizar a tabela

begin

	FPPM_generate: for i in 0 to (HAMM_NPORT-1) generate
	begin
		process(clock, reset_in)
			variable counter_write: integer range 0 to COUNTER_UPDATE_TABLE;
			variable reset: std_logic := '0';
			variable counter_N, counter_M, counter_P: std_logic_vector((COUNTERS_SIZE-1) downto 0);
			variable link_status: std_logic_vector(1 downto 0) := "00";
		begin

			if (reset_in='1') then
				reset := '0';
				counter_N := (others=>'0');
				counter_M := (others=>'0');
				counter_P := (others=>'0');
				write_FaultTable(i) <= '0';
				row_FaultTablePorts_out(i) <= (others=>'0');
			end if;

			if (clock'event and clock='1' and rx(i)='1') then

				--counter_write := counter_write + 1;

				case statusHamming(i) is

					when NE =>
						counter_N := counter_N + 1;
						if (counter_N = N) then
							link_status := "00";
							reset := '1';
						end if;

					when EC =>
						counter_M := counter_M + 1;
						if (counter_M = M) then
							link_status := "01";
							reset := '1';
						end if;

					when ED =>
						counter_P := counter_P + 1;
						if (counter_P = P) then
							link_status := "10";
							reset := '1';
						end if;

					when others => null;

				end case;

				if (reset = '1') then
					reset := '0';
					counter_N := (others=>'0');
					counter_M := (others=>'0');
					counter_P := (others=>'0');
				end if;

				if (counter_write = COUNTER_UPDATE_TABLE) then
				--if (false) then
					write_FaultTable(i) <= '1';
					row_FaultTablePorts_out(i) <= link_status & counter_N & counter_M & counter_P;
					counter_write := 0;
				else
					write_FaultTable(i) <= '0';
					row_FaultTablePorts_out(i) <= (others=>'0');
				end if;

			elsif (rx(i)='0') then
				write_FaultTable(i) <= '0';
				row_FaultTablePorts_out(i) <= (others=>'0');
			end if;
		end process;
	end generate;
 

end FPPM;