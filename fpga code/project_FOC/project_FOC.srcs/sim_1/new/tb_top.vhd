
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB2_top is
end TB2_top;

architecture sim of TB2_top is
    signal clk     : std_logic := '0';
    signal theta   : signed(15 downto 0) := to_signed(-8192, 16);
    

    signal cosA : std_logic_vector(15 downto 0);
    signal sinA : std_logic_vector(15 downto 0);

begin

    clk <= not clk after 5 ns;

    process(clk)
    begin
        if rising_edge(clk) then
            if theta >= to_signed(8184, 16) then
                theta <= to_signed(-8192, 16);
            else
                theta <= theta + 8;
            end if;
        end if;
    end process;

    

    cosA <= cordicA(31 downto 16);
    sinA <= cordicA(15 downto 0);

end sim;
