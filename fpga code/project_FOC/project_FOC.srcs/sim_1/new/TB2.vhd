
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB2_top is
end TB2_top;

architecture sim of TB2_top is
    signal clk     : std_logic := '0';
    signal theta   : signed(15 downto 0) := to_signed(-8192, 16);
    signal cordicA : std_logic_vector(31 downto 0);

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

    cordic_a : entity work.cordic_0
    port map(
        aclk => clk,
        s_axis_phase_tvalid => '1',
        s_axis_phase_tdata => std_logic_vector(theta),
        m_axis_dout_tvalid => open,
        m_axis_dout_tdata => cordicA
    );

    cosA <= cordicA(31 downto 16);
    sinA <= cordicA(15 downto 0);

end sim;
