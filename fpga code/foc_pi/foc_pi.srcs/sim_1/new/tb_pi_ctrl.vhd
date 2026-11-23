library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_pi_ctrl is
end tb_pi_ctrl;

architecture sim of tb_pi_ctrl is

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';
    signal done  : std_logic;
    signal ref   : signed(15 downto 0) := (others => '0');
    signal meas  : signed(15 downto 0) := (others => '0');
    signal kp    : signed(15 downto 0) := (others => '0');
    signal ki    : signed(15 downto 0) := (others => '0');
    signal u     : signed(15 downto 0);

begin

    clk <= not clk after 5 ns;      -- 100 MHz

    dut : entity work.pi_ctrl
        generic map (OUT_MAX => 32767)
        port map (clk => clk, rst => rst, start => start,
                  ref => ref, meas => meas, kp => kp, ki => ki,
                  u => u, done => done);

    stim : process

        -- one control update: pulse start, wait for done, then idle
        procedure update is
        begin
            wait until rising_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until done = '1';
            wait for 1 us;
        end procedure;

    begin
        -- reset
        rst <= '1';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait for 100 ns;

        -- Test 1: step input, P and I together
        ref  <= to_signed(16384, 16);
        meas <= to_signed(0, 16);
        kp   <= to_signed(4096, 16);
        ki   <= to_signed(41, 16);

        update;
        assert u = to_signed(16548, 16)
            report "Test 1a failed: expected 16548" severity error;
        update;
        assert u = to_signed(16712, 16)
            report "Test 1b failed: expected 16712" severity error;

        for n in 3 to 110 loop
            update;
        end loop;
        assert u = to_signed(32767, 16)
            report "Test 1c failed: expected saturation at 32767" severity error;

        -- Test 2: error goes to zero, the integrator should hold the value
        meas <= to_signed(16384, 16);
        update;
        report "Test 2: u after error = 0 is " & integer'image(to_integer(u))
               & " (should equal the integrator, 110 x 164 = 18040)";
        assert u = to_signed(18040, 16)
            report "Test 2 failed: integrator should hold" severity error;

        -- Test 3: small error, shows the dead zone discussed earlier
        rst <= '1';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait for 100 ns;
        ref  <= to_signed(50, 16);
        meas <= to_signed(0, 16);
        for n in 1 to 20 loop
            update;
        end loop;
        report "Test 3: u with err = 50 after 20 updates is "
               & integer'image(to_integer(u))
               & " (a working integrator would have ramped above 50)";

        report "Simulation finished";
        wait;
    end process;

end sim;