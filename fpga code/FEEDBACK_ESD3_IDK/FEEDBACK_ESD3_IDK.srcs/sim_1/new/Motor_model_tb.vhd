
----------------------------------------------------------------------------------
-- Testbench: Motor_Model
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Motor_Model_tb is
end Motor_Model_tb;

architecture Behavioral of Motor_Model_tb is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- Q7.12 voltages
    signal valpha : signed(19 downto 0) := (others => '0');
    signal vbeta  : signed(19 downto 0) := (others => '0');

    -- Q3.12 predicted currents
    signal ihat_alpha : signed(15 downto 0);
    signal ihat_beta  : signed(15 downto 0);


    signal sample_enable : std_logic := '0';
    signal estimate_valid : std_logic;


begin

    -- Clock: 10 ns period

    clk <= not clk after 5 ns;


    -- Motor model instance

    DUT : entity work.Motor_Model

        generic map (

            RS_FIXED => 2048,
            K_FIXED  => 41

        )

       port map (
    clk            => clk,
    reset          => reset,
    sample_enable  => sample_enable,

    valpha         => valpha,
    vbeta          => vbeta,

    ihat_alpha     => ihat_alpha,
    ihat_beta      => ihat_beta,

    estimate_valid => estimate_valid
);


    -- Test sequence

    process

    begin

        -- TEST 1: RESET

        reset <= '1';

        wait for 20 ns;

        reset <= '0';


        -- TEST 2: POSITIVE ALPHA VOLTAGE (1 V)

        valpha <= to_signed(4096, 20);
        vbeta  <= to_signed(0, 20);

        wait for 1000 ns;


        -- TEST 3: ZERO VOLTAGE

        valpha <= to_signed(0, 20);

        wait for 1000 ns;


        -- TEST 4: NEGATIVE ALPHA VOLTAGE (-1 V)

        valpha <= to_signed(-4096, 20);

        wait for 1000 ns;


        -- TEST 5: POSITIVE BETA VOLTAGE (1 V)

        valpha <= to_signed(0, 20);
        vbeta  <= to_signed(4096, 20);

        wait for 1000 ns;


        -- END SIMULATION

        wait;

    end process;

end Behavioral;
