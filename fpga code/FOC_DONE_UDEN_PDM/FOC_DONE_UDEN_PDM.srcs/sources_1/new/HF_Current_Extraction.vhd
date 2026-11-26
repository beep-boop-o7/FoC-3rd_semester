
----------------------------------------------------------------------------------
-- Design Name: FPGA-based FOC Controller
-- Module Name: HF_Current_Extraction
--
-- Description:
-- Extracts the high-frequency components of the measured
-- alpha-beta currents using a first-order high-pass filter.
--
-- The high-pass filter is implemented as:
--
-- I_HF = I_measured - I_LPF
--
-- The LPF coefficient is configurable using Q15.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity HF_Current_Extraction is

    generic (

        -- Smaller value = lower LPF cutoff frequency
        LPF_ALPHA_Q15 : integer := 512

    );

    port (

        clk           : in std_logic;
        reset         : in std_logic;
        sample_enable : in std_logic;

        -- Clarke-transformed measured currents
        ialpha_in : in signed(15 downto 0);
        ibeta_in  : in signed(15 downto 0);

        -- Extracted high-frequency currents
        ihf_alpha : out signed(15 downto 0);
        ihf_beta  : out signed(15 downto 0);

        -- Indicates a new HF sample
        hf_valid : out std_logic

    );

end HF_Current_Extraction;


architecture Behavioral of HF_Current_Extraction is


    -- Low-pass filter states

    signal lpf_alpha_reg : signed(15 downto 0) := (others => '0');
    signal lpf_beta_reg  : signed(15 downto 0) := (others => '0');


    -- High-frequency output registers

    signal ihf_alpha_reg : signed(15 downto 0) := (others => '0');
    signal ihf_beta_reg  : signed(15 downto 0) := (others => '0');

    signal hf_valid_reg : std_logic := '0';


    -- Saturate a 17-bit value to signed 16-bit

    function saturate_16(value : signed(16 downto 0))
        return signed is

    begin

        if value > to_signed(32767,17) then

            return to_signed(32767,16);

        elsif value < to_signed(-32768,17) then

            return to_signed(-32768,16);

        else

            return resize(value,16);

        end if;

    end function;


begin


    ihf_alpha <= ihf_alpha_reg;
    ihf_beta  <= ihf_beta_reg;

    hf_valid <= hf_valid_reg;


    process(clk)

        -- Current differences
        variable alpha_error : signed(16 downto 0);
        variable beta_error  : signed(16 downto 0);

        --
        variable alpha_product : signed(32 downto 0);
        variable beta_product  : signed(32 downto 0);

        -- LPF changes
        variable alpha_delta : signed(16 downto 0);
        variable beta_delta  : signed(16 downto 0);

        -- Updated LPF values
        variable alpha_lpf_next : signed(15 downto 0);
        variable beta_lpf_next  : signed(15 downto 0);

        -- Extracted HF currents
        variable alpha_hf : signed(16 downto 0);
        variable beta_hf  : signed(16 downto 0);

    begin

        if rising_edge(clk) then

            if reset = '1' then

                lpf_alpha_reg <= (others => '0');
                lpf_beta_reg  <= (others => '0');

                ihf_alpha_reg <= (others => '0');
                ihf_beta_reg  <= (others => '0');

                hf_valid_reg <= '0';


            else

                hf_valid_reg <= '0';

                if sample_enable = '1' then


                    --CALCULATE CURRENT ERROR


                    alpha_error := resize(ialpha_in,17) -  resize(lpf_alpha_reg,17);

                    beta_error := resize(ibeta_in,17) - resize(lpf_beta_reg,17);

                    --LOW-PASS FILTER UPDATE

                    alpha_product := alpha_error * to_signed(LPF_ALPHA_Q15,16);

                    beta_product := beta_error * to_signed(LPF_ALPHA_Q15,16);
                        
                    -- Divide by 2^15 to restore scaling

                    alpha_delta := resize(shift_right(alpha_product,15),17);

                    beta_delta := resize(shift_right(beta_product,15),17);

                    --UPDATE LPF STATES

                    alpha_lpf_next := saturate_16(resize(lpf_alpha_reg,17) + alpha_delta);

                    beta_lpf_next := saturate_16(resize(lpf_beta_reg,17) + beta_delta);


                    -- EXTRACT HIGH FREQUENCY COMPONENT

                    alpha_hf := resize(ialpha_in,17) - resize(alpha_lpf_next,17);

                    beta_hf := resize(ibeta_in,17) - resize(beta_lpf_next,17);

                    -- REGISTER OUTPUTS

                    lpf_alpha_reg <= alpha_lpf_next;
                    lpf_beta_reg  <= beta_lpf_next;

                    ihf_alpha_reg <= saturate_16(alpha_hf);
                    ihf_beta_reg  <= saturate_16(beta_hf);

                    hf_valid_reg <= '1';

                end if;

            end if;

        end if;

    end process;


end Behavioral;
