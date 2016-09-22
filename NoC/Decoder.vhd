library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use IEEE.Numeric_std.all;
use work.HammingPack16.all;
use work.PhoenixPackage.all;

entity HAM_DEC is
port
(
	data_in          : in  regflit; -- data input
	parity_in        : in  reghamm; -- parity input
	data_out         : out regflit; -- data output (corrected data)
  	parity_out       : out reghamm; -- parity output (corrected parity)
  	credit_out       : out std_logic_vector(2 downto 0)   -- status output (hamming results status)
);
end HAM_DEC;

architecture HAM_DEC of HAM_DEC is

begin  

process(data_in, parity_in)

	                                              
	--overall mod-2 of all bits
	variable P0 : Std_logic;
					                                              
	--syndrome
	variable Synd : Std_logic_vector(5 downto 1);

begin 
		  
	--calculate overall parity of all bits---------               
	P0 := xor_reduce(data_in & parity_in); 
	----------------------------------------------

      --generate each syndrome bit C1 to C4---------------------------
      Synd(1) := xor_reduce((data_in and MaskP1) & parity_in(1));
      Synd(2) := xor_reduce((data_in and MaskP2) & parity_in(2));
      Synd(3) := xor_reduce((data_in and MaskP4) & parity_in(3));
      Synd(4) := xor_reduce((data_in and MaskP8) & parity_in(4)); 
      Synd(5) := xor_reduce((data_in and MaskP16) & parity_in(5)); 
		----------------------------------------------------------------  
		
	if (Synd = "0000") and (P0 = '0') then  --no errors 
	   		
		credit_out <= NE;
		data_out <= data_in; 
		parity_out <= parity_in;     
		null; --accept default o/p's assigned above
				
	elsif P0 = '1' then --single error (or odd no of errors!)  
	
   		credit_out <= EC;	
		data_out <= data_in; 
		parity_out <= parity_in;	
		            
		--correct single error			            
		case to_integer(unsigned(Synd)) is   
			when 0  => parity_out(0) <= not parity_in(0);
			when 1  => parity_out(1) <= not parity_in(1);
			when 2  => parity_out(2) <= not parity_in(2);
			when 3  => data_out(0)   <= not data_in(0);
			when 4  => parity_out(3) <= not parity_in(3);
			when 5  => data_out(1)   <= not data_in(1);
			when 6  => data_out(2)   <= not data_in(2);
			when 7  => data_out(3)   <= not data_in(3);				  
			when 8  => parity_out(4) <= not parity_in(4);				  
			when 9  => data_out(4)   <= not data_in(4);
			when 10 => data_out(5)   <= not data_in(5);
			when 11 => data_out(6)   <= not data_in(6);
			when 12 => data_out(7)   <= not data_in(7);	  
			when 13 => data_out(8)   <= not data_in(8);				  
			when 14 => data_out(9)   <= not data_in(9);				  
			when 15 => data_out(10)   <= not data_in(10);				
			when 16 => parity_out(5) <= not parity_in(5);		  		
			when 17 => data_out(11)   <= not data_in(11);				  
			when 18 => data_out(12)   <= not data_in(12);				  				  
			when 19 => data_out(13)   <= not data_in(13);				  																				  
			when 20 => data_out(14)   <= not data_in(14);				  				  
			when 21 => data_out(15)   <= not data_in(15);		  
			when others => data_out   <= "0000000000000000"; parity_out <= "000000";		
		end case;

	elsif (P0 = '0') and (Synd /= "00000") then --double error
     		credit_out <= ED;			
		data_out <= "0000000000000000";
		parity_out <= "000000";
	end if;
end process;

end HAM_DEC;