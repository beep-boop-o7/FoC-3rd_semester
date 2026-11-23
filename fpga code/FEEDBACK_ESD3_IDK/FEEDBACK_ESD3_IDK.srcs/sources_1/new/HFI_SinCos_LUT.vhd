
----------------------------------------------------------------------------------
-- Design Name: FPGA-based FOC Controller
-- Module Name: HFI_SinCos_LUT
--
-- Description:
-- Converts an 8-bit electrical angle into sine and cosine values.
--
-- Angle:
--   0   = 0 degrees
--   64  = 90 degrees
--   128 = 180 degrees
--   192 = 270 degrees
--
-- Output format: signed Q1.15
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HFI_SinCos_LUT is
    port (
        theta_est : in unsigned(7 downto 0);

        sin_theta : out signed(15 downto 0);
        cos_theta : out signed(15 downto 0)
    );
end HFI_SinCos_LUT;

architecture Behavioral of HFI_SinCos_LUT is

    -- Quarter-wave sine lookup table.
    -- Values represent sin(index * 360 / 256)

    function quarter_sine(index : integer) return signed is
    begin
        case index is
            when 0  => return to_signed(0,16);
            when 1  => return to_signed(804,16);
            when 2  => return to_signed(1608,16);
            when 3  => return to_signed(2410,16);
            when 4  => return to_signed(3212,16);
            when 5  => return to_signed(4011,16);
            when 6  => return to_signed(4808,16);
            when 7  => return to_signed(5602,16);
            when 8  => return to_signed(6393,16);
            when 9  => return to_signed(7179,16);
            when 10 => return to_signed(7962,16);
            when 11 => return to_signed(8739,16);
            when 12 => return to_signed(9512,16);
            when 13 => return to_signed(10278,16);
            when 14 => return to_signed(11039,16);
            when 15 => return to_signed(11793,16);
            when 16 => return to_signed(12539,16);
            when 17 => return to_signed(13279,16);
            when 18 => return to_signed(14010,16);
            when 19 => return to_signed(14732,16);
            when 20 => return to_signed(15446,16);
            when 21 => return to_signed(16151,16);
            when 22 => return to_signed(16846,16);
            when 23 => return to_signed(17530,16);
            when 24 => return to_signed(18204,16);
            when 25 => return to_signed(18868,16);
            when 26 => return to_signed(19519,16);
            when 27 => return to_signed(20159,16);
            when 28 => return to_signed(20787,16);
            when 29 => return to_signed(21403,16);
            when 30 => return to_signed(22005,16);
            when 31 => return to_signed(22594,16);
            when 32 => return to_signed(23170,16);
            when 33 => return to_signed(23731,16);
            when 34 => return to_signed(24279,16);
            when 35 => return to_signed(24811,16);
            when 36 => return to_signed(25329,16);
            when 37 => return to_signed(25832,16);
            when 38 => return to_signed(26319,16);
            when 39 => return to_signed(26790,16);
            when 40 => return to_signed(27245,16);
            when 41 => return to_signed(27683,16);
            when 42 => return to_signed(28105,16);
            when 43 => return to_signed(28510,16);
            when 44 => return to_signed(28898,16);
            when 45 => return to_signed(29268,16);
            when 46 => return to_signed(29621,16);
            when 47 => return to_signed(29956,16);
            when 48 => return to_signed(30273,16);
            when 49 => return to_signed(30571,16);
            when 50 => return to_signed(30852,16);
            when 51 => return to_signed(31113,16);
            when 52 => return to_signed(31356,16);
            when 53 => return to_signed(31580,16);
            when 54 => return to_signed(31785,16);
            when 55 => return to_signed(31971,16);
            when 56 => return to_signed(32137,16);
            when 57 => return to_signed(32285,16);
            when 58 => return to_signed(32412,16);
            when 59 => return to_signed(32521,16);
            when 60 => return to_signed(32609,16);
            when 61 => return to_signed(32678,16);
            when 62 => return to_signed(32728,16);
            when 63 => return to_signed(32757,16);
            when 64 => return to_signed(32767,16);
            when others => return to_signed(0,16);
        end case;
    end function;

begin

    process(theta_est)

        variable quadrant : integer range 0 to 3;
        variable angle_index : integer range 0 to 63;

        variable sine_value : signed(15 downto 0);
        variable cosine_value : signed(15 downto 0);

    begin

        quadrant := to_integer(theta_est(7 downto 6));
        angle_index := to_integer(theta_est(5 downto 0));

        case quadrant is

            -- 0 to 90 degrees
            when 0 =>
                sine_value :=
                    quarter_sine(angle_index);

                cosine_value :=
                    quarter_sine(64 - angle_index);

            -- 90 to 180 degrees
            when 1 =>
                sine_value :=
                    quarter_sine(64 - angle_index);

                cosine_value :=
                    -quarter_sine(angle_index);

            -- 180 to 270 degrees
            when 2 =>
                sine_value :=
                    -quarter_sine(angle_index);

                cosine_value :=
                    -quarter_sine(64 - angle_index);

            -- 270 to 360 degrees
            when 3 =>
                sine_value :=
                    -quarter_sine(64 - angle_index);

                cosine_value :=
                    quarter_sine(angle_index);

        end case;

        sin_theta <= sine_value;
        cos_theta <= cosine_value;

    end process;

end Behavioral;

