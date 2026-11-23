----------------------------------------------------------------------------------
-- Testbench: HFI_Demodulation + HFI_Position_Error
--
-- Tests:
--   1. Positive q-axis HF current
--   2. Negative q-axis HF current
--   3. Zero q-axis HF current
--
-- No physical motor is required.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_HFI_Demodulation is
end TB_HFI_Demodulation;


architecture Behavioral of TB_HFI_Demodulation is

    constant CLK_PERIOD : time := 83.333 ns;

    signal clk                  : std_logic := '0';
    signal reset                : std_logic := '1';

    signal sample_enable        : std_logic := '1';
    signal hf_valid             : std_logic := '0';

    signal ihf_alpha            : signed(15 downto 0) := (others => '0');
    signal ihf_beta             : signed(15 downto 0) := (others => '0');

    signal sin_theta            : signed(15 downto 0) := (others => '0');
    signal cos_theta            : signed(15 downto 0) := (others => '0');

    signal injection_carrier    : signed(15 downto 0) := (others => '0');

    signal demodulated_q        : signed(15 downto 0);
    signal demodulated_valid    : std_logic;

    signal position_error       : signed(15 downto 0);
    signal position_error_valid : std_logic;

begin

    --------------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------------

    clk <= not clk after CLK_PERIOD / 2;


    --------------------------------------------------------------------------
    -- HFI Demodulation
    --------------------------------------------------------------------------

    HFI_Demodulation_inst : entity work.HFI_Demodulation

        generic map (
            LPF_ALPHA_Q15 => 1024
        )

        port map (
            clk               => clk,
            reset             => reset,

            sample_enable     => sample_enable,
            hf_valid          => hf_valid,

            ihf_alpha         => ihf_alpha,
            ihf_beta          => ihf_beta,

            sin_theta         => sin_theta,
            cos_theta         => cos_theta,

            injection_carrier => injection_carrier,

            demodulated_q     => demodulated_q,
            demodulated_valid => demodulated_valid
        );


    --------------------------------------------------------------------------
    -- HFI Position Error
    --------------------------------------------------------------------------

    HFI_Position_Error_inst : entity work.HFI_Position_Error

        generic map (
            ERROR_GAIN_Q15 => 32767,
            ERROR_POLARITY => 1
        )

        port map (
            clk                  => clk,
            reset                => reset,

            sample_enable        => sample_enable,
            demodulated_valid    => demodulated_valid,

            demodulated_q        => demodulated_q,

            position_error       => position_error,
            position_error_valid => position_error_valid
        );


    --------------------------------------------------------------------------
    -- Test sequence
    --------------------------------------------------------------------------

    process

    begin

        ----------------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------------

        reset <= '1';

        hf_valid <= '0'; 

        ihf_alpha <= (others => '0');
        ihf_beta  <= (others => '0');

        sin_theta <= (others => '0');
        cos_theta <= to_signed(32767, 16);

        injection_carrier <= to_signed(32767, 16);

        wait for 10 * CLK_PERIOD;

        reset <= '0';

        wait for 5 * CLK_PERIOD;


        ----------------------------------------------------------------------
        -- TEST 1: Positive q-axis HF current
        --
        -- theta = 0
        -- Ialpha = 0
        -- Ibeta  = +0.5
        -- Carrier = +1.0
        --
        -- Expected demodulated output: approximately +0.5
        ----------------------------------------------------------------------

        report "TEST 1: Positive q-axis current";

        ihf_alpha <= to_signed(0, 16);
        ihf_beta  <= to_signed(16384, 16);

        injection_carrier <= to_signed(32767, 16);

        hf_valid <= '1';

        wait for 200 * CLK_PERIOD;


        report "Positive test demodulated_q = " &
            integer'image(to_integer(demodulated_q));

        report "Positive test position_error = " &
            integer'image(to_integer(position_error));


        ----------------------------------------------------------------------
        -- TEST 2: Negative q-axis HF current
        --
        -- Ibeta = -0.5
        --
        -- Expected demodulated output: approximately -0.5
        ----------------------------------------------------------------------

        report "TEST 2: Negative q-axis current";

        ihf_beta <= to_signed(-16384, 16);

        wait for 200 * CLK_PERIOD;


        report "Negative test demodulated_q = " &
            integer'image(to_integer(demodulated_q));

        report "Negative test position_error = " &
            integer'image(to_integer(position_error));


        ----------------------------------------------------------------------
        -- TEST 3: Zero q-axis HF current
        --
        -- Expected demodulated output approaches zero
        ----------------------------------------------------------------------

        report "TEST 3: Zero q-axis current";

        ihf_beta <= to_signed(0, 16);

        wait for 200 * CLK_PERIOD;


        report "Zero test demodulated_q = " &
            integer'image(to_integer(demodulated_q));

        report "Zero test position_error = " &
            integer'image(to_integer(position_error));


        ----------------------------------------------------------------------
        -- End simulation
        ----------------------------------------------------------------------

        report "HFI DEMODULATION TESTS FINISHED";

        wait;

    end process;

end Behavioral;
