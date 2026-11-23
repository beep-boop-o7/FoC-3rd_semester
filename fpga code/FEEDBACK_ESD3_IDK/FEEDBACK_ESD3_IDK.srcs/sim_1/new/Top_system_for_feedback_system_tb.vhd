
----------------------------------------------------------------------------------
-- Testbench: Top_system_for_feedback_system_tb
--
-- Tests:
-- 1. Sample generation at 20 kHz using a 12 MHz FPGA clock.
-- 2. Current Clarke transformation.
-- 3. Voltage reconstruction and Clarke transformation.
-- 4. Motor current prediction.
-- 5. Current error calculation.
-- 6. Timing of error_valid.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Top_system_for_feedback_system_tb is
end Top_system_for_feedback_system_tb;


architecture Behavioral of Top_system_for_feedback_system_tb is


    --------------------------------------------------------------------------
    -- CLOCK CONFIGURATION
    --------------------------------------------------------------------------

    constant CLK_PERIOD : time := 83.333 ns;


    --------------------------------------------------------------------------
    -- TESTBENCH SIGNALS
    --------------------------------------------------------------------------

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';


    --------------------------------------------------------------------------
    -- THREE-PHASE CURRENTS
    --
    -- Q3.12
    --
    -- Initial values:
    -- ia =  0.1 A
    -- ib = -0.05 A
    -- ic = -0.05 A
    --------------------------------------------------------------------------

    signal ia : signed(15 downto 0) := to_signed(410, 16);
    signal ib : signed(15 downto 0) := to_signed(-205, 16);
    signal ic : signed(15 downto 0) := to_signed(-205, 16);


    --------------------------------------------------------------------------
    -- PWM DUTY CYCLES
    --
    -- Q0.15
    --
    -- Initial values:
    -- duty_a = 0.5
    -- duty_b = 0.0
    -- duty_c = 0.0
    --------------------------------------------------------------------------

    signal duty_a : signed(15 downto 0) := to_signed(16384, 16);
    signal duty_b : signed(15 downto 0) := to_signed(0, 16);
    signal duty_c : signed(15 downto 0) := to_signed(0, 16);


    --------------------------------------------------------------------------
    -- DC BUS VOLTAGE
    --
    -- Q7.8
    --
    -- 12 V = 12 * 256 = 3072
    --------------------------------------------------------------------------

    signal vdc : signed(15 downto 0) := to_signed(3072, 16);


    --------------------------------------------------------------------------
    -- ERROR OUTPUTS
    --------------------------------------------------------------------------

    signal a_system_error : std_logic_vector(15 downto 0);
    signal b_system_error : std_logic_vector(15 downto 0);

    signal error_valid : std_logic;


begin


    --------------------------------------------------------------------------
    -- 1. CLOCK GENERATION
    --------------------------------------------------------------------------

    clk <= not clk after CLK_PERIOD / 2;


    --------------------------------------------------------------------------
    -- 2. DEVICE UNDER TEST
    --------------------------------------------------------------------------

    DUT : entity work.Top_system_for_feedback_system

        generic map (

            CLOCKS_PER_SAMPLE => 600,

            RS_FIXED => 2048,

            K_FIXED => 205

        )

        port map (

            clk   => clk,
            reset => reset,

            ia => ia,
            ib => ib,
            ic => ic,

            duty_a => duty_a,
            duty_b => duty_b,
            duty_c => duty_c,

            vdc => vdc,

            a_system_error => a_system_error,
            b_system_error => b_system_error,

            error_valid => error_valid

        );


    --------------------------------------------------------------------------
    -- 3. RESET AND INPUT STIMULUS
    --------------------------------------------------------------------------

    stimulus_process : process

    begin

        ----------------------------------------------------------------------
        -- INITIAL RESET
        ----------------------------------------------------------------------

        reset <= '1';

        wait for 10 * CLK_PERIOD;

        wait until falling_edge(clk);

        reset <= '0';


        ----------------------------------------------------------------------
        -- FIRST ERROR RESULT
        --
        -- Wait for the motor model to complete its first prediction.
        ----------------------------------------------------------------------

        wait until error_valid = '1';

        report "First error result:" severity note;

        report "Alpha error (raw Q3.12) = "
            & integer'image(to_integer(signed(a_system_error)))
            severity note;

        report "Beta error (raw Q3.12) = "
            & integer'image(to_integer(signed(b_system_error)))
            severity note;


        ----------------------------------------------------------------------
        -- CHANGE MEASURED CURRENTS
        --
        -- ia =  0.2 A
        -- ib = -0.1 A
        -- ic = -0.1 A
        ----------------------------------------------------------------------

        wait until falling_edge(clk);

        ia <= to_signed(819, 16);
        ib <= to_signed(-410, 16);
        ic <= to_signed(-409, 16);


        ----------------------------------------------------------------------
        -- SECOND ERROR RESULT
        ----------------------------------------------------------------------

        wait until error_valid = '0';

        wait until error_valid = '1';

        report "Second error result:" severity note;

        report "Alpha error (raw Q3.12) = "
            & integer'image(to_integer(signed(a_system_error)))
            severity note;

        report "Beta error (raw Q3.12) = "
            & integer'image(to_integer(signed(b_system_error)))
            severity note;


        ----------------------------------------------------------------------
        -- CHANGE MEASURED CURRENTS AGAIN
        --
        -- ia =  0.3 A
        -- ib = -0.15 A
        -- ic = -0.15 A
        ----------------------------------------------------------------------

        wait until falling_edge(clk);

        ia <= to_signed(1229, 16);
        ib <= to_signed(-614, 16);
        ic <= to_signed(-615, 16);


        ----------------------------------------------------------------------
        -- THIRD ERROR RESULT
        ----------------------------------------------------------------------

        wait until error_valid = '0';

        wait until error_valid = '1';

        report "Third error result:" severity note;

        report "Alpha error (raw Q3.12) = "
            & integer'image(to_integer(signed(a_system_error)))
            severity note;

        report "Beta error (raw Q3.12) = "
            & integer'image(to_integer(signed(b_system_error)))
            severity note;


        ----------------------------------------------------------------------
        -- FINISH STIMULUS
        ----------------------------------------------------------------------

        report "Testbench stimulus completed." severity note;

        wait;

    end process;


    --------------------------------------------------------------------------
    -- 4. ERROR VALID TIMING CHECK
    --
    -- A new error should be produced every 600 clock cycles.
    --------------------------------------------------------------------------

    timing_check_process : process(clk)

        variable cycle_count : integer := 0;

        variable previous_error_cycle : integer := -1;

    begin

        if rising_edge(clk) then

            if reset = '1' then

                cycle_count := 0;

                previous_error_cycle := -1;

            else

                cycle_count := cycle_count + 1;


                if error_valid = '1' then

                    if previous_error_cycle /= -1 then

                        assert
                            (cycle_count - previous_error_cycle) = 600

                        report "ERROR: error_valid timing is incorrect!"

                        severity error;


                        report "Correct interval between error results: "
                            & integer'image(
                                cycle_count - previous_error_cycle
                              )
                            & " clock cycles."
                            severity note;

                    else

                        report "First valid error detected."
                            severity note;

                    end if;


                    previous_error_cycle := cycle_count;

                end if;

            end if;

        end if;

    end process;


end Behavioral;
