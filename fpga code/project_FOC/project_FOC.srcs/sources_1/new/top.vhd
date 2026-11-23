library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        clk : in std_logic;
        ea : in std_logic_vector(11 downto 0);  
        eb : in std_logic_vector(11 downto 0);  
        ec : in std_logic_vector(11 downto 0);
        va : out std_logic_vector(11 downto 0);
        vb : out std_logic_vector(11 downto 0);
        vc : out std_logic_vector(11 downto 0)
    
    );
end top;

architecture Behavioral of top is

        signal ia : std_logic_vector(11 downto 0);  
       signal  ib : std_logic_vector(11 downto 0);  
       signal  ic : std_logic_vector(11 downto 0); 
       signal  ialpha : std_logic_vector(11 downto 0);
        signal ibeta  : std_logic_vector(11 downto 0);

    constant INV_SQRT3 : signed(15 downto 0)
        := to_signed(18919,16);
        
    constant SQRT3_DIV2 : signed(15 downto 0)
    := to_signed(28378,16); -- 0.866 * 32768

    signal sinCosTheta : std_logic_vector(31 downto 0);
    signal theta : std_logic_vector(15 downto 0);
    signal ealpha : std_logic_vector(11 downto 0);
    signal ebeta  : std_logic_vector(11 downto 0);
    signal cordic_valid : std_logic;
    signal id : std_logic_vector(11 downto 0);
    signal iq : std_logic_vector(11 downto 0);
    signal sin_s : signed(15 downto 0);
    signal cos_s : signed(15 downto 0);
    signal ib_ic : signed(12 downto 0);
    signal id_temp : signed(28 downto 0);
    signal iq_temp : signed(28 downto 0);
    
    --debugging som blev et fix
    type delay_array is array (0 to 41) of signed(11 downto 0);

    signal alpha_delay : delay_array;
    signal beta_delay  : delay_array;
    --debugging
    
    signal vd : std_logic_vector(11 downto 0);
    signal vq : std_logic_vector(11 downto 0);
    
    signal valpha_temp : signed(28 downto 0);
    signal vbeta_temp : signed(28 downto 0);
    signal valpha : std_logic_vector(11 downto 0);
    signal vbeta  : std_logic_vector(11 downto 0);
    
    signal vb_temp : signed(28 downto 0);
    signal vc_temp : signed(28 downto 0);
    
    

begin

--debugging
process(clk)
begin
    if rising_edge(clk) then

        alpha_delay(0) <= signed(ialpha);
        beta_delay(0)  <= signed(ibeta);

        for i in 1 to 41 loop
            alpha_delay(i) <= alpha_delay(i-1);
            beta_delay(i)  <= beta_delay(i-1);
        end loop;

    end if;
end process;


--debugging

  ia <= std_logic_vector(signed(ea));
  ib <= std_logic_vector(signed(eb));
  ic <= std_logic_vector(signed(ec));
    
    ialpha <= std_logic_vector(signed(ia));
   

        ib_ic <= resize(signed(ib),13) - resize(signed(ic),13);
    
    ibeta <= std_logic_vector(resize(shift_right(ib_ic * INV_SQRT3, 15), 12));
    
    
    ealpha <= ialpha;
    
    ebeta <= ibeta;
    
    
    
    cordic_tan : entity work.cordic_1
    port map(
        aclk => clk,
        s_axis_cartesian_tvalid => '1',
            s_axis_cartesian_tdata => std_logic_vector(resize(signed(ebeta), 16)) & std_logic_vector(resize(signed(ealpha), 16)),
        m_axis_dout_tvalid => open,
        m_axis_dout_tdata => theta
);

    cordic_a : entity work.cordic_0
    port map(--SKIFT muligved her
        aclk => clk,--SKIFT muligved her
        s_axis_phase_tvalid => '1',--SKIFT muligved her
        s_axis_phase_tdata => theta,--SKIFT muligved her
        m_axis_dout_tvalid => open,--SKIFT muligved her
        m_axis_dout_tdata => sinCosTheta--SKIFT muligved her
    );
    

cos_s <= signed(sinCosTheta(15 downto 0));
sin_s <= signed(sinCosTheta(31 downto 16));
    
    
    id_temp <=
      resize(cos_s * alpha_delay(39),29)--debugging somblev til fiks (delay på 39 clk)
    + resize(sin_s * beta_delay(39),29);--debugging

iq_temp <=
      resize(cos_s * beta_delay(39),29) --debugging
    - resize(sin_s * alpha_delay(39),29);--debugging
    
    
    id <= std_logic_vector(
      resize(
      shift_right(id_temp,14),
      12));

    iq <= std_logic_vector(
      resize(
      shift_right(iq_temp,14),
      12));
      
      --HER STARTER INVERSEINGEEINGEN --så deett-
      vd<=id;--PI
      vq<=iq;--PI
      
      valpha_temp <=
      resize(cos_s * signed(vd),29)
    - resize(sin_s * signed(vq),29);
    
    vbeta_temp <=
      resize(sin_s * signed(vd),29)
    + resize(cos_s * signed(vq),29);
    
    valpha <= std_logic_vector(
      resize(
      shift_right(valpha_temp,14),
      12));

    vbeta <= std_logic_vector(
      resize(
      shift_right(vbeta_temp,14),
      12));
      
      va<=valpha;
      
   vb_temp <=
      resize((-signed(valpha)) * to_signed(16384,16),29)
    + resize(signed(vbeta) * SQRT3_DIV2,29);

vc_temp <=
      resize((-signed(valpha)) * to_signed(16384,16),29)
    - resize(signed(vbeta) * SQRT3_DIV2,29);
    
vb <= std_logic_vector(
      resize(
      shift_right(vb_temp,15),
      12));

vc <= std_logic_vector(
      resize(
      shift_right(vc_temp,15),
      12));
      
    

end Behavioral;