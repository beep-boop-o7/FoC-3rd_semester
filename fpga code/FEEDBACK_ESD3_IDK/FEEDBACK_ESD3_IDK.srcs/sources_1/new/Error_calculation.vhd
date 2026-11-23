----------------------------------------------------------------------------------
-- Design Name: FOC Feedback System
-- Module Name: Error_calculation
--
-- Description:
-- Calculates the difference between measured and predicted
-- alpha-beta motor currents.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity Error_calculation is

    port(

        -- Measured currents
       
        ialpha_inPort : in signed(15 downto 0);
        ibeta_inPort  : in signed(15 downto 0);

        -- Predicted currents
       
        ihat_alpha_inPort : in signed(15 downto 0);
        ihat_beta_inPort  : in signed(15 downto 0);

        -- Current estimation errors

        alpha_error_out : out signed(15 downto 0);
        beta_error_out  : out signed(15 downto 0)

    );

end Error_calculation;


architecture Behavioral of Error_calculation is


begin


    alpha_error_out <= ialpha_inPort - ihat_alpha_inPort;

    beta_error_out <= ibeta_inPort - ihat_beta_inPort;


end Behavioral;
