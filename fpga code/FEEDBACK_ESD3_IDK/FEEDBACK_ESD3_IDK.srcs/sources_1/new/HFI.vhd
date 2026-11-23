--HFI

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity HFI is
    generic (
        HALF_PERIOD : integer := 119;
        SHIFT_SCALE : integer := 4
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- Normal FOC d axis voltage reference
        vd_ref_in : in signed(15 downto 0);

        -- Measured motor phase currents
        ia : in signed(15 downto 0);
        ib : in signed(15 downto 0);
        ic : in signed(15 downto 0);

        -- Timing
        clk50k        : out std_logic;
        sample_enable : out std_logic;

        -- Injection signals
        sine_out         : out signed(15 downto 0);
        injection_carrier : out signed(15 downto 0);
        vd_ref_out       : out signed(15 downto 0);

        -- Clarke outputs
        ialpha : out signed(15 downto 0);
        ibeta  : out signed(15 downto 0)
    );
end HFI;

architecture Behavioral of HFI is

    signal sample_count : integer range 0 to 29 := 0;
    signal sample_tick  : std_logic := '0';

    --50khz thing
    signal clock_count : integer range 0 to HALF_PERIOD := 0;
    signal clk50k_reg  : std_logic := '0';

    type carrier_array is array (0 to 7)
        of signed(15 downto 0);

    constant CARRIER_LUT : carrier_array := (
        0 => to_signed(0, 16),
        1 => to_signed(23170, 16),
        2 => to_signed(32767, 16),
        3 => to_signed(23170, 16),
        4 => to_signed(0, 16),
        5 => to_signed(-23170, 16),
        6 => to_signed(-32767, 16),
        7 => to_signed(-23170, 16)
    );

    signal carrier_index : integer range 0 to 7 := 0;

    signal carrier_reg : signed(15 downto 0)
        := (others => '0');

    signal sine_scaled : signed(15 downto 0);

    signal sum_ext : signed(16 downto 0);

    signal beta_sum : signed(17 downto 0);

    constant INV_SQRT3_Q15 : signed(15 downto 0)
        := to_signed(18919, 16);

    signal beta_mult : signed(33 downto 0);
    signal beta_scaled : signed(33 downto 0);

    signal alpha_reg : signed(15 downto 0)
        := (others => '0');

    signal beta_reg : signed(15 downto 0)
        := (others => '0');
        
     --  sample stuff
     signal sample_enable_reg : std_logic := '0';

begin

    --Generate 400 kHz sample enable

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                sample_count <= 0;
                sample_tick <= '0';

                carrier_index <= 0;
                carrier_reg <= (others => '0');

            else

                sample_tick <= '0';

                if sample_count = 29 then

                    sample_count <= 0;
                    sample_tick <= '1';

                    -- Update injection carrier once per sample
                    carrier_reg <= CARRIER_LUT(carrier_index);

                    if carrier_index = 7 then
                        carrier_index <= 0;
                    else
                        carrier_index <= carrier_index + 1;
                    end if;

                else

                    sample_count <= sample_count + 1;

                end if;

            end if;

        end if;
    end process;

    --Generate 50 kHz diagnostic clock

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                clock_count <= 0;
                clk50k_reg <= '0';

            else

                if clock_count = HALF_PERIOD then

                    clock_count <= 0;
                    clk50k_reg <= not clk50k_reg;

                else

                    clock_count <= clock_count + 1;

                end if;

            end if;

        end if;
    end process;

    --Scale injection amplitude, like 1/16 amplitude

    sine_scaled <= shift_right(carrier_reg, SHIFT_SCALE);

    --Add injection to d-axis voltage reference

    sum_ext <= resize(vd_ref_in, 17)+ resize(sine_scaled, 17);            

    process(sum_ext)
    begin

        if sum_ext > to_signed(32767, 17) then

            vd_ref_out <= to_signed(32767, 16);

        elsif sum_ext < to_signed(-32768, 17) then

            vd_ref_out <= to_signed(-32768, 16);

        else

            vd_ref_out <= sum_ext(15 downto 0);

        end if;

    end process;


    --Clarke transformation, remove when final foc

    beta_sum <= resize(ia, 18) + shift_left(resize(ib, 18), 1);

    beta_mult <= beta_sum * INV_SQRT3_Q15;

    beta_scaled <= shift_right(beta_mult, 15);


    --Register Clarke outputs at 400 kHz

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                alpha_reg <= (others => '0');
                beta_reg <= (others => '0');

            elsif sample_tick = '1' then

                alpha_reg <= ia;

                if beta_scaled > to_signed(32767, 34) then

                    beta_reg <= to_signed(32767, 16);

                elsif beta_scaled < to_signed(-32768, 34) then

                    beta_reg <= to_signed(-32768, 16);

                else

                    beta_reg <= beta_scaled(15 downto 0);

                end if;

            end if;

        end if;
    end process;


    -- Delay sample enable until Clarke outputs are available
    
    process(clk)
    begin
        if rising_edge(clk) then
    
            if reset = '1' then
                sample_enable_reg <= '0';
            else
                sample_enable_reg <= sample_tick;
            end if;
    
        end if;
    end process;

    -- Outputs

    sample_enable <= sample_enable_reg;
    clk50k <= clk50k_reg;

    sine_out <= sine_scaled;
    injection_carrier <= carrier_reg;

    ialpha <= alpha_reg;
    ibeta <= beta_reg;

end Behavioral;
