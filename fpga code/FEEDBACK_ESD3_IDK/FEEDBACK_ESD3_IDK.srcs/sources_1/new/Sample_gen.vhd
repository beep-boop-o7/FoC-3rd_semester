
----------------------------------------------------------------------------------
-- Module Name: Sample_gen
-- Description:
-- Generates an observer sampling pulse.
-- FPGA clock: 12 MHz
-- Default observer frequency: 20 kHz
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Sample_Generator is

    generic (
        CLOCKS_PER_SAMPLE : positive := 600
    );

    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        sample_enable : out std_logic
    );

end Sample_Generator;


architecture Behavioral of Sample_Generator is

    signal counter    : integer range 0 to CLOCKS_PER_SAMPLE - 1 := 0;
    signal sample_reg : std_logic := '0';

begin

    process(clk)
    begin

        if rising_edge(clk) then

            if reset = '1' then

                counter    <= 0;
                sample_reg <= '0';

            else

                sample_reg <= '0';

                if counter = CLOCKS_PER_SAMPLE - 1 then

                    counter    <= 0;
                    sample_reg <= '1';

                else

                    counter <= counter + 1;

                end if;

            end if;

        end if;

    end process;

    sample_enable <= sample_reg;

end Behavioral;
