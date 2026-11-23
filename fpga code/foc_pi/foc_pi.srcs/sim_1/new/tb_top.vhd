library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_top is
end tb_top;

architecture sim of tb_top is
    signal sysclk : std_logic := '0';
    signal led    : std_logic_vector(1 downto 0);
begin

    -- 12 MHz clock: period 83.33 ns
    sysclk <= not sysclk after 41.665 ns;

    dut : entity work.top
        port map (
            sysclk => sysclk,
            led    => led
        );

end sim;