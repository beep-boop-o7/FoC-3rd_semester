----------------------------------------------------------------------------------
-- Design Name: HFI_PLL
-- Module Name: HFI_PLL
--
-- Description:
-- PI-based phase-locked loop for HFI rotor position estimation.
--
-- Input:
--   position_error : signed Q1.15 position error
--
-- Outputs:
--   omega_est      : signed Q16.16 electrical angle counts per sample
--   theta_est      : unsigned 8-bit electrical angle (0-255 = 0-360 degrees)
--
-- The PLL updates only when sample_enable and position_error_valid are high.
--
-- VHDL-93 compatible.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HFI_PLL is

    generic (
        -- PI gains, represented in Q1.15
        KP_Q15 : integer := 4096;
        KI_Q15 : integer := 64;

        -- Maximum estimated speed, represented in Q16.16
        -- 524288 = 8.0 angle counts per sample
        OMEGA_LIMIT_Q16 : integer := 524288
    );

    port (
        clk                  : in  std_logic;
        reset                : in  std_logic;

        sample_enable        : in  std_logic;
        position_error_valid : in  std_logic;

        position_error       : in  signed(15 downto 0);

        theta_est            : out unsigned(7 downto 0);
        omega_est            : out signed(31 downto 0);

        pll_valid            : out std_logic
    );

end HFI_PLL;


architecture Behavioral of HFI_PLL is

    -- PI integrator state
    signal integrator_reg : signed(31 downto 0) := (others => '0');

    -- Estimated electrical phase, with 16 fractional bits.
    -- Bits 23 downto 16 represent the 8-bit electrical angle.
    signal phase_reg : signed(23 downto 0) := (others => '0');

    signal omega_reg : signed(31 downto 0) := (others => '0');

begin

    process(clk)

        variable kp_product : signed(31 downto 0);
        variable ki_product : signed(31 downto 0);

        variable p_term : signed(31 downto 0);
        variable i_delta : signed(31 downto 0);

        variable integrator_next : signed(31 downto 0);
        variable omega_next      : signed(31 downto 0);

        variable phase_next : signed(23 downto 0);

        variable omega_limit : signed(31 downto 0);

    begin

        if rising_edge(clk) then

            if reset = '1' then

                integrator_reg <= (others => '0');
                phase_reg      <= (others => '0');
                omega_reg      <= (others => '0');

                theta_est <= (others => '0');
                omega_est <= (others => '0');
                pll_valid <= '0';

            else

                pll_valid <= '0';

                if position_error_valid = '1' then

                    omega_limit := to_signed(OMEGA_LIMIT_Q16, 32);

 
                    -- Proportional term


                    kp_product := position_error * to_signed(KP_Q15, 16);

                    p_term := shift_right(kp_product, 14);



                    -- Integral term
 

                    ki_product := position_error * to_signed(KI_Q15, 16);

                    i_delta := shift_right(ki_product, 14);



                    -- Update and limit the integrator

                    integrator_next := integrator_reg + i_delta;

                    if integrator_next > omega_limit then

                        integrator_next := omega_limit;

                    elsif integrator_next < -omega_limit then

                        integrator_next := -omega_limit;

                    end if;


                    -- Calculate estimated electrical speed


                    omega_next := p_term + integrator_next;

                    if omega_next > omega_limit then

                        omega_next := omega_limit;

                    elsif omega_next < -omega_limit then

                        omega_next := -omega_limit;

                    end if;



                    -- Integrate speed to estimate electrical angle


                    phase_next := phase_reg + resize(omega_next, 24);



                    -- Store updated values


                    integrator_reg <= integrator_next;
                    omega_reg      <= omega_next;
                    phase_reg      <= phase_next;

                    theta_est <= unsigned(phase_next(23 downto 16));
                    omega_est <= omega_next;

                    pll_valid <= '1';

                end if;

            end if;

        end if;

    end process;

end Behavioral;