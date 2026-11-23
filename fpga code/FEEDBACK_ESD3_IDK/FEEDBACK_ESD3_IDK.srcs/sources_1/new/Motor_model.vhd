----------------------------------------------------------------------------------
-- Design Name: FPGA-based FOC Controller
-- Module Name: Motor_Model
--
-- Description:
-- Motor current prediction model with Adaptive Super-Twisting Algorithm.
--
-- Adaptive gain method:
-- Shtessel et al. (2012), Equation (14).
--
-- The adaptation law is applied independently to the alpha and beta axes.
--
-- STA:
--   u = k1 * sqrt(abs(s)) * sign(s) + z
--
--   z[k+1] = z[k] + k2_step * sign(s)
--
-- Adaptive gain:
--   alpha_dot = +adaptation_rate, if abs(s) > mu
--   alpha_dot = -adaptation_rate, if abs(s) < mu
--   alpha_dot = eta,              if alpha <= alpha_min
--
-- Gain relationship:
--   k1 = alpha
--   k2 = epsilon * alpha
--
-- K2_RATIO_Q15 incorporates Ts * epsilon.
--
-- Fixed-point:
--   Current: Q3.12
--   Voltage: Q7.12
--   STA state z: Q7.12
--   Adaptive k1: Q3.12 numerical representation
--
-- Error convention:
--   s_alpha = ialpha - ihat_alpha
--   s_beta  = ibeta  - ihat_beta
--
-- VHDL-93 compatible.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Motor_Model is

    generic (

        -- Motor resistance(Not decided yetttt): 
        RS_FIXED : integer := 2048;

        -- Ts / Ls(and this one either): 
        K_FIXED : integer := 205;


        -- ADAPTIVE STA PARAMETERS

        -- Initial k1(temp):
        K1_FIXED : integer := 2048;

        -- Minimum adaptive k1(tempp): 
        K1_MIN_FIXED : integer := 512;

        -- Maximum adaptive k1(temp):
        K1_MAX_FIXED : integer := 8192;

        -- Sliding-region threshold(temp): 
        MU_FIXED : integer := 41;

        -- Increase/decrease in k1 per motor sample(temp):
        ALPHA_STEP_FIXED : integer := 1;

        -- Recovery increase per sample when k1 reaches its minimum (temp)
        ETA_STEP_FIXED : integer := 1;

        -- Q0.15 ratio: k2_step_raw = (k1_raw * K2_RATIO_Q15) / 32768, Example: k1 = 2048 and ratio = 160 gives k2_step = 10.
        K2_RATIO_Q15 : integer := 160

    );

    port (

        clk           : in std_logic;
        reset         : in std_logic;
        sample_enable : in std_logic;

        -- Measured currents: 
        ialpha        : in signed(15 downto 0);
        ibeta         : in signed(15 downto 0);

        -- Reconstructed voltages:
        valpha        : in signed(19 downto 0);
        vbeta         : in signed(19 downto 0);

        -- Predicted currents: 
        ihat_alpha    : out signed(15 downto 0);
        ihat_beta     : out signed(15 downto 0);

        -- Estimated back EMF: 
        ealpha_est    : out signed(19 downto 0);
        ebeta_est     : out signed(19 downto 0);

        -- Indicates that a new prediction is available
        estimate_valid : out std_logic;

        -- Current estimation errors: 
        alpha_error_result_for_motor : in signed(15 downto 0);
        beta_error_result_for_motor  : in signed(15 downto 0)

    );

end Motor_Model;


architecture Behavioral of Motor_Model is


    -- MOTOR PARAMETERS

    constant RS : signed(15 downto 0) := to_signed(RS_FIXED, 16);

    constant K : signed(15 downto 0) :=  to_signed(K_FIXED, 16);


    -- ADAPTIVE GAIN LIMITS AND PARAMETERS


    constant K1_INITIAL : signed(15 downto 0) := to_signed(K1_FIXED, 16);

    constant K1_MIN : signed(15 downto 0) := to_signed(K1_MIN_FIXED, 16);

    constant K1_MAX : signed(15 downto 0) := to_signed(K1_MAX_FIXED, 16);
        
    constant MU : unsigned(16 downto 0) := to_unsigned(MU_FIXED, 17);
        
    constant ALPHA_STEP : signed(16 downto 0) := to_signed(ALPHA_STEP_FIXED, 17);

    constant ETA_STEP : signed(16 downto 0) := to_signed(ETA_STEP_FIXED, 17);

    constant K2_RATIO : signed(15 downto 0) :=  to_signed(K2_RATIO_Q15, 16);


    -- OBSERVER STATES

    -- our predicted currents:
    signal sig_ihat_alpha : signed(15 downto 0) := (others => '0');

    signal sig_ihat_beta : signed(15 downto 0) := (others => '0');

    -- STA integral states:
    signal z_alpha : signed(19 downto 0) := (others => '0');

    signal z_beta : signed(19 downto 0) := (others => '0');

    -- Estimated back-EMF:
    signal sig_ealpha : signed(19 downto 0) := (others => '0');
    
    signal sig_ebeta : signed(19 downto 0) := (others => '0');



    -- ADAPTIVE GAINS

    -- Independent adaptive gains for alpha and beta. Numerical representation:

    signal k1_alpha : signed(15 downto 0) := to_signed(K1_FIXED, 16);

    signal k1_beta : signed(15 downto 0) := to_signed(K1_FIXED, 16);

    signal have_previous_sample : std_logic := '0';

    signal estimate_valid_reg : std_logic := '0';


    -- CURRENT SATURATION


    function saturate_16(x : signed(35 downto 0))
        return signed is
    begin

        if x > to_signed(32767, 36) then
            return to_signed(32767, 16);

        elsif x < to_signed(-32768, 36) then
            return to_signed(-32768, 16);

        else
            return resize(x, 16);
        end if;

    end function;


    -- VOLTAGE SATURATION


    function saturate_20(x : signed(35 downto 0))
        return signed is
    begin

        if x > to_signed(524287, 36) then
            return to_signed(524287, 20);

        elsif x < to_signed(-524288, 36) then
            return to_signed(-524288, 20);

        else
            return resize(x, 20);
        end if;

    end function;


    -- ABSOLUTE VALUE OF CURRENT ERROR

    function abs_error(x : signed(15 downto 0))
        return unsigned is

        variable extended : signed(16 downto 0);

    begin

        extended := resize(x, 17);

        if extended(16) = '1' then
            return unsigned(-extended);
        else
            return unsigned(extended);
        end if;

    end function;


    -- SQUARE ROOT FUNCTION

    function sqrt_q12(x : signed(15 downto 0))
        return signed is

        variable x_extended : signed(16 downto 0);

        variable magnitude : unsigned(16 downto 0);

        variable radicand : unsigned(28 downto 0);

        variable root : unsigned(28 downto 0);

        variable trial : unsigned(28 downto 0);

        variable bit_mask : unsigned(28 downto 0);

    begin

        x_extended := resize(x, 17);

        if x_extended(16) = '1' then
            magnitude := unsigned(-x_extended);
        else
            magnitude := unsigned(x_extended);
        end if;


        -- sqrt(abs(x_real)) represented with 12 fractional bits. sqrt(abs(x_raw) * 4096)

        radicand := shift_left(resize(magnitude, 29), 12);
            
        root := (others => '0');

        bit_mask := shift_left(to_unsigned(1, 29), 26);
            

        while bit_mask /= to_unsigned(0, 29) loop

            trial := root + bit_mask;

            if radicand >= trial then

                radicand := radicand - trial;

                root := shift_right(root, 1) + bit_mask;

            else

                root := shift_right(root, 1);

            end if;

            bit_mask := shift_right(bit_mask, 2);

        end loop;

        return signed(resize(root, 16));

    end function;


begin


    -- MOTOR MODEL + ADAPTIVE SUPER-TWISTING OBSERVER

    process(clk)

 
        -- Motor resistance multiplication

        variable p_ralpha : signed(31 downto 0);
        variable p_rbeta  : signed(31 downto 0);

        -- Voltage errors: Q7.12

        variable err_alpha : signed(19 downto 0);
        variable err_beta  : signed(19 downto 0);

        -- Current prediction multiplication

        variable p_kalpha : signed(35 downto 0);
        variable p_kbeta  : signed(35 downto 0);

        variable next_alpha : signed(35 downto 0);
        variable next_beta  : signed(35 downto 0);

        -- STA square-root calculation

        variable root_alpha : signed(15 downto 0);
        variable root_beta  : signed(15 downto 0);

        -- STA first component

        variable p_sta_alpha : signed(31 downto 0);
        variable p_sta_beta  : signed(31 downto 0);

        variable term_alpha : signed(35 downto 0);
        variable term_beta  : signed(35 downto 0);

        -- STA output

        variable u_alpha_now : signed(19 downto 0);
        variable u_beta_now  : signed(19 downto 0);

        variable output_alpha : signed(35 downto 0);
        variable output_beta  : signed(35 downto 0);

        -- Adaptive gain calculations

        variable abs_alpha : unsigned(16 downto 0);
        variable abs_beta  : unsigned(16 downto 0);

        variable next_k1_alpha : signed(16 downto 0);
        variable next_k1_beta  : signed(16 downto 0);

        -- Adaptive second gain, k2_step = k1 * K2_RATIO_Q15 / 32768:

        variable p_k2_alpha : signed(31 downto 0);
        variable p_k2_beta  : signed(31 downto 0);

        variable k2_step_alpha : signed(19 downto 0);
        variable k2_step_beta  : signed(19 downto 0);

        -- STA integral state update

        variable next_z_alpha : signed(20 downto 0);
        variable next_z_beta  : signed(20 downto 0);

        -- Back-EMF calculation

        variable emf_alpha_wide : signed(20 downto 0);
        variable emf_beta_wide  : signed(20 downto 0);


    begin

        if rising_edge(clk) then

            if reset = '1' then

                sig_ihat_alpha <= (others => '0');
                sig_ihat_beta  <= (others => '0');

                z_alpha <= (others => '0');
                z_beta  <= (others => '0');

                sig_ealpha <= (others => '0');
                sig_ebeta  <= (others => '0');

                k1_alpha <= K1_INITIAL;
                k1_beta  <= K1_INITIAL;

                have_previous_sample <= '0';

                estimate_valid_reg <= '0';


            else

                estimate_valid_reg <= '0';


                if sample_enable = '1' then

                    -- FIRST SAMPLE

                    if have_previous_sample = '0' then

                        have_previous_sample <= '1';


                    else

                        -- CALCULATE ABSOLUTE CURRENT ERRORS:

                        abs_alpha := abs_error(alpha_error_result_for_motor);
                            
                        abs_beta := abs_error(beta_error_result_for_motor);
                            
                        -- CALCULATE STA SQUARE ROOTS:

                        root_alpha := sqrt_q12(alpha_error_result_for_motor);
                            
                        root_beta := sqrt_q12(beta_error_result_for_motor);
                            
                        -- CALCULATE FIRST STA COMPONENT

                        p_sta_alpha := root_alpha * k1_alpha;
                            
                        p_sta_beta := root_beta * k1_beta;


                        term_alpha :=  resize(shift_right(p_sta_alpha, 12),36
                        );
                              
                        term_beta := resize( shift_right(p_sta_beta, 12), 36
                        );


                        -- Apply alpha error sign:

                        if alpha_error_result_for_motor = to_signed(0, 16) then

                            term_alpha := (others => '0');

                        elsif alpha_error_result_for_motor(15) = '1' then

                            term_alpha := -term_alpha;

                        end if;


                        -- Apply beta error sign:

                        if beta_error_result_for_motor = to_signed(0, 16) then
                           
                            term_beta := (others => '0');

                        elsif beta_error_result_for_motor(15) = '1' then

                            term_beta := -term_beta;

                        end if;


                        -- CALCULATE ADAPTIVE SECOND GAIN:

                        p_k2_alpha := k1_alpha * K2_RATIO;

                        p_k2_beta := k1_beta * K2_RATIO;
                           

                        k2_step_alpha := resize(shift_right(p_k2_alpha, 15),20
                            );

                        k2_step_beta := resize( shift_right(p_k2_beta, 15), 20
                            );

                        -- CALCULATE STA OUTPUT

                        output_alpha := term_alpha +  resize(z_alpha, 36);

                        output_beta := term_beta + resize(z_beta, 36);

                        u_alpha_now := saturate_20(output_alpha);

                        u_beta_now :=  saturate_20(output_beta);


                        -- MOTOR CURRENT PREDICTION ALPHA AXIS

                        p_ralpha := sig_ihat_alpha * RS;

                        err_alpha :=  valpha - resize( shift_right(p_ralpha, 12),20) + u_alpha_now;
                        
                        p_kalpha := err_alpha * K;

                        next_alpha := resize(sig_ihat_alpha, 36) + shift_right(p_kalpha, 12);

                        sig_ihat_alpha <= saturate_16(next_alpha);

                        -- BETA AXIS

                        p_rbeta := sig_ihat_beta * RS;

                        err_beta := vbeta - resize( shift_right(p_rbeta, 12), 20) + u_beta_now; 
                        
                        p_kbeta := err_beta * K;

                        next_beta := resize(sig_ihat_beta, 36) + shift_right(p_kbeta, 12);

                        sig_ihat_beta <= saturate_16(next_beta);


                        -- 8. UPDATE STA INTEGRAL STATES


                        next_z_alpha := resize(z_alpha, 21);

                        next_z_beta := resize(z_beta, 21);

                        -- ALPHA

                        if alpha_error_result_for_motor > to_signed(0, 16) then

                            next_z_alpha := next_z_alpha + resize(k2_step_alpha, 21);

                        elsif alpha_error_result_for_motor < to_signed(0, 16) then

                            next_z_alpha := next_z_alpha - resize(k2_step_alpha, 21);

                        end if;


                        -- BETA

                        if beta_error_result_for_motor > to_signed(0, 16) then

                            next_z_beta := next_z_beta + resize(k2_step_beta, 21);

                        elsif beta_error_result_for_motor < to_signed(0, 16) then

                            next_z_beta := next_z_beta - resize(k2_step_beta, 21);

                        end if;


                        z_alpha <= saturate_20( resize(next_z_alpha, 36)
                            );

                        z_beta <= saturate_20(resize(next_z_beta, 36)
                            );

                        -- 9. ESTIMATE BACK-EMF, With the observer correction added positively to the voltage model, the equivalent correction:

                        emf_alpha_wide := -resize(next_z_alpha, 21);

                        emf_beta_wide :=  -resize(next_z_beta, 21);

                        sig_ealpha <= saturate_20(resize(emf_alpha_wide, 36)
                            );

                        sig_ebeta <= saturate_20( resize(emf_beta_wide, 36)
                            );


                        -- 10. ADAPTIVE GAIN UPDATE, ALPHA GAIN:

                        next_k1_alpha := resize(k1_alpha, 17);

                        if k1_alpha <= K1_MIN then -- Minimum gain recovery
                            
                            next_k1_alpha := next_k1_alpha + ETA_STEP;

                        else

                            if abs_alpha > MU then  -- Error outside sliding region, increase gain:
                                
                                next_k1_alpha := next_k1_alpha + ALPHA_STEP;

                            elsif abs_alpha < MU then -- Error inside sliding region, decrease gain.:

                                next_k1_alpha := next_k1_alpha - ALPHA_STEP;

                            end if;

                        end if;


                        -- Apply alpha gain limits.

                        if next_k1_alpha > resize(K1_MAX, 17) then
                           
                            next_k1_alpha := resize(K1_MAX, 17);

                        elsif next_k1_alpha < resize(K1_MIN, 17) then

                            next_k1_alpha := resize(K1_MIN, 17);

                        end if;


                        k1_alpha <=  resize(next_k1_alpha, 16); -- BETA GAIN

                        next_k1_beta := resize(k1_beta, 17);


                        if k1_beta <= K1_MIN then -- Minimum gain recovery.

                            next_k1_beta :=  next_k1_beta + ETA_STEP;         

                        else

                            if abs_beta > MU then -- Error outside sliding region,increase gain:
                            
                                next_k1_beta := next_k1_beta + ALPHA_STEP;

                            elsif abs_beta < MU then -- Error inside sliding region, decrease gain:

                                next_k1_beta := next_k1_beta - ALPHA_STEP;

                            end if;

                        end if;

                        -- Apply beta gain limits.

                        if next_k1_beta > resize(K1_MAX, 17) then

                            next_k1_beta := resize(K1_MAX, 17);
                            
                        elsif next_k1_beta < resize(K1_MIN, 17) then

                            next_k1_beta := resize(K1_MIN, 17);

                        end if;


                        k1_beta <= resize(next_k1_beta, 16);


                        -- NEW ESTIMATE AVAILABLE

                        estimate_valid_reg <= '1';


                    end if;

                end if;

            end if;

        end if;

    end process;


    -- OUTPUT CONNECTIONS


    ihat_alpha <= sig_ihat_alpha;
    ihat_beta  <= sig_ihat_beta;

    ealpha_est <= sig_ealpha;
    ebeta_est  <= sig_ebeta;

    estimate_valid <= estimate_valid_reg;


end Behavioral;
