----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/24/2026 01:09:29 PM
-- Design Name: 
-- Module Name: main - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity main is
    Port ( increment : in bit_vector (3 downto 0);
           clk       : in std_ulogic;
           output    : out bit);
end main;

architecture Behavioral of main is
    component fullAdder is
        Port ( a, b, c_in : in bit;
               sum, c_out : out bit);
    end component;
    component in_out_store is
        Port ( i   : in bit;
               clk : in std_ulogic;
               o   : out bit);
    end component;
    signal r, i, c : bit_vector (3 downto 0);
begin
    b1:fullAdder port map (a => increment(0), b => i(0), c_in => '0', sum => r(0), c_out => c(0));
    b2:fullAdder port map (a => increment(1), b => i(1), c_in => c(0), sum => r(1), c_out => c(1));
    b3:fullAdder port map (a => increment(2), b => i(2), c_in => c(1), sum => r(2), c_out => c(2));
    b4:fullAdder port map (a => increment(3), b => i(3), c_in => c(2), sum => r(3), c_out => c(3));
    
    s1:in_out_store port map (i => r(0), clk => clk, o => i(0));
    s2:in_out_store port map (i => r(1), clk => clk, o => i(1));
    s3:in_out_store port map (i => r(2), clk => clk, o => i(2));
    s4:in_out_store port map (i => r(3), clk => clk, o => i(3));
    
    s_out:in_out_store port map (i => c(3), clk => clk, o => output);
end Behavioral;
