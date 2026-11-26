
----------------------------------------------------------------------------------
-- Design Name: HFI_Position_Error
-- Module Name: HFI_Position_Error
--
-- Description:
-- Conditions the demodulated HFI q-axis current response and produces
-- a normalized position error for the HFI PLL.
--
-- Input:
--   demodulated_q : Signed Q1.15 demodulated q-axis HFI response
--
-- Output:
--   position_error : Signed Q1.15 position error
--
-- ERROR_POLARITY:
--   +1 = Keep the input polarity
--   -1 = Reverse the input polarity
--
-- ERROR_GAIN_Q15:
--   Configurable Q1.15 scaling factor
--
-- VHDL-93 compatible.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HFI_Position_Error is

    generic (
        ERROR_GAIN_Q15 : integer := 32767;
        ERROR_POLARITY : integer := 1
    );

    port (
        clk                  : in  std_logic;
        reset                : in  std_logic;

        sample_enable        : in  std_logic;
        demodulated_valid    : in  std_logic;

        demodulated_q        : in  signed(15 downto 0);

        position_error       : out signed(15 downto 0);
        position_error_valid : out std_logic
    );

end HFI_Position_Error;


architecture Behavioral of HFI_Position_Error is

begin

    process(clk)

        variable product       : signed(31 downto 0);
        variable scaled_value  : signed(31 downto 0);

    begin

        if rising_edge(clk) then

            if reset = '1' then

                position_error       <= (others => '0');
                position_error_valid <= '0';

            else

                position_error_valid <= '0';

                if demodulated_valid = '1' then
                

                    -- Apply configurable position-error gain


                    product := demodulated_q * to_signed(ERROR_GAIN_Q15, 16);

                    scaled_value := shift_right(product, 15);



                    -- Apply configurable polarity

                    if ERROR_POLARITY = -1 then

                        scaled_value := -scaled_value;

                    end if;



                    -- Saturate to signed 16-bit 


                    if scaled_value > to_signed(32767, 32) then

                        position_error <= to_signed(32767, 16);

                    elsif scaled_value < to_signed(-32768, 32) then

                        position_error <= to_signed(-32768, 16);

                    else

                        position_error <=
                            resize(scaled_value, 16);

                    end if;


                    -- Signal that a new position error is available

                    position_error_valid <= '1';

                end if;

            end if;

        end if;

    end process;

end Behavioral;
