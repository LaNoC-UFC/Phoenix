library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity fifo_buffer is
    generic(
        BUFFER_DEPTH : positive;
        BUFFER_WIDTH : positive
    );
    port(
        reset :     in std_logic;
        clock :     in std_logic;
        head:       out std_logic_vector(BUFFER_WIDTH-1 downto 0);
        tail :      in std_logic_vector(BUFFER_WIDTH-1 downto 0);
        push :      in std_logic;
        pull :      in std_logic;
        counter :   out natural range 0 to BUFFER_DEPTH
    );
end;

architecture circular_fifo_buffer of fifo_buffer is

    type buff is array(0 to BUFFER_DEPTH - 1) of std_logic_vector(BUFFER_WIDTH-1 downto 0);
    subtype pointer is natural range 0 to BUFFER_DEPTH - 1;

    procedure increment_pointer(p: inout pointer) is
    begin
        if p = BUFFER_DEPTH - 1 then
            p := 0;
        else
            p := p + 1;
        end if;
    end increment_pointer;

    signal buf: buff := (others=>(others=>'0'));
    signal is_full : boolean;
    signal first: pointer;
    signal last: pointer;

begin

    head <= buf(first);
    counter <=  BUFFER_DEPTH when is_full else
                last - first when (last >= first) else
                BUFFER_DEPTH - (first - last);

    process(reset, clock)
        variable aux_first, aux_last: pointer;
        variable aux_is_full, is_empty : boolean;
    begin
        if reset = '1' then
            last <= 0;
            first <= 0;
            is_full <= false;
            is_empty := true;
        elsif rising_edge(clock) then
            aux_is_full := is_full;
            aux_last := last;
            aux_first := first;
            -- remove data
            if not is_empty and pull = '1' then
                increment_pointer(aux_first);
                aux_is_full := false;
                is_empty := (aux_first = aux_last);
            end if;
            -- append data
            if not aux_is_full and push = '1' then
                buf(aux_last) <= tail;
                increment_pointer(aux_last);
                is_empty := false;
                aux_is_full := (aux_last = aux_first);
            end if;
            is_full <= aux_is_full;
            last <= aux_last;
            first <= aux_first;
        end if;
    end process;

end circular_fifo_buffer;
