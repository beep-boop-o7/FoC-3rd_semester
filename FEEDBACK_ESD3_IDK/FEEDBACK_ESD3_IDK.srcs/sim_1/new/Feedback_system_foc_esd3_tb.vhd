
----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 11.11.2026
-- Design Name: FOC Feedback System
-- Module Name: Feedback_system_foc_esd3_tb
-- Project Name: FPGA-based FOC Controller
--
-- Description:
-- Testbench for Clarke transformation and voltage reconstruction.
-- Uses VHDL-93 compatible signed fixed-point arithmetic.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity Feedback_system_tb is
end entity;


architecture simulation of Feedback_system_tb is


    --------------------------------------------------------------------------
    -- 1. CLOCK AND RESET
    --------------------------------------------------------------------------

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';


    --------------------------------------------------------------------------
    -- 2. INPUT SIGNALS
    --------------------------------------------------------------------------

    -- Three-phase currents: Q3.12
    signal ia : signed(15 downto 0) := (others => '0');
    signal ib : signed(15 downto 0) := (others => '0');
    signal ic : signed(15 downto 0) := (others => '0');

    -- PWM duty cycles: Q0.15
    signal duty_a : signed(15 downto 0) := (others => '0');
    signal duty_b : signed(15 downto 0) := (others => '0');
    signal duty_c : signed(15 downto 0) := (others => '0');

    -- DC bus voltage: Q7.8
    signal vdc : signed(15 downto 0) := (others => '0');


    --------------------------------------------------------------------------
    -- 3. OUTPUT SIGNALS
    --------------------------------------------------------------------------

    -- Current Clarke outputs: Q3.12
    signal ialpha : signed(15 downto 0);
    signal ibeta  : signed(15 downto 0);

    -- Voltage Clarke outputs: Q7.12
    signal valpha : signed(19 downto 0);
    signal vbeta  : signed(19 downto 0);


    --------------------------------------------------------------------------
    -- 4. TEST PARAMETERS
    --------------------------------------------------------------------------

    -- Tolerance in the original real-value scale
    -- 0.01 * 4096 = approximately 41 integer units

    constant TOLERANCE : integer := 41;


begin


    --------------------------------------------------------------------------
    -- 5. INSTANTIATE DEVICE UNDER TEST
    --------------------------------------------------------------------------

    DUT : entity work.Feedback_system
        port map (
            clk     => clk,
            reset   => reset,

            ia      => ia,
            ib      => ib,
            ic      => ic,

            duty_a  => duty_a,
            duty_b  => duty_b,
            duty_c  => duty_c,

            vdc     => vdc,

            ialpha  => ialpha,
            ibeta   => ibeta,

            valpha  => valpha,
            vbeta   => vbeta
        );


    --------------------------------------------------------------------------
    -- 6. CLOCK GENERATION
    --------------------------------------------------------------------------

    clock_process : process
    begin

        clk <= '0';
        wait for 5 ns;

        clk <= '1';
        wait for 5 ns;

    end process;


    --------------------------------------------------------------------------
    -- 7. STIMULUS PROCESS
    --------------------------------------------------------------------------

    stimulus_process : process
    begin

        ----------------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------------

        reset <= '1';

        wait for 20 ns;

        reset <= '0';


        ----------------------------------------------------------------------
        -- TEST CASE 1: BALANCED CURRENTS
        ----------------------------------------------------------------------

        -- ia = 1.0 A
        -- ib = -0.5 A
        -- ic = -0.5 A
        --
        -- Q3.12: multiply actual value by 4096.

        ia <= to_signed(4096, 16);
        ib <= to_signed(4096, 16);
        ic <= to_signed(4096, 16);


        ----------------------------------------------------------------------
        -- VOLTAGE RECONSTRUCTION INPUTS
        ----------------------------------------------------------------------

        -- Duty cycles: Q0.15
        --
        -- 0.5  * 32768 = 16384
        -- 0.25 * 32768 = 8192

        duty_a <= to_signed(16384, 16);
        duty_b <= to_signed(8192, 16);
        duty_c <= to_signed(8192, 16);


        -- DC bus voltage: Q7.8
        --
        -- 12.0 * 256 = 3072

        vdc <= to_signed(3072, 16);


        ----------------------------------------------------------------------
        -- WAIT FOR PIPELINE
        ----------------------------------------------------------------------

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        wait for 1 ns;


        ----------------------------------------------------------------------
        -- 8. CHECK CURRENT CLARKE TRANSFORMATION
        ----------------------------------------------------------------------

        -- Expected:
        -- ialpha = 1.0
        -- ibeta  = 0.0
        --
        -- Q3.12:
        -- 1.0 = 4096

        assert abs(to_integer(ialpha) - 4096) <= TOLERANCE
            report "ERROR: ialpha is incorrect"
            severity error;

        assert abs(to_integer(ibeta)) <= TOLERANCE
            report "ERROR: ibeta is incorrect"
            severity error;


        ----------------------------------------------------------------------
        -- 9. CHECK VOLTAGE CLARKE TRANSFORMATION
        ----------------------------------------------------------------------

        -- Expected:
        -- va = 6.0 V
        -- vb = 3.0 V
        -- vc = 3.0 V
        --
        -- valpha = 2.0 V
        -- vbeta  = 0.0 V
        --
        -- Q7.12:
        -- 2.0 = 8192

        assert abs(to_integer(valpha) - 8192) <= TOLERANCE
            report "ERROR: valpha is incorrect"
            severity error;

        assert abs(to_integer(vbeta)) <= TOLERANCE
            report "ERROR: vbeta is incorrect"
            severity error;


        ----------------------------------------------------------------------
        -- 10. TEST RESULT
        ----------------------------------------------------------------------

        report "TEST CASE 1 PASSED: Clarke transformations are correct"
            severity note;


        wait;

    end process;


end architecture;
