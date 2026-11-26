-- uart_rx.vhd
-- 8N1 UART receiver. LSB first, one start bit, one stop bit.
-- Defaults: 12 MHz clock, 115200 baud -> 12_000_000 / 115_200 = 104.17 -> 104 (0.16 % error)

library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
  generic (
    CLKS_PER_BIT : positive := 104
  );
  port (
    clk       : in  std_logic;
    rx        : in  std_logic;                       -- asynchronous pin
    data      : out std_logic_vector(7 downto 0);
    valid     : out std_logic;                       -- 1-clock pulse, data is valid
    frame_err : out std_logic                        -- 1-clock pulse, stop bit was not '1'
  );
end entity uart_rx;

architecture rtl of uart_rx is
  type state_t is (S_IDLE, S_START, S_DATA, S_STOP);
  signal state   : state_t := S_IDLE;
  signal sync1   : std_logic := '1';
  signal sync2   : std_logic := '1';
  signal cnt     : integer range 0 to CLKS_PER_BIT - 1 := 0;
  signal bit_idx : integer range 0 to 7 := 0;
  signal shreg   : std_logic_vector(7 downto 0) := (others => '0');
begin

  process (clk)
  begin
    if rising_edge(clk) then
      -- 2-flip-flop synchronizer (the pin is asynchronous to clk)
      sync1 <= rx;
      sync2 <= sync1;

      valid     <= '0';
      frame_err <= '0';

      case state is

        when S_IDLE =>
          cnt     <= 0;
          bit_idx <= 0;
          if sync2 = '0' then               -- falling edge = start bit
            state <= S_START;
          end if;

        when S_START =>
          -- wait half a bit so we are in the middle of the start bit
          if cnt = CLKS_PER_BIT / 2 - 1 then
            cnt <= 0;
            if sync2 = '0' then             -- still low: real start bit
              state <= S_DATA;
            else                            -- glitch: ignore
              state <= S_IDLE;
            end if;
          else
            cnt <= cnt + 1;
          end if;

        when S_DATA =>
          -- from here on, every full bit time lands in the middle of the next bit
          if cnt = CLKS_PER_BIT - 1 then
            cnt   <= 0;
            shreg <= sync2 & shreg(7 downto 1);   -- LSB arrives first
            if bit_idx = 7 then
              state <= S_STOP;
            else
              bit_idx <= bit_idx + 1;
            end if;
          else
            cnt <= cnt + 1;
          end if;

        when S_STOP =>
          -- middle of the stop bit
          if cnt = CLKS_PER_BIT - 1 then
            cnt   <= 0;
            state <= S_IDLE;
            if sync2 = '1' then
              data  <= shreg;
              valid <= '1';
            else
              frame_err <= '1';
            end if;
          else
            cnt <= cnt + 1;
          end if;

      end case;
    end if;
  end process;

end architecture rtl;