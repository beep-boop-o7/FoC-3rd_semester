
----------------------------------------------------------------------------------
-- Design Name: Hybrid_Observer
-- Module Name: Hybrid_Observer
--
-- Description:
-- Hybrid sensorless rotor position estimator.
--
-- HFI is used at low speeds.
-- Adaptive STA-SMO is used at higher speeds.
-- A transition state blends the estimated rotor angles.
--
-- Mode encoding:
--   00 = HFI
--   01 = HFI -> SMO transition
--   10 = SMO
--   11 = SMO -> HFI transition
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Hybrid_Observer is

    generic (
        -- Speed threshold for switching HFI -> SMO
        HFI_TO_SMO_THRESHOLD : integer := 10000;

        -- Speed threshold for switching SMO -> HFI
        SMO_TO_HFI_THRESHOLD : integer := 8000;

        -- Number of FPGA clock cycles for transition
        TRANSITION_CYCLES : integer := 1000             -- The three varibles can be and should prob be chnaged
    );

    port (
        clk   : in std_logic;
        reset : in std_logic;


        -- HFI estimator


        theta_hfi : in unsigned(7 downto 0);
        omega_hfi : in signed(31 downto 0);
        hfi_valid : in std_logic;


        -- Adaptive STA-SMO estimator


        theta_smo : in unsigned(15 downto 0);
        omega_smo : in signed(31 downto 0);
        smo_valid : in std_logic;


        -- Selected estimator output


        theta_est_hy : out unsigned(7 downto 0);
        omega_est : out signed(31 downto 0);


        -- Debug


        observer_mode : out std_logic_vector(1 downto 0);
        
        
        observer_valid : out std_logic
    );

end Hybrid_Observer;


architecture Behavioral of Hybrid_Observer is


    -- State definition


    type state_type is (HFI_MODE, HFI_TO_SMO,SMO_MODE,SMO_TO_HFI);


    signal state : state_type := HFI_MODE;


    -- Transition counter
 

    signal transition_count : integer range 0 to TRANSITION_CYCLES := 0;

    function blend_angle (
        source_angle : unsigned(7 downto 0);
        target_angle : unsigned(7 downto 0);
        weight       : integer
    ) return unsigned is

        variable angle_difference : signed(7 downto 0);
        variable correction       : integer;
        variable result_angle     : integer;
        
        

    begin


        -- Circular angle difference
        angle_difference := signed(target_angle - source_angle);

        -- Apply transition weight
        correction := (to_integer(angle_difference) * weight) / 255;
            
        -- Add correction to source angle
        result_angle := to_integer(source_angle) + correction;

        -- Wrap angle to 0...255
        result_angle := result_angle mod 256;

        return to_unsigned(result_angle, 8);

    end function;

signal theta_est : unsigned(15 downto 0);
begin
    theta_est_hy <= theta_est(15 downto 8);


    -- Hybrid observer state machine


    process(clk)

    begin

        if rising_edge(clk) then

            if reset = '1' then

                state <= HFI_MODE;
                transition_count <= 0;

            else

                case state is


                    -- HFI MODE

                    when HFI_MODE =>

                        transition_count <= 0;

                        -- If HFI is unavailable but SMO is valid, then fall back to SMO.

                        if hfi_valid = '0' and smo_valid = '1' then

                            state <= SMO_MODE;

                        -- Switch toward SMO at higher speed.
                        elsif hfi_valid = '1' and smo_valid = '1' then

                            if omega_hfi >= to_signed(HFI_TO_SMO_THRESHOLD, 32)
                               or
                               omega_hfi <= -to_signed(HFI_TO_SMO_THRESHOLD, 32)
                            then

                                state <= HFI_TO_SMO;
                                transition_count <= 0;

                            end if;

                        end if;


                    -- HFI -> SMO TRANSITION


                    when HFI_TO_SMO =>

                        if smo_valid = '0' then

                            state <= HFI_MODE;
                            transition_count <= 0;

                        elsif hfi_valid = '0' then

                            -- HFI is no longer valid.  Use SMO now

                            state <= SMO_MODE;
                            transition_count <= 0;

                        else

                            if transition_count <  TRANSITION_CYCLES then

                                transition_count <= transition_count + 1;

                            else

                                state <= SMO_MODE;
                                transition_count <= 0;

                            end if;

                        end if;


                    -- SMO MODE


                    when SMO_MODE =>

                        transition_count <= 0;

                        -- If SMO becomes unavailable but HFI is valid, fall back to HFI.

                        if smo_valid = '0' and hfi_valid = '1' then

                            state <= HFI_MODE;

                        -- Switch toward HFI at lower speed.
                        elsif smo_valid = '1' and hfi_valid = '1' then

                            if omega_smo <= to_signed(SMO_TO_HFI_THRESHOLD, 32) and omega_smo >= -to_signed(SMO_TO_HFI_THRESHOLD, 32)
                           
                            then

                                state <= SMO_TO_HFI;
                                transition_count <= 0;

                            end if;

                        end if;


 
                    -- SMO -> HFI TRANSITION


                    when SMO_TO_HFI =>

                        if hfi_valid = '0' then

                            -- HFI is not ready.Remain with SMO.

                            state <= SMO_MODE;
                            transition_count <= 0;

                        elsif smo_valid = '0' then

                            -- SMO is no longer valid. Use HFI now
                            state <= HFI_MODE;
                            transition_count <= 0;

                        else

                            if transition_count < TRANSITION_CYCLES then
                              
                                transition_count <= transition_count + 1;

                            else

                                state <= HFI_MODE;
                                transition_count <= 0;

                            end if;

                        end if;


                end case;

            end if;

        end if;

    end process;



    -- Output selection


    process(state, transition_count,
        theta_hfi, theta_smo,
        omega_hfi, omega_smo,
        hfi_valid, smo_valid)

        variable weight : integer range 0 to 255;

    begin

        weight := 0;

        case state is


            -- HFI selected


            when HFI_MODE =>

                theta_est <= theta_hfi;
                omega_est <= omega_hfi;

                observer_mode <= "00";
                observer_valid <= hfi_valid;


            -- Transition from HFI to SMO


            when HFI_TO_SMO =>

                if TRANSITION_CYCLES > 0 then

                    weight := (transition_count * 255) / TRANSITION_CYCLES;
                else
                    weight := 255;
                end if;
                theta_est <= blend_angle(theta_hfi,theta_smo, weight);

                -- Keep HFI speed during the angle transition
                omega_est <= omega_hfi;

                observer_mode <= "01";
                observer_valid <= hfi_valid and smo_valid;
                

            -- SMO selected


            when SMO_MODE =>

                theta_est <= theta_smo;
                omega_est <= omega_smo;

                observer_mode <= "10";
                observer_valid <= smo_valid;

 
            -- Transition from SMO to HFI
      

            when SMO_TO_HFI =>

                if TRANSITION_CYCLES > 0 then

                    weight := (transition_count * 255)/ TRANSITION_CYCLES;
                else
                    weight := 255;

                end if;

                theta_est <= blend_angle( theta_smo, theta_hfi, weight );

                -- Keep SMO speed during the angle transition
                omega_est <= omega_smo;

                observer_mode <= "11";
                observer_valid <= smo_valid and hfi_valid;

        end case;

    end process;


end Behavioral;
