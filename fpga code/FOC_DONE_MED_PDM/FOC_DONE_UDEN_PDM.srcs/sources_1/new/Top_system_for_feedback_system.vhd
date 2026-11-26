
----------------------------------------------------------------------------------
-- Design Name: FPGA-based FOC Controller
-- Module Name: Top_system_for_feedback_system
--
-- Description:
-- Connects Sample_Generator, Feedback_system, Motor_Model,
-- Error_calculation and Park_transform.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Top_system_for_feedback_system is

generic (

    CLOCKS_PER_SAMPLE : positive := 600;

    RS_FIXED : integer := 2048;
    K_FIXED  : integer := 205;

    -- Adaptive STA parameters
    K1_FIXED       : integer := 2048;
    K1_MIN_FIXED   : integer := 512;
    K1_MAX_FIXED   : integer := 8192;

    MU_FIXED       : integer := 41;

    ALPHA_STEP_FIXED : integer := 1;
    ETA_STEP_FIXED   : integer := 1;

    K2_RATIO_Q15   : integer := 160

);

port (

    clk   : in std_logic;
    reset : in std_logic;

    -- Three-phase motor currents
    ia : in signed(15 downto 0);
    ib : in signed(15 downto 0);
    ic : in signed(15 downto 0);

    -- PWM duty cycles
    duty_a : in signed(15 downto 0);
    duty_b : in signed(15 downto 0);
    duty_c : in signed(15 downto 0);

    -- DC bus voltage
    vdc : in signed(15 downto 0);

    -- Estimated electrical rotor angle
    theta_est : in unsigned(7 downto 0);

    -- Park transform outputs
    id_out : out signed(15 downto 0);
    iq_out : out signed(15 downto 0);

    -- Current estimation errors
    a_system_error : out std_logic_vector(15 downto 0);
    b_system_error : out std_logic_vector(15 downto 0);

    -- Indicates when a new error has been stored
    error_valid : out std_logic;
    
    -- SMO rotor angle and speed estimates
    theta_smo : out unsigned(7 downto 0);
    omega_smo : out signed(31 downto 0);
    smo_valid : out std_logic
    

);

end Top_system_for_feedback_system;


architecture Behavioral of Top_system_for_feedback_system is


    -- SAMPLING CONTROL

    signal wire_sample_enable : std_logic := '0';


    -- FEEDBACK SYSTEM SIGNALS

    signal wire_fb_a_to_error : signed(15 downto 0);
    signal wire_fb_b_to_error : signed(15 downto 0);

    signal wire_valpha : signed(19 downto 0);
    signal wire_vbeta  : signed(19 downto 0);

    signal current_valid : std_logic;
    signal voltage_valid : std_logic;


    -- MOTOR MODEL SIGNALS

    signal wire_motor_model_a_to_error : signed(15 downto 0);
    signal wire_motor_model_b_to_error : signed(15 downto 0);

    signal estimate_valid : std_logic;

    signal error_alpha_reg : signed(15 downto 0);
    signal error_beta_reg  : signed(15 downto 0);

    signal error_valid_reg : std_logic;

    signal wire_ealpha_est : signed(19 downto 0);
    signal wire_ebeta_est  : signed(19 downto 0);


    -- ERROR CALCULATION SIGNALS

    signal wire_alpha_error : signed(15 downto 0);
    signal wire_beta_error  : signed(15 downto 0);


    -- PARK TRANSFORM SIGNALS

    signal wire_id : signed(15 downto 0);
    signal wire_iq : signed(15 downto 0);
    
    -- HIGH-FREQUENCY CURRENT EXTRACTION

    signal wire_ihf_alpha : signed(15 downto 0);
    signal wire_ihf_beta  : signed(15 downto 0);

    signal wire_hf_valid : std_logic;


    -- SMO ANGLE ESTIMATOR SIGNALS
    signal wire_smo_theta : unsigned(7 downto 0);
    signal wire_smo_omega : signed(31 downto 0);
    signal wire_smo_valid : std_logic;

begin



    -- SAMPLE GENERATOR

    U_SAMPLE_GEN : entity work.Sample_Generator

        generic map (

            CLOCKS_PER_SAMPLE => CLOCKS_PER_SAMPLE

        )

        port map (

            clk           => clk,
            reset         => reset,
            sample_enable => wire_sample_enable

        );



    -- FEEDBACK SYSTEM


    U_FEEDBACK_SYSTEM : entity work.Feedback_system

        port map (

            clk           => clk,
            reset         => reset,
            sample_enable => wire_sample_enable,

            ia            => ia,
            ib            => ib,
            ic            => ic,

            duty_a        => duty_a,
            duty_b        => duty_b,
            duty_c        => duty_c,

            vdc           => vdc,

            ialpha        => wire_fb_a_to_error,
            ibeta         => wire_fb_b_to_error,

            valpha        => wire_valpha,
            vbeta         => wire_vbeta,

            current_valid => current_valid,
            voltage_valid => voltage_valid

        );
        

        -- HF CURRENT EXTRACTION


        U_HF_CURRENT_EXTRACTION : entity work.HF_Current_Extraction
        
            generic map (
        
                LPF_ALPHA_Q15 => 512
        
            )
        
            port map (
        
                clk           => clk,
                reset         => reset,
        
                sample_enable => current_valid,
        
                ialpha_in     => wire_fb_a_to_error,
                ibeta_in      => wire_fb_b_to_error,
        
                ihf_alpha     => wire_ihf_alpha,
                ihf_beta      => wire_ihf_beta,
        
                hf_valid      => wire_hf_valid
        
            );
        

    -- 3. MOTOR MODEL / adaptive STA SMO


    U_MOTOR_MODEL : entity work.Motor_model

        generic map (

            RS_FIXED          => RS_FIXED,
            K_FIXED           => K_FIXED,

            K1_FIXED          => K1_FIXED,
            K1_MIN_FIXED      => K1_MIN_FIXED,
            K1_MAX_FIXED      => K1_MAX_FIXED,

            MU_FIXED          => MU_FIXED,

            ALPHA_STEP_FIXED  => ALPHA_STEP_FIXED,
            ETA_STEP_FIXED    => ETA_STEP_FIXED,

            K2_RATIO_Q15      => K2_RATIO_Q15

        )

        port map (

            clk            => clk,
            reset          => reset,
            sample_enable  => voltage_valid,

            valpha         => wire_valpha,
            vbeta          => wire_vbeta,

            ialpha         => wire_fb_a_to_error,
            ibeta          => wire_fb_b_to_error,

            ihat_alpha     => wire_motor_model_a_to_error,
            ihat_beta      => wire_motor_model_b_to_error,

            ealpha_est     => wire_ealpha_est,
            ebeta_est      => wire_ebeta_est,

            estimate_valid => estimate_valid,

            alpha_error_result_for_motor => wire_alpha_error,
            beta_error_result_for_motor  => wire_beta_error

        );




        -- SMO ANGLE ESTIMATOR

        
        U_SMO_ANGLE_ESTIMATOR : entity work.SMO_Angle_Estimator
        
            generic map (
                MIN_EMF_COMPONENT => 8,
                ROTOR_OFFSET      => 192
            )
        
            port map (
                clk           => clk,
                reset         => reset,
        
                sample_enable => estimate_valid,
        
                ealpha_est    => wire_ealpha_est,
                ebeta_est     => wire_ebeta_est,
        
                theta_est     => wire_smo_theta,
                omega_est     => wire_smo_omega,
        
                angle_valid   => wire_smo_valid
            );


    -- ERROR CALCULATION
    

    U_ERROR_CALCULATION : entity work.Error_calculation

        port map (

            ialpha_inPort     => wire_fb_a_to_error,
            ibeta_inPort      => wire_fb_b_to_error,

            ihat_alpha_inPort => wire_motor_model_a_to_error,
            ihat_beta_inPort  => wire_motor_model_b_to_error,

            alpha_error_out   => wire_alpha_error,
            beta_error_out    => wire_beta_error

        );



    -- PARK TRANSFORM


    U_PARK_TRANSFORM : entity work.Park_transform

        port map (

            clk           => clk,
            reset         => reset,

            sample_enable => current_valid,

            ialpha        => wire_fb_a_to_error,
            ibeta         => wire_fb_b_to_error,

            theta_est     => theta_est,

            id            => wire_id,
            iq            => wire_iq

        );


  
    -- STORE VALID ERROR RESULTS


    process(clk)

    begin

        if rising_edge(clk) then

            if reset = '1' then

                error_alpha_reg <= (others => '0');
                error_beta_reg  <= (others => '0');
                error_valid_reg <= '0';

            else

                error_valid_reg <= '0';

                if estimate_valid = '1' then

                    error_alpha_reg <= wire_alpha_error;
                    error_beta_reg  <= wire_beta_error;

                    error_valid_reg <= '1';

                end if;

            end if;

        end if;

    end process;



    -- TOP-LEVEL OUTPUTS


    a_system_error <= std_logic_vector(error_alpha_reg);
    b_system_error <= std_logic_vector(error_beta_reg);

    error_valid <= error_valid_reg;

    id_out <= wire_id;
    iq_out <= wire_iq;
    
    -- SMO estimator outputs
    theta_smo <= wire_smo_theta;
    omega_smo <= wire_smo_omega;
    smo_valid <= wire_smo_valid;
    
end Behavioral;
