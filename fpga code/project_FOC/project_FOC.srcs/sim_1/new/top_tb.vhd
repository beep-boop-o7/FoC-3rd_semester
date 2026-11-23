library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity top_tb is
end top_tb;

architecture sim of top_tb is

    signal clk : std_logic := '0';

    signal ea : std_logic_vector(11 downto 0);
    signal eb : std_logic_vector(11 downto 0);
    signal ec : std_logic_vector(11 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    ------------------------------------------------------------------
    -- DUT
    ------------------------------------------------------------------

    uut : entity work.top
    port map (
        clk => clk,
        ea  => ea,
        eb  => eb,
        ec  => ec
    );

    ------------------------------------------------------------------
    -- Clock
    ------------------------------------------------------------------

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    ------------------------------------------------------------------
    -- 3-fase sinusgenerator
    ------------------------------------------------------------------

    stim_proc : process

        variable angle : real := 0.0;

        constant AMP   : real := 1800.0;
        constant STEP  : real := 0.02;

        variable va : integer;
        variable vb : integer;
        variable vc : integer;

    begin

        while true loop

            va := integer(AMP * sin(angle));
            vb := integer(AMP * sin(angle + 2.0*MATH_PI/3.0));
            vc := integer(AMP * sin(angle - 2.0*MATH_PI/3.0));

            ea <= std_logic_vector(to_signed(va,12));
            eb <= std_logic_vector(to_signed(vb,12));
            ec <= std_logic_vector(to_signed(vc,12));

            angle := angle + STEP;

            wait for CLK_PERIOD;

        end loop;

    end process;

end sim;