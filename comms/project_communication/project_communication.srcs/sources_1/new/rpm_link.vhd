-- rpm_link.vhd
-- UART link between the Arduino Mega and the FOC logic.
--
--   Arduino -> FPGA : 0xA5, CMD, DATA_hi, DATA_lo, checksum
--   FPGA -> Arduino : 0x5A, ID,  DATA_hi, DATA_lo, checksum
--   checksum = XOR of the first four bytes
--
--   CMD 0x01 = reference frequency (signed 16-bit, electrical frequency in 0.1 Hz units,
--              clamped to +/- MAX_FREQ). The Arduino converts RPM -> frequency.
--   CMD 0x02 = Kp              (unsigned 16-bit)
--   CMD 0x03 = Ki              (unsigned 16-bit)
--   ID  0x01 = measured frequency (signed 16-bit, 0.1 Hz units)
--   ID  0x02 = Kp as stored in the FPGA
--   ID  0x03 = Ki as stored in the FPGA
--
-- The FPGA sends these three frames by itself every TELEMETRY_CYCLES
-- (600_000 cycles = 50 ms at 12 MHz), whether or not the Arduino sends anything.
--
-- Safety behaviour:
--   * A packet is only accepted after a correct header AND checksum.
--   * The reference is clamped to +/- MAX_FREQ.
--   * Every valid packet feeds the watchdog. If none arrives within WATCHDOG_CYCLES
--     (2_400_000 cycles = 200 ms at 12 MHz), ref_freq is forced to 0.
--     The reference is also 0 after power-up. Kp and Ki are kept.
--   * If a packet stalls half-way (lost byte), the parser resynchronises after BYTE_TIMEOUT_CYCLES.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rpm_link is
  generic (
    CLKS_PER_BIT         : positive := 104;        -- 12 MHz / 115200
    WATCHDOG_CYCLES      : positive := 2_400_000;  -- 200 ms @ 12 MHz
    BYTE_TIMEOUT_CYCLES  : positive := 24_000;     -- 2 ms @ 12 MHz
    TELEMETRY_CYCLES     : positive := 600_000;    -- 50 ms @ 12 MHz
    MAX_FREQ             : positive := 20000;      -- PLACEHOLDER: 20000 RPM x 6 pole pairs / 6 (0.1 Hz units)
    KP_INIT              : natural  := 150;        -- gains used until the Arduino sends new ones
    KI_INIT              : natural  := 20
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;                  -- synchronous, active high
    uart_rx_pin  : in  std_logic;                  -- from Arduino TX1 (through level shifter)
    uart_tx_pin  : out std_logic;                  -- to Arduino RX1
    meas_freq    : in  signed(15 downto 0);        -- measured electrical frequency from the FOC logic (0.1 Hz)
    ref_freq     : out signed(15 downto 0);        -- reference electrical frequency to the sine generator (0.1 Hz)
    kp_val       : out unsigned(15 downto 0);      -- Kp to the FOC logic
    ki_val       : out unsigned(15 downto 0);      -- Ki to the FOC logic
    ref_valid    : out std_logic;                  -- 1-clock pulse for every accepted reference packet
    link_ok      : out std_logic;                  -- '1' while the watchdog has not expired
    bad_packet   : out std_logic                   -- 1-clock pulse: checksum error, unknown command, framing error or timeout
  );
end entity rpm_link;

architecture rtl of rpm_link is

  constant HDR_CMD : std_logic_vector(7 downto 0) := x"A5";
  constant HDR_RPL : std_logic_vector(7 downto 0) := x"5A";
  constant CMD_REF : std_logic_vector(7 downto 0) := x"01";
  constant CMD_KP  : std_logic_vector(7 downto 0) := x"02";
  constant CMD_KI  : std_logic_vector(7 downto 0) := x"03";
  constant ID_SPEED : std_logic_vector(7 downto 0) := x"01";
  constant ID_KP    : std_logic_vector(7 downto 0) := x"02";
  constant ID_KI    : std_logic_vector(7 downto 0) := x"03";

  -- UART blocks
  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid : std_logic;
  signal rx_err   : std_logic;
  signal tx_start : std_logic := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy  : std_logic;

  -- parser
  type pstate_t is (P_HDR, P_CMD, P_HI, P_LO, P_CK);
  signal pstate    : pstate_t := P_HDR;
  signal cmd_b, hi_b, lo_b : std_logic_vector(7 downto 0) := (others => '0');
  signal bt_cnt    : integer range 0 to BYTE_TIMEOUT_CYCLES := 0;
  signal wd_cnt    : integer range 0 to WATCHDOG_CYCLES := WATCHDOG_CYCLES;  -- starts expired
  signal ref_i     : signed(15 downto 0) := (others => '0');
  signal kp_i      : unsigned(15 downto 0) := to_unsigned(KP_INIT, 16);
  signal ki_i      : unsigned(15 downto 0) := to_unsigned(KI_INIT, 16);
  signal link_ok_i : std_logic := '0';
  signal ref_valid_i  : std_logic := '0';
  signal bad_packet_i : std_logic := '0';

  -- telemetry sender
  type byte_array_t is array (0 to 4) of std_logic_vector(7 downto 0);
  type tstate_t is (T_IDLE, T_BUILD, T_LOAD, T_WAIT_BUSY, T_WAIT_DONE);
  signal tstate    : tstate_t := T_IDLE;
  signal rep       : byte_array_t := (others => (others => '0'));
  signal tx_idx    : integer range 0 to 4 := 0;
  signal frame_idx : integer range 0 to 2 := 0;
  signal tele_cnt  : integer range 0 to TELEMETRY_CYCLES - 1 := 0;
  signal tele_pend : std_logic := '0';

begin

  ref_freq    <= ref_i;
  kp_val     <= kp_i;
  ki_val     <= ki_i;
  link_ok    <= link_ok_i;
  ref_valid  <= ref_valid_i;
  bad_packet <= bad_packet_i;

  u_rx : entity work.uart_rx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (clk => clk, rx => uart_rx_pin, data => rx_data, valid => rx_valid, frame_err => rx_err);

  u_tx : entity work.uart_tx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (clk => clk, start => tx_start, data => tx_data, busy => tx_busy, tx => uart_tx_pin);

  ---------------------------------------------------------------------------
  -- Packet parser + clamp + watchdog
  ---------------------------------------------------------------------------
  parser : process (clk)
    variable v : signed(15 downto 0);
    variable w : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      ref_valid_i  <= '0';
      bad_packet_i <= '0';

      if rst = '1' then
        pstate    <= P_HDR;
        bt_cnt    <= 0;
        wd_cnt    <= WATCHDOG_CYCLES;
        ref_i     <= (others => '0');
        kp_i      <= to_unsigned(KP_INIT, 16);
        ki_i      <= to_unsigned(KI_INIT, 16);
        link_ok_i <= '0';
      else

        -- watchdog: force the reference to 0 when no valid packet has arrived in time
        if wd_cnt >= WATCHDOG_CYCLES then
          ref_i     <= (others => '0');
          link_ok_i <= '0';
        else
          wd_cnt <= wd_cnt + 1;
        end if;

        -- inter-byte timeout: abandon a half-received packet
        if pstate /= P_HDR then
          if bt_cnt = BYTE_TIMEOUT_CYCLES then
            pstate       <= P_HDR;
            bt_cnt       <= 0;
            bad_packet_i <= '1';
          else
            bt_cnt <= bt_cnt + 1;
          end if;
        else
          bt_cnt <= 0;
        end if;

        -- byte handling (later assignments override the ones above)
        if rx_err = '1' then
          pstate       <= P_HDR;
          bad_packet_i <= '1';
        elsif rx_valid = '1' then
          bt_cnt <= 0;
          case pstate is

            when P_HDR =>
              if rx_data = HDR_CMD then
                pstate <= P_CMD;
              end if;                         -- anything else: ignore, keep hunting for header

            when P_CMD =>
              cmd_b  <= rx_data;
              pstate <= P_HI;

            when P_HI =>
              hi_b   <= rx_data;
              pstate <= P_LO;

            when P_LO =>
              lo_b   <= rx_data;
              pstate <= P_CK;

            when P_CK =>
              pstate <= P_HDR;
              if rx_data = (HDR_CMD xor cmd_b xor hi_b xor lo_b) then
                w := hi_b & lo_b;
                if cmd_b = CMD_REF then
                  v := signed(w);
                  if v > to_signed(MAX_FREQ, 16) then
                    ref_i <= to_signed(MAX_FREQ, 16);
                  elsif v < to_signed(-MAX_FREQ, 16) then
                    ref_i <= to_signed(-MAX_FREQ, 16);
                  else
                    ref_i <= v;
                  end if;
                  ref_valid_i <= '1';
                  wd_cnt      <= 0;
                  link_ok_i   <= '1';
                elsif cmd_b = CMD_KP then
                  kp_i      <= unsigned(w);
                  wd_cnt    <= 0;
                  link_ok_i <= '1';
                elsif cmd_b = CMD_KI then
                  ki_i      <= unsigned(w);
                  wd_cnt    <= 0;
                  link_ok_i <= '1';
                else
                  bad_packet_i <= '1';        -- valid checksum but unknown command
                end if;
              else
                bad_packet_i <= '1';          -- checksum error
              end if;

          end case;
        end if;

      end if;
    end if;
  end process parser;

  ---------------------------------------------------------------------------
  -- Telemetry sender: every TELEMETRY_CYCLES send speed, Kp and Ki to the Arduino
  ---------------------------------------------------------------------------
  replier : process (clk)
    variable id  : std_logic_vector(7 downto 0);
    variable val : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      tx_start <= '0';

      if tele_cnt = TELEMETRY_CYCLES - 1 then
        tele_cnt  <= 0;
        tele_pend <= '1';
      else
        tele_cnt <= tele_cnt + 1;
      end if;

      case tstate is

        when T_IDLE =>
          if tele_pend = '1' then
            tele_pend <= '0';
            frame_idx <= 0;
            tstate    <= T_BUILD;
          end if;

        when T_BUILD =>
          -- values are captured here, so all bytes of one frame belong together
          case frame_idx is
            when 0      => id := ID_SPEED; val := std_logic_vector(meas_freq);
            when 1      => id := ID_KP;    val := std_logic_vector(kp_i);
            when others => id := ID_KI;    val := std_logic_vector(ki_i);
          end case;
          rep(0) <= HDR_RPL;
          rep(1) <= id;
          rep(2) <= val(15 downto 8);
          rep(3) <= val(7 downto 0);
          rep(4) <= HDR_RPL xor id xor val(15 downto 8) xor val(7 downto 0);
          tx_idx <= 0;
          tstate <= T_LOAD;

        when T_LOAD =>
          tx_data  <= rep(tx_idx);
          tx_start <= '1';
          tstate   <= T_WAIT_BUSY;

        when T_WAIT_BUSY =>                  -- wait until uart_tx has accepted the byte
          if tx_busy = '1' then
            tstate <= T_WAIT_DONE;
          end if;

        when T_WAIT_DONE =>                  -- wait until the byte has been sent
          if tx_busy = '0' then
            if tx_idx = 4 then
              if frame_idx = 2 then
                tstate <= T_IDLE;
              else
                frame_idx <= frame_idx + 1;
                tstate    <= T_BUILD;
              end if;
            else
              tx_idx <= tx_idx + 1;
              tstate <= T_LOAD;
            end if;
          end if;

      end case;
    end if;
  end process replier;

end architecture rtl;
