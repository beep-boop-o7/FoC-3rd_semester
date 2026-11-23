
----------------------------------------------------------------------------------
-- Design Name: FPGA-based FOC Controller
-- Module Name: HFI_Demodulation
--
-- Description:
-- Synchronous demodulation of the extracted high-frequency
-- q-axis current.
--
-- Processing:
-- 1. Transform the extracted HF current from alpha/beta to q-axis.
-- 2. Multiply the q-axis current by the injection carrier.
-- 3. Apply a low-pass filter to obtain the position error.
--
-- Fixed-point formats:
-- ihf_alpha/beta : signed 16-bit current format
-- sin_theta      : Q1.15
-- cos_theta      : Q1.15
-- injection      : Q1.15
-- LPF alpha      : Q0.15
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity HFI_Demodulation is

    generic (
        LPF_ALPHA_Q15  : integer := 1024;
        DEMOD_POLARITY : integer := 1
    );

    port (
        clk               : in  std_logic;
        reset             : in  std_logic;

        sample_enable     : in  std_logic;
        hf_valid          : in  std_logic;

        ihf_alpha         : in  signed(15 downto 0);
        ihf_beta          : in  signed(15 downto 0);

        sin_theta         : in  signed(15 downto 0);
        cos_theta         : in  signed(15 downto 0);

        injection_carrier : in  signed(15 downto 0);

        demodulated_q     : out signed(15 downto 0);
        demodulated_valid : out std_logic
    );

end HFI_Demodulation;


architecture Behavioral of HFI_Demodulation is

    signal demod_lpf_reg : signed(15 downto 0) := (others => '0');

    signal demod_valid_reg : std_logic := '0';

    -- Saturate a 17-bit value to signed 16-bit.

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


    -- Saturate a 33-bit value to signed 16-bit.

    function saturate_33(value : signed(32 downto 0))
        return signed is
    begin

        if value > to_signed(32767,33) then
            return to_signed(32767,16);

        elsif value < to_signed(-32768,33) then
            return to_signed(-32768,16);

        else
            return resize(value,16);
        end if;

    end function;


begin

    -- Connect internal registers to output ports.

    demodulated_q     <= demod_lpf_reg;
    demodulated_valid <= demod_valid_reg;


    process(clk)

        variable product_alpha_sin : signed(31 downto 0);
        variable product_beta_cos  : signed(31 downto 0);

        variable q_axis_sum        : signed(32 downto 0);
        variable q_axis_scaled     : signed(32 downto 0);

        variable demod_product     : signed(31 downto 0);
        variable demod_scaled      : signed(31 downto 0);

        variable demod_sample      : signed(15 downto 0);

        variable filter_error      : signed(16 downto 0);
        variable filter_product    : signed(32 downto 0);
        variable filter_delta      : signed(16 downto 0);
        variable filter_next       : signed(15 downto 0);

    begin

        if rising_edge(clk) then

            if reset = '1' then

                demod_lpf_reg <= (others => '0');
                demod_valid_reg <= '0';

            else

                demod_valid_reg <= '0';

                if hf_valid = '1' then
                

                    -- TRANSFORM HF CURRENT INTO Q-AXIS
                    

                    product_alpha_sin := ihf_alpha * sin_theta;

                    product_beta_cos := ihf_beta * cos_theta;
                        
                    q_axis_sum := -resize(product_alpha_sin,33) + resize(product_beta_cos,33);
                    
                    -- Restore current scaling after multiplication.

                    q_axis_scaled := shift_right(q_axis_sum,15);

                    demod_sample := saturate_33(q_axis_scaled);
                    

                    -- SYNCHRONOUS DEMODULATION
                    

                    demod_product := demod_sample * injection_carrier;

                    demod_scaled := shift_right(demod_product,15);
                        
                    demod_sample := saturate_33(resize(demod_scaled,33));
                    

                    -- SELECT DEMODULATION POLARITY


                    if DEMOD_POLARITY = -1 then

                        demod_sample := -demod_sample;

                    end if;

                    -- LOW-PASS FILTER

                    filter_error := resize(demod_sample,17) - resize(demod_lpf_reg,17); 

                    filter_product := filter_error * to_signed(LPF_ALPHA_Q15,16);

                    filter_delta := resize(shift_right(filter_product,15),17);


                    -- UPDATE FILTER


                    filter_next :=  saturate_16(resize(demod_lpf_reg,17)+filter_delta);

                    demod_lpf_reg <= filter_next;

                    demod_valid_reg <= '1';

                end if;

            end if;

        end if;

    end process;

end Behavioral;
