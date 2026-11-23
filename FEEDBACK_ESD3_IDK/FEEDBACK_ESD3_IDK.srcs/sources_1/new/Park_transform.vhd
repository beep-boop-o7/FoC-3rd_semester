----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.11.2026 15:24:13
-- Design Name: 
-- Module Name: Park_transform - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Park_transform is
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        sample_enable : in  std_logic;

        -- Clarke current outputs
        ialpha        : in  signed(15 downto 0);
        ibeta         : in  signed(15 downto 0);

        -- Estimated electrical angle
        -- 0 to 255 = 0 to 360 degrees
        theta_est     : in  unsigned(7 downto 0);

        -- Park transform outputs
        id            : out signed(15 downto 0);
        iq            : out signed(15 downto 0)
    );
end Park_transform;


architecture Behavioral of Park_transform is

    signal id_reg : signed(15 downto 0) := (others => '0');
    signal iq_reg : signed(15 downto 0) := (others => '0');

    -- 64-point sine table, Q1.15

    function sine_lut(index : unsigned(5 downto 0))
        return signed is
    begin
        case to_integer(index) is

            when  0 => return to_signed(     0,16);
            when  1 => return to_signed(  3212,16);
            when  2 => return to_signed(  6393,16);
            when  3 => return to_signed(  9512,16);
            when  4 => return to_signed( 12539,16);
            when  5 => return to_signed( 15446,16);
            when  6 => return to_signed( 18204,16);
            when  7 => return to_signed( 20787,16);
            when  8 => return to_signed( 23170,16);
            when  9 => return to_signed( 25329,16);
            when 10 => return to_signed( 27245,16);
            when 11 => return to_signed( 28898,16);
            when 12 => return to_signed( 30273,16);
            when 13 => return to_signed( 31356,16);
            when 14 => return to_signed( 32137,16);
            when 15 => return to_signed( 32609,16);

            when 16 => return to_signed( 32767,16);
            when 17 => return to_signed( 32609,16);
            when 18 => return to_signed( 32137,16);
            when 19 => return to_signed( 31356,16);
            when 20 => return to_signed( 30273,16);
            when 21 => return to_signed( 28898,16);
            when 22 => return to_signed( 27245,16);
            when 23 => return to_signed( 25329,16);
            when 24 => return to_signed( 23170,16);
            when 25 => return to_signed( 20787,16);
            when 26 => return to_signed( 18204,16);
            when 27 => return to_signed( 15446,16);
            when 28 => return to_signed( 12539,16);
            when 29 => return to_signed(  9512,16);
            when 30 => return to_signed(  6393,16);
            when 31 => return to_signed(  3212,16);

            when 32 => return to_signed(     0,16);
            when 33 => return to_signed( -3212,16);
            when 34 => return to_signed( -6393,16);
            when 35 => return to_signed( -9512,16);
            when 36 => return to_signed(-12539,16);
            when 37 => return to_signed(-15446,16);
            when 38 => return to_signed(-18204,16);
            when 39 => return to_signed(-20787,16);
            when 40 => return to_signed(-23170,16);
            when 41 => return to_signed(-25329,16);
            when 42 => return to_signed(-27245,16);
            when 43 => return to_signed(-28898,16);
            when 44 => return to_signed(-30273,16);
            when 45 => return to_signed(-31356,16);
            when 46 => return to_signed(-32137,16);
            when 47 => return to_signed(-32609,16);

            when 48 => return to_signed(-32767,16);
            when 49 => return to_signed(-32609,16);
            when 50 => return to_signed(-32137,16);
            when 51 => return to_signed(-31356,16);
            when 52 => return to_signed(-30273,16);
            when 53 => return to_signed(-28898,16);
            when 54 => return to_signed(-27245,16);
            when 55 => return to_signed(-25329,16);
            when 56 => return to_signed(-23170,16);
            when 57 => return to_signed(-20787,16);
            when 58 => return to_signed(-18204,16);
            when 59 => return to_signed(-15446,16);
            when 60 => return to_signed(-12539,16);
            when 61 => return to_signed( -9512,16);
            when 62 => return to_signed( -6393,16);
            when 63 => return to_signed( -3212,16);

            when others => return to_signed(0,16);

        end case;
    end function;


    -- Saturate 33-bit result after Q15 scaling

    function saturate(value : signed(32 downto 0))
        return signed is

        variable shifted : signed(32 downto 0);

    begin

        shifted := shift_right(value,15);

        if shifted > to_signed(32767,33) then

            return to_signed(32767,16);

        elsif shifted < to_signed(-32768,33) then

            return to_signed(-32768,16);

        else

            return resize(shifted,16);

        end if;

    end function;


begin

    id <= id_reg;
    iq <= iq_reg;


    process(clk)

        variable angle_index : unsigned(5 downto 0);
        variable cos_index   : unsigned(5 downto 0);

        variable sine_value : signed(15 downto 0);
        variable cos_value  : signed(15 downto 0);

        variable product_1 : signed(31 downto 0);
        variable product_2 : signed(31 downto 0);
        variable product_3 : signed(31 downto 0);
        variable product_4 : signed(31 downto 0);

        variable id_sum : signed(32 downto 0);
        variable iq_sum : signed(32 downto 0);

    begin

        if rising_edge(clk) then

            if reset = '1' then

                id_reg <= (others => '0');
                iq_reg <= (others => '0');

            elsif sample_enable = '1' then

                -- Convert 8-bit angle to 64-point LUT index
                angle_index := theta_est(7 downto 2);

                -- Cos(theta) = Sin(theta + 90 degrees)
                cos_index := angle_index + to_unsigned(16,6);

                sine_value := sine_lut(angle_index);
                cos_value  := sine_lut(cos_index);


                -- Id = Ialpha*cos(theta) + Ibeta*sin(theta)

                product_1 := ialpha * cos_value;
                product_2 := ibeta  * sine_value;

                id_sum :=
                    resize(product_1,33)
                    +
                    resize(product_2,33);


                -- Iq = -Ialpha*sin(theta) + Ibeta*cos(theta)

                product_3 := ialpha * sine_value;
                product_4 := ibeta  * cos_value;

                iq_sum :=
                    -resize(product_3,33)
                    +
                    resize(product_4,33);


                -- Scale back from Q15 coefficient

                id_reg <= saturate(id_sum);
                iq_reg <= saturate(iq_sum);

            end if;

        end if;

    end process;

end Behavioral;
