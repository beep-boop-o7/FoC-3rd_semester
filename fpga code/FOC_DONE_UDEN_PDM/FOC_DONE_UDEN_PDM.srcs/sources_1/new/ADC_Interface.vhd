library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ADC_Interface is
    port (
        sysclk : in std_logic;
        reset  : in std_logic;

        xa_p : in std_logic;
        xa_n : in std_logic;

        adc_data  : out std_logic_vector(11 downto 0);
        adc_valid : out std_logic
    );
end entity;

architecture rtl of ADC_Interface is

    signal eoc      : std_logic;
    signal drdy     : std_logic;
    signal drp_data : std_logic_vector(15 downto 0);

    signal adc_value     : std_logic_vector(11 downto 0) := (others => '0');
    signal adc_valid_reg : std_logic := '0';

    -- 1. COMPONENT declaration stays BEFORE 'begin'
    COMPONENT xadc_wiz_0
      PORT (
        di_in               : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        daddr_in            : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        den_in              : IN STD_LOGIC;
        dwe_in              : IN STD_LOGIC;
        drdy_out            : OUT STD_LOGIC;
        do_out              : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        dclk_in             : IN STD_LOGIC;
        reset_in            : IN STD_LOGIC;
        vp_in               : IN STD_LOGIC;
        vn_in               : IN STD_LOGIC;
        vauxp4              : IN STD_LOGIC;
        vauxn4              : IN STD_LOGIC;
        user_temp_alarm_out : OUT STD_LOGIC;
        vccint_alarm_out    : OUT STD_LOGIC;
        vccaux_alarm_out    : OUT STD_LOGIC;
        ot_out              : OUT STD_LOGIC;
        channel_out         : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        eoc_out             : OUT STD_LOGIC;
        alarm_out           : OUT STD_LOGIC;
        eos_out             : OUT STD_LOGIC;
        busy_out            : OUT STD_LOGIC 
      );
    END COMPONENT;

begin

    process(sysclk)
    begin
        if rising_edge(sysclk) then
            adc_valid_reg <= '0';

            if reset = '1' then
                adc_value <= (others => '0');
            else
                -- Capture the XADC result when data is ready.
                if drdy = '1' then
                    adc_value     <= drp_data(15 downto 4);
                    adc_valid_reg <= '1';
                end if;
            end if;
        end if;
    end process;

    adc_data  <= adc_value;
    adc_valid <= adc_valid_reg;

    --------------------------------------------------------------------------
    -- 2. XADC Wizard Instantiation stays AFTER 'begin'
    --------------------------------------------------------------------------
    xadc_inst : xadc_wiz_0
        port map (
            daddr_in            => "0010100",  -- VAUX4 result register
            den_in              => eoc,
            di_in               => (others => '0'),
            dwe_in              => '0',
            do_out              => drp_data,
            drdy_out            => drdy,
            dclk_in             => sysclk,
            reset_in            => reset,
            eoc_out             => eoc,
            vp_in               => '0',
            vn_in               => '0',
            vauxp4              => xa_p,
            vauxn4              => xa_n,
            user_temp_alarm_out => open,
            vccint_alarm_out    => open,
            vccaux_alarm_out    => open,
            ot_out              => open,
            channel_out         => open,
            alarm_out           => open,
            eos_out             => open,
            busy_out            => open
        );

end architecture;
