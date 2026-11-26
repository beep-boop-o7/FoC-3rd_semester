library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rpm_link is
end entity;

architecture sim of tb_rpm_link is

    constant CLK_PERIOD : time := 83.333 ns; -- 12 MHz
    constant BIT_TIME   : time := 8.680 us;  -- 115200 baud

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';

    signal uart_rx_pin : std_logic := '1';
    signal uart_tx_pin : std_logic;

    signal meas_freq   : signed(15 downto 0) := to_signed(150,16);
    signal ref_freq    : signed(15 downto 0);

    signal ref_valid   : std_logic;
    signal link_ok     : std_logic;
    signal bad_packet  : std_logic;

    --------------------------------------------------------------------------
    -- UART transmit one byte into DUT RX
    --------------------------------------------------------------------------
    procedure uart_send_byte(
        signal tx : out std_logic;
        data      : std_logic_vector(7 downto 0)
    ) is
    begin

        -- start bit
        tx <= '0';
        wait for BIT_TIME;

        -- data bits (LSB first)
        for i in 0 to 7 loop
            tx <= data(i);
            wait for BIT_TIME;
        end loop;

        -- stop bit
        tx <= '1';
        wait for BIT_TIME;

    end procedure;

begin

    --------------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------------
    uut : entity work.rpm_link
        generic map(
            CLKS_PER_BIT        => 104,
            WATCHDOG_CYCLES     => 2400000,
            BYTE_TIMEOUT_CYCLES => 24000,
            MAX_RPM             => 2000
        )
        port map(
            clk         => clk,
            rst         => rst,
            uart_rx_pin => uart_rx_pin,
            uart_tx_pin => uart_tx_pin,
            meas_freq   => meas_freq,
            ref_freq    => ref_freq,
            ref_valid   => ref_valid,
            link_ok     => link_ok,
            bad_packet  => bad_packet
        );

    --------------------------------------------------------------------------
    -- 12 MHz clock
    --------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    --------------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------------
    stim : process
    begin

        wait for 1 ms;

        ----------------------------------------------------------------------
        -- Send:
        -- A5 01 00 96 32
        --
        -- CMD_REF
        -- FREQ = 150 Hz
        ----------------------------------------------------------------------

        uart_send_byte(uart_rx_pin, x"A5");
        uart_send_byte(uart_rx_pin, x"01");
        uart_send_byte(uart_rx_pin, x"00");
        uart_send_byte(uart_rx_pin, x"96");
        uart_send_byte(uart_rx_pin, x"32");

        wait for 20 ms;

        ----------------------------------------------------------------------
        -- Check results
        ----------------------------------------------------------------------

        assert ref_freq = to_signed(150,16)
            report "REF_FREQ not updated correctly"
            severity error;

        assert link_ok = '1'
            report "LINK_OK not asserted"
            severity error;

        assert bad_packet = '0'
            report "Unexpected bad packet"
            severity error;

        report "TEST PASSED";

        wait;

    end process;

end architecture;