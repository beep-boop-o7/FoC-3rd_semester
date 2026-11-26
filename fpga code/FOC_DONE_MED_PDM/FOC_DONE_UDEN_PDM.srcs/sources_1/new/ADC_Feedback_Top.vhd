
----------------------------------------------------------------------------------
-- Design Name: ADC_Feedback_Top
-- Module Name: ADC_Feedback_Top
--
-- Description:
-- Complete ADC feedback acquisition system.
--
-- XADC VAUX4 -> External MUX -> Three phase-current measurements
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ADC_Feedback_Top is

    generic (

        -- External multiplexer configuration
        SETTLE_CYCLES : positive := 120;

        MUX_A_SEL : std_logic_vector(1 downto 0) := "00";
        MUX_B_SEL : std_logic_vector(1 downto 0) := "01";
        MUX_C_SEL : std_logic_vector(1 downto 0) := "10";       --Possibly chnage 

        -- Current sensor zero-current ADC code
        ADC_ZERO_CODE : integer := 2048
    );

    port (
        sysclk : in std_logic;
        btn0   : in std_logic;

        --analog input 
        xa_p : in std_logic_vector(0 downto 0);
        xa_n : in std_logic_vector(0 downto 0);

        -- mux cntrl pin
        mux_sel : out std_logic_vector(1 downto 0);

        -- Optional potentiometer supply
        pot_ref : out std_logic;

        -- Phase current measurements
        ia : out signed(15 downto 0);
        ib : out signed(15 downto 0);
        ic : out signed(15 downto 0);

        -- Indicates that all three phase measurements are updated
        current_valid : out std_logic
    );

end entity;


architecture rtl of ADC_Feedback_Top is

    -- Reset synchronization
    
    signal reset_pipe : std_logic_vector(1 downto 0) := (others => '0');
    signal reset : std_logic;

    -- ADC interface signals

    signal adc_data  : std_logic_vector(11 downto 0);
    signal adc_valid : std_logic;

begin

    -- Reset

    process(sysclk)
    begin

        if rising_edge(sysclk) then

            reset_pipe <= reset_pipe(0) & btn0;

        end if;

    end process;

    reset <= reset_pipe(1);

    -- Potentiometer supply

    pot_ref <= '1';

    -- XADC INTERFACE

    ADC_Interface_inst : entity work.ADC_Interface

        port map (
            sysclk => sysclk,
            reset  => reset,

            xa_p => xa_p(0),
            xa_n => xa_n(0),

            adc_data  => adc_data,
            adc_valid => adc_valid
        );

    --MUX CONTROLLER

    ADC_Mux_Controller_inst : entity work.ADC_Mux_Controller

        generic map (

            SETTLE_CYCLES => SETTLE_CYCLES,

            ADC_ZERO_CODE => ADC_ZERO_CODE,

            MUX_A_SEL => MUX_A_SEL,
            MUX_B_SEL => MUX_B_SEL,
            MUX_C_SEL => MUX_C_SEL
        )

        port map (
            clk   => sysclk,
            reset => reset,

            adc_data  => adc_data,
            adc_valid => adc_valid,

            mux_sel => mux_sel,

            ia => ia,
            ib => ib,
            ic => ic,

            current_valid => current_valid
        );

end architecture;
