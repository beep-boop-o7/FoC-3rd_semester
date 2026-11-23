library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pi_ctrl is
    generic (
        OUT_MAX : integer := 32767            -- output and integrator clamp (Q1.15)
    );
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        start : in  std_logic;                -- one-cycle pulse, once per control period
        ref   : in  signed(15 downto 0);      -- Q1.15
        meas  : in  signed(15 downto 0);      -- Q1.15
        kp    : in  signed(15 downto 0);      -- Q4.12
        ki    : in  signed(15 downto 0);      -- Q4.12, already includes Ts
        u     : out signed(15 downto 0);      -- Q1.15, saturated
        done  : out std_logic
    );
end pi_ctrl;

architecture rtl of pi_ctrl is
    signal err    : signed(16 downto 0) := (others => '0');
    signal p_prod : signed(32 downto 0) := (others => '0');
    signal i_prod : signed(32 downto 0) := (others => '0');
    signal integ  : signed(31 downto 0) := (others => '0');
    signal state  : unsigned(1 downto 0) := (others => '0');
begin

    process(clk)
        variable p_s, i_s, integ_n, sum : signed(31 downto 0);
        constant LIM_P : signed(31 downto 0) := to_signed( OUT_MAX, 32);
        constant LIM_N : signed(31 downto 0) := to_signed(-OUT_MAX, 32);
    begin
        if rising_edge(clk) then
            done <= '0';

            if rst = '1' then
                integ <= (others => '0');
                state <= (others => '0');
                u     <= (others => '0');
            else
                case state is

                    when "00" =>                          -- wait for start, form the error
                        if start = '1' then
                            err   <= resize(ref, 17) - resize(meas, 17);
                            state <= "01";
                        end if;

                    when "01" =>                          -- multiply
                        p_prod <= err * kp;
                        i_prod <= err * ki;
                        state  <= "10";

                    when others =>                        -- accumulate, clamp, output
                        p_s := resize(shift_right(p_prod, 12), 32);
                        i_s := resize(shift_right(i_prod, 12), 32);

                        integ_n := integ + i_s;
                        if    integ_n > LIM_P then integ_n := LIM_P;
                        elsif integ_n < LIM_N then integ_n := LIM_N;
                        end if;

                        sum := p_s + integ_n;
                        if    sum > LIM_P then sum := LIM_P;
                        elsif sum < LIM_N then sum := LIM_N;
                        end if;

                        integ <= integ_n;
                        u     <= resize(sum, 16);
                        done  <= '1';
                        state <= "00";

                end case;
            end if;
        end if;
    end process;

end rtl;