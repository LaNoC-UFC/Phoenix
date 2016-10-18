library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.CONV_STD_LOGIC_VECTOR;
use work.PhoenixPackage.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use IEEE.std_logic_unsigned.all;

entity topNoC is
end;

architecture topNoC of topNoC is
	
	signal clock : regNrot:=(others=>'0');
	signal reset : std_logic;
	signal clock_rx: regNrot:=(others=>'0');
	signal rx, credit_o: regNrot;
	signal clock_tx, tx, credit_i, testLink_i, testLink_o: regNrot;
	signal data_in, data_out : arrayNrot_regflit;
	signal currentTime: std_logic_vector(4*TAM_FLIT-1 downto 0) := (others=>'0');
  
  function string_to_int(x_str : string; radix : positive range 2 to 36 := 10) return integer is
    constant STR_LEN          : integer := x_str'length;
    
    variable chr_val          : integer;
    variable ret_int          : integer := 0;
    variable do_mult          : boolean := true;
    variable power            : integer := 0;
  begin
    for i in STR_LEN downto 1 loop
      case x_str(i) is
        when '0'       =>   chr_val := 0;
        when '1'       =>   chr_val := 1;
        when '2'       =>   chr_val := 2;
        when '3'       =>   chr_val := 3;
        when '4'       =>   chr_val := 4;
        when '5'       =>   chr_val := 5;
        when '6'       =>   chr_val := 6;
        when '7'       =>   chr_val := 7;
        when '8'       =>   chr_val := 8;
        when '9'       =>   chr_val := 9;
        when 'A' | 'a' =>   chr_val := 10;
        when 'B' | 'b' =>   chr_val := 11;
        when 'C' | 'c' =>   chr_val := 12;
        when 'D' | 'd' =>   chr_val := 13;
        when 'E' | 'e' =>   chr_val := 14;
        when 'F' | 'f' =>   chr_val := 15;
		
        when others => report "Illegal character for conversion for string to integer" severity failure;
      end case;
      if chr_val >= radix then report "Illagel character at this radix" severity failure; end if;
        
      if do_mult then
        ret_int := ret_int + (chr_val * (radix**power));
      end if;
        
      power := power + 1;
          
    end loop;  
    return ret_int;   
  end function;

begin
	reset <= '1', '0' after 10 ns;
	clock <= not clock after 10 ns;
	clock_rx <= not clock_rx after 10 ns;	
	--credit_i <= (others=>'1');
	credit_i <= tx;
	testLink_i <= (others=>'0');

	NOC: Entity work.NOC
	port map(
		clock         => clock,
		reset         => reset,
		clock_rxLocal => clock_rx,
		rxLocal       => rx,
		data_inLocal_flit  => data_in,
		credit_oLocal => credit_o,
		clock_txLocal => clock_tx,
		txLocal       => tx,
		data_outLocal_flit => data_out,
		credit_iLocal => credit_i
		);
		

-- 0: destino do pacote
-- 1: tamanho do pacote
-- 2: nodo origem
-- 3 a 6: timestamp do nodo de origem
-- 7 a 8: numero de sequencia do pacote
-- 9 a 12: timestamp de entrada na rede
-- 13+: payload

process (reset, clock(0))
begin
	if (reset = '1') then
		currentTime <= (others=>'0');
	elsif (rising_edge(clock(0))) then
		currentTime <= currentTime + 1;
	end if;
end process;
		
read_file: for i in 0 to (NROT-1) generate
begin
	process
		file file_pointer: text;
		variable line_num : line; -- linha lida
		variable tmp_word: string (1 to 500);
		variable tmp_line: line;
		variable line_counter: integer := 0;
		variable char_pointer: integer;
		variable char_pointer_tmp: integer;
		variable pkt_time: integer := 0;
		variable str_size: integer;
		variable flit_counter: integer;
		variable timestampNet: std_logic_vector(4*TAM_FLIT-1 downto 0) := (others=>'0');
		variable pkt_size: regflit;
		variable control_pkt: std_logic;
		--variable fault_bits: regphit;
	begin
		file_open(file_pointer,"In/in"&to_hstring(NUMBER_TO_ADDRESS(i))&".txt",READ_MODE);
		while not endfile(file_pointer) loop

			-- limpa a string tmp_word
			for j in 1 to tmp_word'length loop
				tmp_word(j) := NUL;
			end loop;

			readline(file_pointer,line_num);
			line_counter := line_counter + 1;
			char_pointer := line_num'low;
			str_size := 0;
			-- copia a string da linha lida ate encontrar espaco (ira copiar o tempo do inicio do pacote)
			while (line_num(char_pointer) /= ' ' and char_pointer <= line_num'high) loop
				tmp_word(char_pointer) := line_num(char_pointer);
				char_pointer := char_pointer + 1;
				str_size := str_size + 1;
			end loop;

			-- converte string lida (tempo do inicio do pacote) para integer
			pkt_time := string_to_int(tmp_word(1 to str_size),16);
			
			rx(i) <= '0';
			data_in(i) <= (others=>'0');

			-- loop esperando ate' tempo para injetar o pacote
			while not (currentTime >= pkt_time) loop
				wait for 1 ns;
			end loop;
			
			-- limpa a string tmp_word
			for j in 1 to tmp_word'length loop
				tmp_word(j) := NUL;
			end loop;

			char_pointer := char_pointer + 1;
			char_pointer_tmp := 1;
			-- copia a string da linha lida
			while (char_pointer_tmp <= line_num'high) loop
				tmp_word(char_pointer_tmp) := line_num(char_pointer_tmp);
				char_pointer_tmp := char_pointer_tmp + 1;
			end loop;
			
			flit_counter := 0;
			control_pkt := '0';
			
			-- leitura da linha e injetado os flits lidos
			while (char_pointer < line_num'high) loop
			
				if (credit_o(i)='1' and tmp_word(char_pointer) /= NUL) then
				
					rx(i) <= '1'; 
					if (flit_counter = 0) then -- captura o timestamp de entrada na rede
						timestampNet := currentTime;
					end if;
					
					if (flit_counter = 1 and control_pkt='0') then
						pkt_size := CONV_VECTOR(tmp_word, char_pointer) &
									CONV_VECTOR(tmp_word, char_pointer + 1) &
									CONV_VECTOR(tmp_word, char_pointer + 2) &
									CONV_VECTOR(tmp_word, char_pointer + 3);
									
						pkt_size := pkt_size + 4; -- reservar +4 espacos para o timestamp de entrada na rede
						data_in(i) <= pkt_size;
						char_pointer := char_pointer + 5;
					
					elsif (flit_counter>=9 and flit_counter<=12 and control_pkt='0') then
						data_in(i) <= timestampNet(((13-flit_counter)*TAM_FLIT-1) downto ((12-flit_counter)*TAM_FLIT));
					else
						data_in(i) <= CONV_VECTOR(tmp_word, char_pointer) &
									  CONV_VECTOR(tmp_word, char_pointer + 1) &
									  CONV_VECTOR(tmp_word, char_pointer + 2) &
									  CONV_VECTOR(tmp_word, char_pointer + 3);
									  
						if (flit_counter = 0) then
							control_pkt := CONV_VECTOR(tmp_word, char_pointer)(TAM_FLIT/4-1);
						end if;
								   
						char_pointer := char_pointer + 5;
						
					end if;
					flit_counter := flit_counter + 1;
					
				else
					rx(i) <= '0';
					data_in(i) <= (others=>'0');
					if (tmp_word(char_pointer) = NUL) then
						exit;
					end if;
				end if;
						   
				wait for 20 ns; -- clock period
			end loop;

			-- fim da linha lida do arquivo e fim da injecao do pacote
			rx(i) <= '0';
			data_in(i) <= (others=>'0');
			
		end loop;
	wait;
	end process;
end generate;


    OutputModules: for i in 0 to (NROT-1) generate
        OM : Entity work.outputModule
        generic map(address => NUMBER_TO_ADDRESS(i))
        port map(
            clock => clock(i),
            tx => tx(i),
            data => data_out(i),
            currentTime => currentTime
        );
    end generate OutputModules;

end topNoC;
