library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.CONV_STD_LOGIC_VECTOR;
use work.PhoenixPackage.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use IEEE.std_logic_unsigned.all;

entity inputModule is
generic(
    address: regflit
);
port(
    done:             out std_logic;
    data:        out regflit;  
    enable:       in std_logic;
    currentTime:    in std_logic_vector(4*TAM_FLIT-1 downto 0)
);
end;

architecture inputModule of inputModule is

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

    process
        file file_pointer: text;
        variable line_num : line;
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
        file_open(file_pointer,"In/in"&to_hstring(address)&".txt",READ_MODE);
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
			
            done <= '0';
            data <= (others=>'0');

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
			
                if (enable='1' and tmp_word(char_pointer) /= NUL) then
				
                    done <= '1'; 
                    if (flit_counter = 0) then -- captura o timestamp de entrada na rede
                        timestampNet := currentTime;
                    end if;
					
                    if (flit_counter = 1 and control_pkt='0') then
                        pkt_size := CONV_VECTOR(tmp_word, char_pointer) &
                                    CONV_VECTOR(tmp_word, char_pointer + 1) &
                                    CONV_VECTOR(tmp_word, char_pointer + 2) &
                                    CONV_VECTOR(tmp_word, char_pointer + 3);
									
                        pkt_size := pkt_size + 4; -- reservar +4 espacos para o timestamp de entrada na rede
                        data <= pkt_size;
                        char_pointer := char_pointer + 5;
					
                    elsif (flit_counter>=9 and flit_counter<=12 and control_pkt='0') then
                        data <= timestampNet(((13-flit_counter)*TAM_FLIT-1) downto ((12-flit_counter)*TAM_FLIT));
                    else
                        data <= CONV_VECTOR(tmp_word, char_pointer) &
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
                    done <= '0';
                    data <= (others=>'0');
                    if (tmp_word(char_pointer) = NUL) then
                        exit;
                    end if;
                end if;
						   
                wait for 20 ns; -- clock period
            end loop;

            -- fim da linha lida do arquivo e fim da injecao do pacote
            done <= '0';
            data <= (others=>'0');
			
        end loop;
    wait;
    end process;

end inputModule;
