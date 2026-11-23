
----------------------------------------------------------------------------------
-- Design Name: HFI_Top
-- Module Name: HFI_Top
--
-- Description:
-- Top-level integration of the HFI subsystem.
--
-- Modules:
--   1. HFI
--   2. HF_Current_Extraction
--   3. HFI_Estimator
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HFI_Top is
    generic (
        -- HFI configuration
        HFI_HALF_PERIOD       : integer := 119;
        HFI_SHIFT_SCALE       : integer := 4;

        -- HF current extraction
        CURRENT_LPF_ALPHA_Q15 : integer := 512;

        -- HFI estimator configuration
        DEMOD_LPF_ALPHA_Q15   : integer := 1024;
        DEMOD_POLARITY        : integer := 1;

        ERROR_GAIN_Q15        : integer := 32767;
        ERROR_POLARITY        : integer := 1;

        PLL_KP_Q15            : integer := 4096;
        PLL_KI_Q15            : integer := 64;
        OMEGA_LIMIT_Q16       : integer := 524288
    );

    port (
        clk : in std_logic;
        reset : in std_logic;

        -- FOC voltage reference
        vd_ref_in : in signed(15 downto 0);
        vd_ref_out : out signed(15 downto 0);

        -- Measured motor phase currents
        ia : in signed(15 downto 0);
        ib : in signed(15 downto 0);
        ic : in signed(15 downto 0);

        -- Estimated rotor position and speed
        theta_est : out unsigned(7 downto 0);
        omega_est : out signed(31 downto 0);
        pll_valid : out std_logic;

        -- HFI timing/debug outputs
        clk50k_debug : out std_logic;
        sample_enable_debug : out std_logic;
        sine_out_debug : out signed(15 downto 0);

        -- Clarke transform debug outputs
        ialpha_debug : out signed(15 downto 0);
        ibeta_debug : out signed(15 downto 0);

        -- High-frequency current debug outputs
        ihf_alpha_debug : out signed(15 downto 0);
        ihf_beta_debug : out signed(15 downto 0);
        hf_valid_debug : out std_logic;

        -- Estimator debug outputs
        sin_theta_debug : out signed(15 downto 0);
        cos_theta_debug : out signed(15 downto 0);

        demodulated_q_debug : out signed(15 downto 0);
        position_error_debug : out signed(15 downto 0);

        demodulated_valid_debug : out std_logic;
        position_error_valid_debug : out std_logic
    );
end HFI_Top;


architecture Structural of HFI_Top is
    -- Internal signals

    -- HFI timing
    signal sample_enable_int : std_logic;

    -- HFI injection carrier
    signal injection_carrier_int : signed(15 downto 0);

    -- Clarke transformed currents
    signal ialpha_int : signed(15 downto 0);
    signal ibeta_int  : signed(15 downto 0);

    -- High-frequency current components
    signal ihf_alpha_int : signed(15 downto 0);
    signal ihf_beta_int  : signed(15 downto 0);
    signal hf_valid_int  : std_logic;


    signal vd_ref_placeholder : signed(15 downto 0); --place holder HERE

    
begin

    --HFI MODULE

    HFI_inst : entity work.HFI
        generic map (
            HALF_PERIOD => HFI_HALF_PERIOD,
            SHIFT_SCALE => HFI_SHIFT_SCALE
        )
        port map (
            clk => clk,
            reset => reset,

            vd_ref_in => vd_ref_placeholder,

            ia => ia,
            ib => ib,
            ic => ic,

            clk50k => clk50k_debug,
            sample_enable => sample_enable_int,

            sine_out => sine_out_debug,
            injection_carrier => injection_carrier_int,

            vd_ref_out => vd_ref_out,

            ialpha => ialpha_int,
            ibeta => ibeta_int
        );


    --HIGH-FREQUENCY CURRENT EXTRACTION

    HF_Current_Extraction_inst : entity work.HF_Current_Extraction
        generic map (
            LPF_ALPHA_Q15 => CURRENT_LPF_ALPHA_Q15
        )
        port map (
            clk => clk,
            reset => reset,

            sample_enable => sample_enable_int,

            ialpha_in => ialpha_int,
            ibeta_in => ibeta_int,

            ihf_alpha => ihf_alpha_int,
            ihf_beta => ihf_beta_int,

            hf_valid => hf_valid_int
        );


    --HFI ESTIMATOR

    HFI_Estimator_inst : entity work.HFI_Estimator
        generic map (
            DEMOD_LPF_ALPHA_Q15 => DEMOD_LPF_ALPHA_Q15,
            DEMOD_POLARITY      => DEMOD_POLARITY,

            ERROR_GAIN_Q15      => ERROR_GAIN_Q15,
            ERROR_POLARITY      => ERROR_POLARITY,

            PLL_KP_Q15          => PLL_KP_Q15,
            PLL_KI_Q15          => PLL_KI_Q15,
            OMEGA_LIMIT_Q16     => OMEGA_LIMIT_Q16
        )
        port map (
            clk => clk,
            reset => reset,

            sample_enable => sample_enable_int,

            hf_valid => hf_valid_int,
            ihf_alpha => ihf_alpha_int,
            ihf_beta => ihf_beta_int,

            injection_carrier => injection_carrier_int,

            theta_est => theta_est,
            omega_est => omega_est,
            pll_valid => pll_valid,

            sin_theta_debug => sin_theta_debug,
            cos_theta_debug => cos_theta_debug,

            demodulated_q_debug => demodulated_q_debug,
            position_error_debug => position_error_debug,

            demodulated_valid_debug => demodulated_valid_debug,
            position_error_valid_debug => position_error_valid_debug
        );

    -- Debug signal connections

    sample_enable_debug <= sample_enable_int;

    ialpha_debug <= ialpha_int;
    ibeta_debug  <= ibeta_int;

    ihf_alpha_debug <= ihf_alpha_int;
    ihf_beta_debug  <= ihf_beta_int;

    hf_valid_debug <= hf_valid_int;

    vd_ref_placeholder <= (others => '0');
    
end Structural;
