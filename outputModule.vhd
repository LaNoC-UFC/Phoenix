library IEEE;
use IEEE.std_logic_1164.all;
use STD.textio.all;
use IEEE.std_logic_unsigned.all;
use work.PhoenixPackage.all;

entity outputModule is
generic(
    address: regflit
);
port(
    clock:          in std_logic;
    tx:             in std_logic;
    data:           in regflit;
    currentTime:    std_logic_vector(4*TAM_FLIT-1 downto 0)
);
end;

architecture outputModule of outputModule is
begin

    process(clock, tx, data, currentTime)
        variable cont : integer := 0;
        variable remaining_flits : std_logic_vector(TAM_FLIT-1 downto 0) := (others=>'0');
        file my_output : TEXT open WRITE_MODE is "Out/out"&to_hstring(address)&".txt";
        variable my_output_line : LINE;
        variable timeSourceCore: std_logic_vector ((TAM_FLIT*4)-1 downto 0) := (others=>'0');
        variable timeSourceNet: std_logic_vector ((TAM_FLIT*4)-1 downto 0) := (others=>'0');
        variable timeTarget: std_logic_vector ((TAM_FLIT*4)-1 downto 0) := (others=>'0');
        variable aux_latency: std_logic_vector ((TAM_FLIT*4)-1 downto 0) := (others=>'0'); --latência desde o tempo de criação do pacote (em decimal)
        variable control_pkt: std_logic;
    begin

        if(clock'event and clock='0' and tx='1')then
            -- DADOS DE CONTROLE:
            if (cont = 0) then -- destino
                write(my_output_line, string'(to_hstring(data)));
                write(my_output_line, string'(" "));
                cont := 1;
                control_pkt := data((TAM_FLIT-1));

            elsif (cont = 1) then -- tamanho
                write(my_output_line, string'(to_hstring(data)));
                write(my_output_line, string'(" "));
                remaining_flits := data;
                cont := 2;
            -- DADOS DO PAYLOAD:
            elsif (remaining_flits > 1) then
                remaining_flits := remaining_flits - 1; -- vai sair quando remaining_flits for 0

                if (cont >= 3 and cont <= 6 and control_pkt='0') then -- captura timestamp
                    timeSourceCore((TAM_FLIT*(7-cont)-1) downto (TAM_FLIT*(6-cont))) := data;
                end if;

                if (cont >= 9 and cont <= 12 and control_pkt='0') then -- captura timestamp
                    timeSourceNet((TAM_FLIT*(13-cont)-1) downto (TAM_FLIT*(12-cont))) := data;
                end if;

                write(my_output_line, string'(to_hstring(data)));
                write(my_output_line, string'(" "));

                cont := cont + 1;
            -- ultimo flit do pacote
            else
                write(my_output_line, string'(to_hstring(data)));
                --writeline(my_output, my_output_line);
                cont := 0;
                if (control_pkt='0') then
                    timeTarget := currentTime;
                    for j in (TAM_FLIT/4) downto 1 loop
                        write(my_output_line, string'(" "));
                        write(my_output_line, string'(to_hstring(timeTarget( TAM_FLIT*j-1 downto TAM_FLIT*(j-1) ))));
                    end loop;

                    write(my_output_line, string'(" "));
                    write(my_output_line, string'(integer'image(CONV_INTEGER(timeSourceCore((TAM_FLIT*2)-1 downto 0)))));

                    write(my_output_line, string'(" "));
                    write(my_output_line, string'(integer'image(CONV_INTEGER(timeSourceNet((TAM_FLIT*2)-1 downto 0)))));

                    write(my_output_line, string'(" "));
                    write(my_output_line, string'(integer'image(CONV_INTEGER(timeTarget((TAM_FLIT*2)-1 downto 0)))));

                    write(my_output_line, string'(" "));
                    aux_latency := (timeTarget-timeSourceCore);
                    write(my_output_line, string'(integer'image(CONV_INTEGER(aux_latency((TAM_FLIT*2)-1 downto 0)))));

                    write(my_output_line, string'(" "));
                    write(my_output_line, string'("0"));

                    writeline(my_output, my_output_line);
                end if;
            end if;
        end if; --end if clock'event...
    end process;

end outputModule;
