
----------------------------------------------------------------------------------
-- Testbench: TB_HFI_PLL
--
-- Tests:
-- 1. Zero position error
-- 2. Positive position error
-- 3. Zero position error after positive input
-- 4. Negative position error
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_HFI_PLL is
end TB_HFI_PLL;


architecture Behavioral of TB_HFI_PLL is

    constant CLK_PERIOD : time := 83.333 ns;

    signal clk                  : std_logic := '0';
    signal reset                : std_logic := '1';

    signal sample_enable        : std_logic := '1';
    signal position_error_valid : std_logic := '1';

    signal position_error       : signed(15 downto 0)
                                  := (others => '0');

    signal theta_est            : unsigned(7 downto 0);
    signal omega_est            : signed(31 downto 0);

    signal pll_valid            : std_logic;

begin

    ------------------------------------------------------------
    -- CLOCK GENERATOR
    ------------------------------------------------------------

    clk <= not clk after CLK_PERIOD / 2;


    ------------------------------------------------------------
    -- PLL INSTANCE
    ------------------------------------------------------------

    DUT : entity work.HFI_PLL

        generic map (
            KP_Q15           => 4096,
            KI_Q15           => 64,
            OMEGA_LIMIT_Q16  => 524288
        )

        port map (
            clk                  => clk,
            reset                => reset,

            sample_enable        => sample_enable,
            position_error_valid => position_error_valid,

            position_error       => position_error,

            theta_est            => theta_est,
            omega_est            => omega_est,

            pll_valid            => pll_valid
        );


    ------------------------------------------------------------
    -- TEST SEQUENCE
    ------------------------------------------------------------

    process

    begin

        --------------------------------------------------------
        -- 1. RESET
        --------------------------------------------------------

        reset <= '1';
        position_error <= (others => '0');

        wait for 5 * CLK_PERIOD;

        wait until falling_edge(clk);

        reset <= '0';


        --------------------------------------------------------
        -- 2. ZERO POSITION ERROR
        --------------------------------------------------------

        position_error <= to_signed(0,16);

        for i in 0 to 19 loop
            wait until rising_edge(clk);
        end loop;


        --------------------------------------------------------
        -- 3. POSITIVE POSITION ERROR
        --------------------------------------------------------

        wait until falling_edge(clk);

        position_error <= to_signed(16384,16);

        for i in 0 to 99 loop
            wait until rising_edge(clk);
        end loop;


        --------------------------------------------------------
        -- 4. ZERO POSITION ERROR AGAIN
        --------------------------------------------------------

        wait until falling_edge(clk);

        position_error <= to_signed(0,16);

        for i in 0 to 19 loop
            wait until rising_edge(clk);
        end loop;


        --------------------------------------------------------
        -- 5. NEGATIVE POSITION ERROR
        --------------------------------------------------------

        wait until falling_edge(clk);

        position_error <= to_signed(-16384,16);

        for i in 0 to 199 loop
            wait until rising_edge(clk);
        end loop;


        --------------------------------------------------------
        -- 6. FINISH
        --------------------------------------------------------

        wait until falling_edge(clk);

        position_error <= to_signed(0,16);

        wait for 20 * CLK_PERIOD;

        wait;

    end process;

end Behavioral;
