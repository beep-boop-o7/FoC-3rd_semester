----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/13/2026 01:09:33 PM
-- Design Name: 
-- Module Name: out_downscale - Behavioral
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

entity out_downscale is
    Port ( input  : in bit;
           clk    : in std_ulogic;
           output : out bit);
end out_downscale;

architecture Behavioral of out_downscale is
    component in_out_store is
        Port ( i   : in bit;
               clk : in std_ulogic;
               o   : out bit);
    end component;
    component half_adder is
        Port ( a, b : in bit;
         sum, c_out : out bit);
    end component;
    signal r, i : bit_vector (4 downto 0);
    signal c : bit_vector (3 downto 0);
    signal x : bit;
begin
    x <= input xor i(4);
    
    b1:half_adder port map (a => x, b => i(0), sum => r(0), c_out => c(0));
    b2:half_adder port map (a => c(0), b => i(1), sum => r(1), c_out => c(1));
    b3:half_adder port map (a => c(1), b => i(2), sum => r(2), c_out => c(2));
    b4:half_adder port map (a => c(2), b => i(3), sum => r(3), c_out => c(3));
    r(4) <= c(3) xor i(4);
    
    s1:in_out_store port map (i => r(0), clk => clk, o => i(0));
    s2:in_out_store port map (i => r(1), clk => clk, o => i(1));
    s3:in_out_store port map (i => r(2), clk => clk, o => i(2));
    s4:in_out_store port map (i => r(3), clk => clk, o => i(3));
    s5:in_out_store port map (i => r(4), clk => clk, o => i(4));

    output <= r(4);
    
end Behavioral;
