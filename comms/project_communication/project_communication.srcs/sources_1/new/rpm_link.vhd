-- rpm_link.vhd
-- Arduino -> FPGA : 0xA5, CMD, DATA_hi, DATA_lo, checksum
-- FPGA    -> Arduino : 0x5A, FREQ_hi, FREQ_lo, checksum
--
-- checksum = header XOR cmd XOR hi XOR lo
--
-- CMD_REF = 0x01
-- CMD_KP  = 0x02
-- CMD_KI  = 0x03
-- Safety behaviour:
--   * A reference is only accepted after a correct header AND checksum.
--   * The reference is clamped to +/- MAX_FREQ.
--   * If no valid packet arrives within WATCHDOG_CYCLES, ref_rpm is forced to 0
--     (2_400_000 cycles = 200 ms at 12 MHz). It also starts at 0 after power-up.
--   * If a packet stalls half-way (lost byte), the parser resynchronises after BYTE_TIMEOUT_CYCLES.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rpm_link is
  generic (
    CLKS_PER_BIT         : positive := 104;        -- 12 MHz / 115200
    WATCHDOG_CYCLES      : positive := 2_400_000;  -- 200 ms @ 12 MHz
    BYTE_TIMEOUT_CYCLES  : positive := 24_000;     -- 2 ms @ 12 MHz
    MAX_RPM              : positive := 2000        -- PLACEHOLDER: set to your safe maximum
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;                  -- synchronous, active high
    uart_rx_pin  : in  std_logic;                  -- from Arduino TX1 (through level shifter)
    uart_tx_pin  : out std_logic;                  -- to Arduino RX1
    meas_freq    : in  signed(15 downto 0);        -- measured speed from the FOC logic
    ref_freq     : out signed(15 downto 0);        -- reference speed to the FOC logic
    ref_valid    : out std_logic;                  -- 1-clock pulse for every accepted packet
    link_ok      : out std_logic;                  -- '1' while the watchdog has not expired
    bad_packet   : out std_logic                   -- 1-clock pulse: checksum error, framing error or timeout
  );
end entity rpm_link;

architecture rtl of rpm_link is

  constant HDR_CMD : std_logic_vector(7 downto 0) := x"A5";
  constant HDR_RPL : std_logic_vector(7 downto 0) := x"5A";

  -- UART blocks
  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid : std_logic;
  signal rx_err   : std_logic;
  signal tx_start : std_logic := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy  : std_logic;
  
  signal cmd_b : std_logic_vector(7 downto 0);

  -- parser
  type pstate_t is (P_HDR, P_CMD, P_HI, P_LO, P_CK);
  signal pstate    : pstate_t := P_HDR;
  signal hi_b, lo_b : std_logic_vector(7 downto 0) := (others => '0');
  signal bt_cnt    : integer range 0 to BYTE_TIMEOUT_CYCLES := 0;
  signal wd_cnt    : integer range 0 to WATCHDOG_CYCLES := WATCHDOG_CYCLES;  -- starts expired
  signal ref_freq_i     : signed(15 downto 0) := (others => '0');
  signal kp_i : signed(15 downto 0) := (others => '0');
  signal ki_i : signed(15 downto 0) := (others => '0');
  signal link_ok_i : std_logic := '0';
  signal ref_valid_i  : std_logic := '0';
  signal bad_packet_i : std_logic := '0';
  signal send_req  : std_logic := '0';

  -- reply sender
  type byte_array_t is array (0 to 3) of std_logic_vector(7 downto 0);
  type tstate_t is (T_IDLE, T_LOAD, T_WAIT_BUSY, T_WAIT_DONE);
  signal tstate  : tstate_t := T_IDLE;
  signal rep     : byte_array_t := (others => (others => '0'));
  signal tx_idx  : integer range 0 to 3 := 0;

begin

  ref_freq    <= ref_freq_i;
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
      send_req     <= '0';

      if rst = '1' then
        pstate    <= P_HDR;
        bt_cnt    <= 0;
        wd_cnt    <= WATCHDOG_CYCLES;
        ref_freq_i     <= (others => '0');
        link_ok_i <= '0';
      else

        -- watchdog: force the reference to 0 when no valid packet has arrived in time
        if wd_cnt >= WATCHDOG_CYCLES then
          ref_freq_i     <= (others => '0');
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
              cmd_b <= rx_data;
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
    v := signed(w);

    case cmd_b is

      when x"01" =>  -- CMD_REF

        if v > to_signed(MAX_RPM, 16) then
          ref_freq_i <= to_signed(MAX_RPM, 16);

        elsif v < to_signed(-MAX_RPM, 16) then
          ref_freq_i <= to_signed(-MAX_RPM, 16);

        else
          ref_freq_i <= v;
        end if;

        wd_cnt      <= 0;
        link_ok_i   <= '1';
        ref_valid_i <= '1';
        send_req    <= '1';

      when x"02" =>  -- CMD_KP
        kp_i <= v;

                    wd_cnt      <= 0;
                    link_ok_i   <= '1';
                    ref_valid_i <= '1';
                    send_req    <= '1';


      when x"03" =>  -- CMD_KI
        
                    ki_i <= v;

                    wd_cnt      <= 0;
                    link_ok_i   <= '1';
                    ref_valid_i <= '1';
                    send_req    <= '1';

      when others =>
        bad_packet_i <= '1';

    end case;

  else
    bad_packet_i <= '1';
  end if;
          end case;
        end if; --rx valid 

      end if; --rst  
    end if; --rising edge
  end process parser;
  ---------------------------------------------------------------------------
  -- Reply sender: after each accepted command, send the measured speed back
  ---------------------------------------------------------------------------
  replier : process (clk)
  begin
    if rising_edge(clk) then
      tx_start <= '0';

      case tstate is

        when T_IDLE =>
          if send_req = '1' then
            -- snapshot the measured speed so all bytes belong to the same value
            rep(0) <= HDR_RPL;
            rep(1) <= std_logic_vector(meas_freq(15 downto 8));
            rep(2) <= std_logic_vector(meas_freq(7 downto 0));
            rep(3) <= HDR_RPL xor std_logic_vector(meas_freq(15 downto 8))
                               xor std_logic_vector(meas_freq(7 downto 0));
            tx_idx <= 0;
            tstate <= T_LOAD;
          end if;

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
            if tx_idx = 3 then
              tstate <= T_IDLE;
            else
              tx_idx <= tx_idx + 1;
              tstate <= T_LOAD;
            end if;
          end if;

      end case;
    end if;
  end process replier;

end architecture rtl;