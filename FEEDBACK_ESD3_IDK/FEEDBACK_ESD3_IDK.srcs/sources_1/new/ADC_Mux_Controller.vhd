
----------------------------------------------------------------------------------
-- Design Name: ADC_Mux_Controller
-- Module Name: ADC_Mux_Controller
--
-- Description:
-- Controls an external analog multiplexer connected to XADC VAUX4.
-- Sequentially samples three phase-current signals.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ADC_Mux_Controller is

    generic (

        -- Number of FPGA clock cycles to wait after changing mux channel.
        SETTLE_CYCLES : positive := 120;

        -- ADC zero-current offset.
        -- 2048 assumes a 12-bit ADC with a midpoint-biased sensor.
        ADC_ZERO_CODE : integer := 2048;

        --For our mux smd 
        
        MUX_SEL_WIDTH : positive := 3;

        -- Multiplexer selection codes.
        MUX_A_SEL : std_logic_vector(1 downto 0) := "000";
        MUX_B_SEL : std_logic_vector(1 downto 0) := "001";
        MUX_C_SEL : std_logic_vector(1 downto 0) := "010"
    );

    port (
        clk   : in std_logic;
        reset : in std_logic;

        -- ADC input
        adc_data  : in std_logic_vector(11 downto 0);
        adc_valid : in std_logic;

        -- External multiplexer selection
        mux_sel : out std_logic_vector(MUX_SEL_WIDTH - 1 downto 0);
        mux_en_n : out std_logic;
        
        -- Measured phase currents
        ia : out signed(15 downto 0);
        ib : out signed(15 downto 0);
        ic : out signed(15 downto 0);

        -- Pulses after all three currents have been collected
        current_valid : out std_logic
    );

end entity;


architecture rtl of ADC_Mux_Controller is

    type state_type is (
        SELECT_A,
        WAIT_A,
        SELECT_B,
        WAIT_B,
        SELECT_C,
        WAIT_C
    );

    signal state : state_type := SELECT_A;

    signal settle_counter : integer range 0 to SETTLE_CYCLES - 1 := 0;

    signal mux_sel_reg : std_logic_vector(MUX_SEL_WIDTH - 1 downto 0) := MUX_A_SEL;
    signal mux_en_n_reg : std_logic := '1'; -- Keep mux disabled during reset

    signal ia_reg : signed(15 downto 0) := (others => '0');
    signal ib_reg : signed(15 downto 0) := (others => '0');
    signal ic_reg : signed(15 downto 0) := (others => '0');

    signal current_valid_reg : std_logic := '0';

    --------------------------------------------------------------------------
    -- Convert 12-bit unsigned ADC result into signed current representation.
    --
    -- Assumes zero current corresponds to ADC_ZERO_CODE.
    --------------------------------------------------------------------------

    function adc_to_signed (
        value : std_logic_vector(11 downto 0)
    ) return signed is

        variable converted : integer;

    begin

        converted := to_integer(unsigned(value)) - ADC_ZERO_CODE;

        return to_signed(converted, 16);

    end function;

begin

    process(clk)
    begin

        if rising_edge(clk) then

            current_valid_reg <= '0';

            if reset = '1' then

                state <= SELECT_A;
                settle_counter <= 0;
                mux_en_n_reg <= '1';

                mux_sel_reg <= MUX_A_SEL;

                ia_reg <= (others => '0');
                ib_reg <= (others => '0');
                ic_reg <= (others => '0');

            else
                mux_en_n_reg <= '0';
                
                case state is

                    ----------------------------------------------------------
                    -- PHASE A
                    ----------------------------------------------------------

                    when SELECT_A =>

                        mux_sel_reg <= MUX_A_SEL;
                        settle_counter <= 0;

                        state <= WAIT_A;


                    when WAIT_A =>

                        if settle_counter < SETTLE_CYCLES - 1 then

                            settle_counter <= settle_counter + 1;

                        else

                            if adc_valid = '1' then

                                ia_reg <= adc_to_signed(adc_data);

                                settle_counter <= 0;
                                state <= SELECT_B;

                            end if;

                        end if;


                    ----------------------------------------------------------
                    -- PHASE B
                    ----------------------------------------------------------

                    when SELECT_B =>

                        mux_sel_reg <= MUX_B_SEL;
                        settle_counter <= 0;

                        state <= WAIT_B;


                    when WAIT_B =>

                        if settle_counter < SETTLE_CYCLES - 1 then

                            settle_counter <= settle_counter + 1;

                        else

                            if adc_valid = '1' then

                                ib_reg <= adc_to_signed(adc_data);

                                settle_counter <= 0;
                                state <= SELECT_C;

                            end if;

                        end if;


                    ----------------------------------------------------------
                    -- PHASE C
                    ----------------------------------------------------------

                    when SELECT_C =>

                        mux_sel_reg <= MUX_C_SEL;
                        settle_counter <= 0;

                        state <= WAIT_C;


                    when WAIT_C =>

                        if settle_counter < SETTLE_CYCLES - 1 then

                            settle_counter <= settle_counter + 1;

                        else

                            if adc_valid = '1' then

                                ic_reg <= adc_to_signed(adc_data);

                                current_valid_reg <= '1';

                                settle_counter <= 0;
                                state <= SELECT_A;

                            end if;

                        end if;

                end case;

            end if;

        end if;

    end process;

    mux_sel <= mux_sel_reg;

    ia <= ia_reg;
    ib <= ib_reg;
    ic <= ic_reg;

    current_valid <= current_valid_reg;
    
    mux_en_n <= mux_en_n_reg;

end architecture;
