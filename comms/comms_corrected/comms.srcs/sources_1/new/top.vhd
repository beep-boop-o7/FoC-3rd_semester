library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  port (
    sysclk  : in  std_logic;     -- 12 MHz oscillator
    uart_rx : in  std_logic;     -- from Arduino TX1 (through level shifter)
    uart_tx : out std_logic      -- to Arduino RX1
  );
end entity top;

architecture rtl of top is
  signal freq_cmd : signed(15 downto 0);   -- electrical frequency, 0.1 Hz units
begin

  u_link : entity work.rpm_link
    generic map (
      CLKS_PER_BIT        => 104,
      WATCHDOG_CYCLES     => 2_400_000,
      BYTE_TIMEOUT_CYCLES => 24_000,
      TELEMETRY_CYCLES    => 600_000,
      MAX_FREQ            => 20000,
      KP_INIT             => 150,
      KI_INIT             => 20)
    port map (
      clk         => sysclk,
      rst         => '0',
      uart_rx_pin => uart_rx,
      uart_tx_pin => uart_tx,
      meas_freq   => freq_cmd,    -- loopback: the reference is sent back as the "measured" frequency
      ref_freq    => freq_cmd,
      kp_val      => open,        -- later: to the speed controller
      ki_val      => open,
      ref_valid   => open,
      link_ok     => open,
      bad_packet  => open);

end architecture rtl;
