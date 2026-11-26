----------------------------------------------------------------------------------
-- Design Name: FOC Feedback System
-- Module Name: Feedback_system
--
-- Description:
-- Clarke transformation for three-phase currents and
-- reconstructed voltages.
--
-- Current outputs: Q3.12
-- Voltage outputs: Q7.12
--
-- VHDL-93 compatible.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Feedback_system is

    port (

        clk           : in std_logic;
        reset         : in std_logic;
        sample_enable : in std_logic;

        -- Three-phase motor currents:
        ia            : in signed(15 downto 0);
        ib            : in signed(15 downto 0);
        ic            : in signed(15 downto 0);

        -- PWM duty cycles: 
        duty_a        : in signed(15 downto 0);
        duty_b        : in signed(15 downto 0);
        duty_c        : in signed(15 downto 0);

        -- DC bus voltage: 
        vdc           : in signed(15 downto 0);

        -- Current alpha-beta outputs: 
        ialpha        : out signed(15 downto 0);
        ibeta         : out signed(15 downto 0);

        -- Voltage alpha-beta outputs: 
        valpha        : out signed(19 downto 0);
        vbeta         : out signed(19 downto 0);

        -- Valid signals
        current_valid : out std_logic;
        voltage_valid : out std_logic

    );

end Feedback_system;


architecture Behavioral of Feedback_system is


    -- Clarke coefficients: 

    constant C_ALPHA_A : signed(15 downto 0) := to_signed(2731, 16);
    constant C_ALPHA_B : signed(15 downto 0) := to_signed(-1365, 16);
    constant C_ALPHA_C : signed(15 downto 0) := to_signed(-1365, 16);

    constant C_BETA_A  : signed(15 downto 0) := to_signed(0, 16);
    constant C_BETA_B  : signed(15 downto 0) := to_signed(2365, 16);
    constant C_BETA_C  : signed(15 downto 0) := to_signed(-2365, 16);


    -- Current alpha-beta registers:

    signal sig_alpha : signed(15 downto 0) := (others => '0');
    signal sig_beta  : signed(15 downto 0) := (others => '0');


    -- Reconstructed phase voltage registers:

    signal va : signed(19 downto 0) := (others => '0');
    signal vb : signed(19 downto 0) := (others => '0');
    signal vc : signed(19 downto 0) := (others => '0');


    -- Voltage alpha-beta registers:

    signal sig_valpha : signed(19 downto 0) := (others => '0');
    signal sig_vbeta  : signed(19 downto 0) := (others => '0');


    -- Pipeline valid signals:

    signal voltage_stage1_valid : std_logic := '0';

    signal current_valid_reg : std_logic := '0';
    signal voltage_valid_reg : std_logic := '0';


begin



    -- CURRENT AND VOLTAGE PROCESSING


    process(clk)

        -- Current multiplication: 

        variable p_ia : signed(31 downto 0);
        variable p_ib : signed(31 downto 0);
        variable p_ic : signed(31 downto 0);

        variable temp_alpha : signed(33 downto 0);
        variable temp_beta  : signed(33 downto 0);


        -- Phase voltage multiplication: 

        variable temp_va : signed(31 downto 0);
        variable temp_vb : signed(31 downto 0);
        variable temp_vc : signed(31 downto 0);


        -- Voltage Clarke multiplication: 

        variable p_va : signed(35 downto 0);
        variable p_vb : signed(35 downto 0);
        variable p_vc : signed(35 downto 0);

        variable temp_valpha : signed(37 downto 0);
        variable temp_vbeta  : signed(37 downto 0);


    begin

        if rising_edge(clk) then

            if reset = '1' then

            sig_alpha <= (others => '0');
            sig_beta  <= (others => '0');

            va <= (others => '0');
            vb <= (others => '0');
            vc <= (others => '0');

            sig_valpha <= (others => '0');
            sig_vbeta  <= (others => '0');

            voltage_stage1_valid <= '0';

            current_valid_reg <= '0';
            voltage_valid_reg <= '0';


            else

                
                -- It will clear valid signals by default. become high only when new data is available.
                current_valid_reg <= sample_enable;

                voltage_stage1_valid <= sample_enable;

                voltage_valid_reg <= voltage_stage1_valid;


                -- CURRENT CLARKE TRANSFORMATION


                if sample_enable = '1' then

                    -- ALPHA CURRENT

                    p_ia := ia * C_ALPHA_A;
                    p_ib := ib * C_ALPHA_B;
                    p_ic := ic * C_ALPHA_C;

                    temp_alpha := resize(p_ia, 34) + resize(p_ib, 34) + resize(p_ic, 34);

                    sig_alpha <= resize(shift_right(temp_alpha, 12), 16);
                        
                    -- BETA CURRENT

                    p_ia := ia * C_BETA_A;
                    p_ib := ib * C_BETA_B;
                    p_ic := ic * C_BETA_C;

                    temp_beta := resize(p_ia, 34) + resize(p_ib, 34) + resize(p_ic, 34);

                    sig_beta <= resize(shift_right(temp_beta, 12), 16);
                      
                      
                end if;

                -- PHASE VOLTAGE RECONSTRUCTION

                if sample_enable = '1' then

                    temp_va := duty_a * vdc;
                    temp_vb := duty_b * vdc;
                    temp_vc := duty_c * vdc;

                    va <= resize(shift_right(temp_va, 11), 20);
                    vb <= resize(shift_right(temp_vb, 11), 20);
                    vc <= resize(shift_right(temp_vc, 11), 20);

                end if;


                -- VOLTAGE CLARKE TRANSFORMATION

                if voltage_stage1_valid = '1' then


                    -- ALPHA VOLTAGE

                    p_va := va * C_ALPHA_A;
                    p_vb := vb * C_ALPHA_B;
                    p_vc := vc * C_ALPHA_C;

                    temp_valpha := resize(p_va, 38) + resize(p_vb, 38) + resize(p_vc, 38);

                    -- Q7.24 -> Q7.12

                    sig_valpha <= resize(shift_right(temp_valpha, 12), 20);
                        
                    -- BETA VOLTAGE

                    p_va := va * C_BETA_A;
                    p_vb := vb * C_BETA_B;
                    p_vc := vc * C_BETA_C;

                    temp_vbeta := resize(p_va, 38) + resize(p_vb, 38) + resize(p_vc, 38);

                    -- Q7.24 -> Q7.12

                    sig_vbeta <= resize(shift_right(temp_vbeta, 12), 20);

                end if;

            end if;

        end if;

    end process;


    -- OUTPUT CONNECTIONS


    ialpha <= sig_alpha;
    ibeta  <= sig_beta;

    valpha <= sig_valpha;
    vbeta  <= sig_vbeta;

    current_valid <= current_valid_reg;
    voltage_valid <= voltage_valid_reg;


end Behavioral;
