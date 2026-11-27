-- uart_tx.vhd
-- 8N1 UART transmitter. LSB first, one start bit, one stop bit.
-- Pulse 'start' for one clock while 'busy' = '0'. 'data' is latched on 'start'.

library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
  generic (
    CLKS_PER_BIT : positive := 104
  );
  port (
    clk   : in  std_logic;
    start : in  std_logic;
    data  : in  std_logic_vector(7 downto 0);
    busy  : out std_logic;
    tx    : out std_logic
  );
end entity uart_tx;

architecture rtl of uart_tx is
  type state_t is (S_IDLE, S_SEND);
  signal state   : state_t := S_IDLE;
  signal cnt     : integer range 0 to CLKS_PER_BIT - 1 := 0;
  signal bit_idx : integer range 0 to 9 := 0;
  -- frame(0) = start bit, frame(8 downto 1) = data (LSB first), frame(9) = stop bit
  signal frame   : std_logic_vector(9 downto 0) := (others => '1');
  signal tx_reg  : std_logic := '1';
  signal busy_i  : std_logic := '0';
begin

  tx   <= tx_reg;
  busy <= busy_i;

  process (clk)
  begin
    if rising_edge(clk) then
      case state is

        when S_IDLE =>
          tx_reg <= '1';
          if start = '1' then
            frame   <= '1' & data & '0';
            tx_reg  <= '0';                 -- start bit begins immediately
            cnt     <= 0;
            bit_idx <= 0;
            busy_i  <= '1';
            state   <= S_SEND;
          end if;

        when S_SEND =>
          if cnt = CLKS_PER_BIT - 1 then
            cnt <= 0;
            if bit_idx = 9 then             -- stop bit has been held for a full bit time
              tx_reg <= '1';
              busy_i <= '0';
              state  <= S_IDLE;
            else
              bit_idx <= bit_idx + 1;
              tx_reg  <= frame(bit_idx + 1);
            end if;
          else
            cnt <= cnt + 1;
          end if;

      end case;
    end if;
  end process;

end architecture rtl;
