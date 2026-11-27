
----------------------------------------------------------------------------------
-- Module Name: HFI_Carrier_Generator
--
-- FPGA clock:              12 MHz
-- PWM/PDM frequency:       400 kHz
-- HFI injection frequency: 50 kHz
-- Injection updates:       400 kHz
-- Samples per HFI cycle:   8
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HFI_Carrier_Generator is
    generic (
        INJECTION_AMPLITUDE : integer := 2048
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        injection_update : out std_logic;
        sample_enable    : out std_logic;

        injection_out : out signed(15 downto 0)
    );
end HFI_Carrier_Generator;

architecture Behavioral of HFI_Carrier_Generator is

    signal clock_count : integer range 0 to 29 := 0;
    signal phase_index : integer range 0 to 7 := 0;

    signal injection_reg : signed(15 downto 0) := (others => '0');

    signal injection_update_reg : std_logic := '0';
    signal sample_enable_reg : std_logic := '0';

    function sine_value(index : integer) return signed is
        variable value : integer;
    begin
        case index is
            when 0 => value := 0;
            when 1 => value := 1448;
            when 2 => value := 2048;
            when 3 => value := 1448;
            when 4 => value := 0;
            when 5 => value := -1448;
            when 6 => value := -2048;
            when 7 => value := -1448;
            when others => value := 0;
        end case;

        return to_signed(
            (value * INJECTION_AMPLITUDE) / 2048,
            16
        );
    end function;

begin

    injection_out    <= injection_reg;
    injection_update <= injection_update_reg;
    sample_enable    <= sample_enable_reg;

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                clock_count <= 0;
                phase_index <= 0;

                injection_reg <= (others => '0');

                injection_update_reg <= '0';
                sample_enable_reg <= '0';

            else

                injection_update_reg <= '0';
                sample_enable_reg <= '0';

                -- Sample trigger at the midpoint of the PWM period.
                if clock_count = 14 then
                    sample_enable_reg <= '1';
                end if;

                -- Update injection reference once per PWM period.
                if clock_count = 29 then

                    injection_reg <= sine_value(phase_index);

                    injection_update_reg <= '1';

                    if phase_index = 7 then
                        phase_index <= 0;
                    else
                        phase_index <= phase_index + 1;
                    end if;

                    clock_count <= 0;

                else
                    clock_count <= clock_count + 1;
                end if;

            end if;
        end if;
    end process;

end Behavioral;
