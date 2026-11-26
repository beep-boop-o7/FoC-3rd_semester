
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HFI_Estimator is
    generic (
        DEMOD_LPF_ALPHA_Q15 : integer := 1024;
        DEMOD_POLARITY      : integer := 1;

        ERROR_GAIN_Q15      : integer := 32767;
        ERROR_POLARITY      : integer := 1;

        PLL_KP_Q15          : integer := 4096;
        PLL_KI_Q15          : integer := 64;
        OMEGA_LIMIT_Q16     : integer := 524288
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- Timing
        sample_enable : in std_logic;

        -- High-frequency current from HF_Current_Extraction
        hf_valid : in std_logic;
        ihf_alpha : in signed(15 downto 0);
        ihf_beta  : in signed(15 downto 0);

        -- Normalized injection carrier
        injection_carrier : in signed(15 downto 0);

        -- Estimated rotor position and speed
        theta_est : out unsigned(7 downto 0);
        omega_est : out signed(31 downto 0);
        pll_valid : out std_logic;

        -- Debug signals
        sin_theta_debug : out signed(15 downto 0);
        cos_theta_debug : out signed(15 downto 0);

        demodulated_q_debug : out signed(15 downto 0);
        position_error_debug : out signed(15 downto 0);

        demodulated_valid_debug : out std_logic;
        position_error_valid_debug : out std_logic
    );
end HFI_Estimator;

architecture Structural of HFI_Estimator is

    -- PLL angle
    signal theta_internal : unsigned(7 downto 0);

    -- Sin cos values calc from estimated value
    signal sin_theta_internal : signed(15 downto 0);
    signal cos_theta_internal : signed(15 downto 0);

    -- Demodulation
    signal demodulated_q_internal : signed(15 downto 0);
    signal demodulated_valid_internal : std_logic;

    -- Position error
    signal position_error_internal : signed(15 downto 0);
    signal position_error_valid_internal : std_logic;

    -- PLL speed
    signal omega_internal : signed(31 downto 0);
    signal pll_valid_internal : std_logic;

begin

    -- Sin cos lookup table

    SinCos_Inst : entity work.HFI_SinCos_LUT
        port map (
            theta_est => theta_internal,
            sin_theta => sin_theta_internal,
            cos_theta => cos_theta_internal
        );
        
    -- HFI demodulation

    Demodulation_Inst : entity work.HFI_Demodulation
        generic map (
            LPF_ALPHA_Q15 => DEMOD_LPF_ALPHA_Q15,
            DEMOD_POLARITY => DEMOD_POLARITY
        )
        port map (
            clk => clk,
            reset => reset,
            sample_enable => sample_enable,

            hf_valid => hf_valid,
            ihf_alpha => ihf_alpha,
            ihf_beta => ihf_beta,

            sin_theta => sin_theta_internal,
            cos_theta => cos_theta_internal,
            injection_carrier => injection_carrier,

            demodulated_q => demodulated_q_internal,
            demodulated_valid => demodulated_valid_internal
        );

    -- Position error calculation


    Position_Error_Inst : entity work.HFI_Position_Error
        generic map (
            ERROR_GAIN_Q15 => ERROR_GAIN_Q15,
            ERROR_POLARITY => ERROR_POLARITY
        )
        port map (
            clk => clk,
            reset => reset,
            sample_enable => sample_enable,

            demodulated_valid => demodulated_valid_internal,
            demodulated_q => demodulated_q_internal,

            position_error => position_error_internal,
            position_error_valid => position_error_valid_internal
        );

    -- HFI phase-locked loop


    PLL_Inst : entity work.HFI_PLL
        generic map (
            KP_Q15 => PLL_KP_Q15,
            KI_Q15 => PLL_KI_Q15,
            OMEGA_LIMIT_Q16 => OMEGA_LIMIT_Q16
        )
        port map (
            clk => clk,
            reset => reset,
            sample_enable => sample_enable,

            position_error_valid => position_error_valid_internal,
            position_error => position_error_internal,

            theta_est => theta_internal,
            omega_est => omega_internal,
            pll_valid => pll_valid_internal
        );

    -- Outputs


    theta_est <= theta_internal;
    omega_est <= omega_internal;
    pll_valid <= pll_valid_internal;

    sin_theta_debug <= sin_theta_internal;
    cos_theta_debug <= cos_theta_internal;

    demodulated_q_debug <= demodulated_q_internal;
    position_error_debug <= position_error_internal;

    demodulated_valid_debug <= demodulated_valid_internal;
    position_error_valid_debug <= position_error_valid_internal;

end Structural;
