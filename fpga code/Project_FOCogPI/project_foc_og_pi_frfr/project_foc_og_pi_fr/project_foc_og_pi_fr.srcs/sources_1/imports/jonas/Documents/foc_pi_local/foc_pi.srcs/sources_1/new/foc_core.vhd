library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity foc_core is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        current_tick : in  std_logic;   -- ~20 kHz
        speed_tick   : in  std_logic;   -- current_tick divided down

        speed_ref    : in  signed(15 downto 0);   -- Q1.15
        speed_meas   : in  signed(15 downto 0);
        iq_meas      : in  signed(15 downto 0);
        id_meas      : in  signed(15 downto 0);

        vq           : out signed(15 downto 0);
        vd           : out signed(15 downto 0)
    );
end foc_core;

architecture rtl of foc_core is

    -- internal wires between the blocks
    signal iq_ref : signed(15 downto 0);
    signal id_ref : signed(15 downto 0);
    signal id_ref_mod : signed(15 downto 0);

    -- gains (Q4.12), placeholder values until you tune them
    constant kp_speed : signed(15 downto 0) := to_signed(4096, 16);   -- 1.0
    constant ki_speed : signed(15 downto 0) := to_signed(41,   16);
    constant kp_iq    : signed(15 downto 0) := to_signed(4096, 16);
    constant ki_iq    : signed(15 downto 0) := to_signed(41,   16);
    constant kp_id    : signed(15 downto 0) := to_signed(4096, 16);
    constant ki_id    : signed(15 downto 0) := to_signed(41,   16);

begin


    iq_ref <= (others => '0');                  -- no flux-producing current

    u_speed_pi : entity work.pi_ctrl
        generic map (OUT_MAX => 16384)          -- current limit
        port map (clk => clk, rst => rst, start => speed_tick,
                  ref => speed_ref, meas => speed_meas,
                  kp => kp_speed, ki => ki_speed,
                  u => id_ref, done => open);

    u_iq_pi : entity work.pi_ctrl
        generic map (OUT_MAX => 32767)          -- voltage limit
        port map (clk => clk, rst => rst, start => current_tick,
                  ref => iq_ref, meas => iq_meas,
                  kp => kp_iq, ki => ki_iq,
                  u => vq, done => open);

    u_id_pi : entity work.pi_ctrl
        generic map (OUT_MAX => 32767)
        port map (clk => clk, rst => rst, start => current_tick,
                  ref => id_ref, meas => id_meas,
                  kp => kp_id, ki => ki_id,
                  u => vd, done => open);
end rtl;