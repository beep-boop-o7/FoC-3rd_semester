----------------------------------------------------------------------------------
-- Design Name: FPGA-based FOC Controller
-- Module Name: MAIN_TOP
--
-- Description:
-- Main integration top for the FPGA-based FOC feedback system.
--
-- Connects:
--   1. ADC_Feedback_Top
--   2. HFI_Top
--   3. Top_system_for_feedback_system (Adaptive STA-SMO)
--   4. Hybrid_Observer
--
-- The FOC controller and existing PDM are not instantiated yet.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MAIN_TOP is
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- ADC interface pins
        xa_p : in std_logic_vector(0 downto 0);
        xa_n : in std_logic_vector(0 downto 0);

        mux_sel : out std_logic_vector(1 downto 0);
        pot_ref : out std_logic;

        -- Motor voltage information
        duty_a : in signed(15 downto 0);
        duty_b : in signed(15 downto 0);
        duty_c : in signed(15 downto 0);
        vdc    : in signed(15 downto 0);

        -- Angle and speed selected by Hybrid Observer
        theta_selected : out unsigned(15 downto 0);
        omega_selected : out signed(31 downto 0);

        observer_valid : out std_logic;

        -- Debug outputs
        theta_hfi_debug : out unsigned(15 downto 8); --if ur reading this there might be an 8 bit variable in the HFI, hope what i did here works
        theta_smo_debug : out unsigned(15 downto 0);  

        hfi_valid_debug : out std_logic;
        smo_valid_debug : out std_logic
    );
end MAIN_TOP;


architecture Structural of MAIN_TOP is


    -- RESET

    signal reset_pipe : std_logic_vector(1 downto 0) := "11";
    signal internal_reset : std_logic;

 
    -- ADC FEEDBACK


    signal ia : signed(15 downto 0);
    signal ib : signed(15 downto 0);
    signal ic : signed(15 downto 0);

    signal current_valid : std_logic;


    -- HFI
  

    signal vd_ref_hfi : signed(15 downto 0);

    signal theta_hfi : unsigned(15 downto 0);
    signal omega_hfi : signed(31 downto 0);

    signal hfi_valid : std_logic;


    -- ADAPTIVE STA-SMO
 

    signal theta_smo : unsigned(7 downto 0);
    signal omega_smo : signed(31 downto 0);

    signal smo_valid : std_logic;

    signal id_feedback : signed(15 downto 0);
    signal iq_feedback : signed(15 downto 0);

    signal alpha_error : std_logic_vector(15 downto 0);
    signal beta_error  : std_logic_vector(15 downto 0);

    signal error_valid : std_logic;

  
    -- HYBRID OBSERVER


    signal theta_hybrid : unsigned(15 downto 0);
    signal omega_hybrid : signed(31 downto 16); --was originally 31 downto 0, now changed to it matches foc_core(can also be 16-1 yall pick whats best)

    signal hybrid_valid : std_logic;


    -- REST OF FOC (TOP.VHD)

    signal ea : std_logic_vector(11 downto 0);
    signal eb : std_logic_vector(11 downto 0);
    signal ec : std_logic_vector(11 downto 0);
    signal va : std_logic_vector(11 downto 0);
    signal vb : std_logic_vector(11 downto 0);
    signal vc : std_logic_vector(11 downto 0);
    signal theta_foc_in : std_logic_vector(15 downto 0);


    -- INTERNAL INTERFACE


    -- Placeholder until the complete FOC controller is connected.
    signal vd_ref_placeholder : signed(15 downto 0) := (others => '0');

begin

     -- RESET SYNCHRONIZER


    process(clk)
    begin
        if rising_edge(clk) then
            reset_pipe <= reset_pipe(0) & reset;
        end if;
    end process;

    internal_reset <= reset_pipe(1);



    -- ADC FEEDBACK TOP


    U_ADC_FEEDBACK : entity work.ADC_Feedback_Top

        port map (
            sysclk        => clk,
            btn0          => internal_reset,

            xa_p          => xa_p,
            xa_n          => xa_n,

            mux_sel       => mux_sel,
            pot_ref       => pot_ref,

            ia            => ia,
            ib            => ib,
            ic            => ic,

            current_valid => current_valid
        );


    -- HFI TOP


    U_HFI_TOP : entity work.HFI_Top

        port map (
            clk       => clk,
            reset     => internal_reset,

            vd_ref_in  => vd_ref_placeholder,
            vd_ref_out => vd_ref_hfi,

            ia => ia,
            ib => ib,
            ic => ic,

            theta_est => theta_hfi,
            omega_est => omega_hfi,

            pll_valid => hfi_valid
        );



    -- ADAPTIVE STA-SMO FEEDBACK SYSTEM


    U_SMO_TOP : entity work.Top_system_for_feedback_system

        port map (
            clk   => clk,
            reset => internal_reset,

            ia => ia,
            ib => ib,
            ic => ic,

            duty_a => duty_a,
            duty_b => duty_b,
            duty_c => duty_c, -- THESE POS COME FROM THE PDM, THIS A PLACEHOLDER

            vdc => vdc, -- SAME HERE PLACE HOLDER, BUT PROB SUM LIKE V11-V12 ish ish 

            -- The selected hybrid angle will eventually feed this port.
            theta_est => theta_hybrid,

            id_out => id_feedback,
            iq_out => iq_feedback,

            a_system_error => alpha_error,
            b_system_error => beta_error,

            error_valid => error_valid,

            theta_smo => theta_smo,
            omega_smo => omega_smo,
            smo_valid => smo_valid
        );



    -- HYBRID OBSERVER


    U_HYBRID_OBSERVER : entity work.Hybrid_Observer

        port map (
            clk   => clk,
            reset => internal_reset,

            theta_hfi => theta_hfi,
            omega_hfi => omega_hfi,
            hfi_valid => hfi_valid,

            theta_smo => theta_smo,
            omega_smo => omega_smo,
            smo_valid => smo_valid,

            theta_est => theta_hybrid,
            omega_est => omega_hybrid,

            observer_valid => hybrid_valid
        );


    U_REST_OF_FOC : entity work.top
    
        port map(
        
        clk => clk,

        ea => ea,
        eb => eb,
        ec => ec,

        va => va,
        vb => vb,
        vc => vc,      
        
        theta => std_logic_vector(theta_hybrid), -- Converted to std_logic_vector alsooo
        
        speed_meas => omega_hybrid -- added to omega well hope theres no error, this headache some bs im going back to bed
        
        );

    -- MAIN OUTPUTS


    theta_selected <= theta_hybrid;
    omega_selected <= omega_hybrid;

    observer_valid <= hybrid_valid;

    theta_hfi_debug <= theta_hfi;
    theta_smo_debug <= theta_smo;

    hfi_valid_debug <= hfi_valid;
    smo_valid_debug <= smo_valid;

end Structural;
