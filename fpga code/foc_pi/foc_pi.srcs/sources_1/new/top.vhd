library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        sysclk : in  std_logic;
        led    : out std_logic_vector(1 downto 0)
    );
end top;

architecture rtl of top is

    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;
            clk_out1 : out std_logic;
            locked   : out std_logic
        );
    end component;

    -- clock and reset
    signal clk_100  : std_logic;
    signal locked   : std_logic;
    signal lock_s1  : std_logic := '0';
    signal lock_s2  : std_logic := '0';
    signal rst      : std_logic;

    -- LED test counter
    signal counter  : unsigned(26 downto 0) := (others => '0');

    -- control timing
    signal current_tick : std_logic := '0';
    signal speed_tick   : std_logic := '0';
    signal tick_cnt     : integer range 0 to 4999 := 0;   -- 100 MHz / 5000 = 20 kHz
    signal spd_cnt      : integer range 0 to 19   := 0;   -- 20 kHz / 20   = 1 kHz

    -- FOC inputs and outputs
    constant SPEED_REF  : signed(15 downto 0) := to_signed(8192, 16);   -- 0.25 of full scale
    signal speed_meas, iq_meas, id_meas : signed(15 downto 0) := (others => '0');
    signal vq, vd                       : signed(15 downto 0);

begin

    u_clk : clk_wiz_0
        port map (
            clk_in1  => sysclk,
            clk_out1 => clk_100,
            locked   => locked
        );

    -- two-flop synchroniser for the asynchronous locked signal
    process(clk_100)
    begin
        if rising_edge(clk_100) then
            lock_s1 <= locked;
            lock_s2 <= lock_s1;
        end if;
    end process;

    rst <= not lock_s2;

    -- LED test counter
    process(clk_100)
    begin
        if rising_edge(clk_100) then
            if rst = '0' then
                counter <= counter + 1;
            else
                counter <= (others => '0');
            end if;
        end if;
    end process;

    led(0) <= counter(26);
    led(1) <= counter(25);

    -- tick generator
    process(clk_100)
    begin
        if rising_edge(clk_100) then
            current_tick <= '0';
            speed_tick   <= '0';
            if rst = '1' then
                tick_cnt <= 0;
                spd_cnt  <= 0;
            elsif tick_cnt = 4999 then
                tick_cnt     <= 0;
                current_tick <= '1';
                if spd_cnt = 19 then
                    spd_cnt    <= 0;
                    speed_tick <= '1';
                else
                    spd_cnt <= spd_cnt + 1;
                end if;
            else
                tick_cnt <= tick_cnt + 1;
            end if;
        end if;
    end process;

    -- control algorithm
    u_foc : entity work.foc_core
        port map (
            clk          => clk_100,
            rst          => rst,
            current_tick => current_tick,
            speed_tick   => speed_tick,
            speed_ref    => SPEED_REF,
            speed_meas   => speed_meas,
            iq_meas      => iq_meas,
            id_meas      => id_meas,
            vq           => vq,
            vd           => vd
        );

end rtl;