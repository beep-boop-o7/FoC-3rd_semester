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
    Port ( increment_in : in bit_vector (11 downto 0);
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
    component out_downscale is
        Port ( input  : in bit;
               clk    : in std_ulogic;
               output : out bit);
    end component;
    signal r, i, c : bit_vector (11 downto 0);
    signal increment : bit_vector (11 downto 0);
begin


    increment(10 down to 0)<=increment_in(10 down to 0);
    increment(11)<=not increment_in(11);



    b1:fullAdder port map (a => increment(0), b => i(0), c_in => '0', sum => r(0), c_out => c(0));
    b2:fullAdder port map (a => increment(1), b => i(1), c_in => c(0), sum => r(1), c_out => c(1));
    b3:fullAdder port map (a => increment(2), b => i(2), c_in => c(1), sum => r(2), c_out => c(2));
    b4:fullAdder port map (a => increment(3), b => i(3), c_in => c(2), sum => r(3), c_out => c(3));
    b5:fullAdder port map (a => increment(4), b => i(4), c_in => c(3), sum => r(4), c_out => c(4));
    b6:fullAdder port map (a => increment(5), b => i(5), c_in => c(4), sum => r(5), c_out => c(5));
    b7:fullAdder port map (a => increment(6), b => i(6), c_in => c(5), sum => r(6), c_out => c(6));
    b8:fullAdder port map (a => increment(7), b => i(7), c_in => c(6), sum => r(7), c_out => c(7));
    b9:fullAdder port map (a => increment(8), b => i(8), c_in => c(7), sum => r(8), c_out => c(8));
    b10:fullAdder port map (a => increment(9), b => i(9), c_in => c(8), sum => r(9), c_out => c(9));
    b11:fullAdder port map (a => increment(10), b => i(10), c_in => c(9), sum => r(10), c_out => c(10));
    b12:fullAdder port map (a => increment(11), b => i(11), c_in => c(10), sum => r(11), c_out => c(11));
    
   
    s1:in_out_store port map (i => r(0),  clk => clk, o => i(0));
s2:in_out_store port map (i => r(1),  clk => clk, o => i(1));
s3:in_out_store port map (i => r(2),  clk => clk, o => i(2));
s4:in_out_store port map (i => r(3),  clk => clk, o => i(3));
s5:in_out_store port map (i => r(4),  clk => clk, o => i(4));
s6:in_out_store port map (i => r(5),  clk => clk, o => i(5));
s7:in_out_store port map (i => r(6),  clk => clk, o => i(6));
s8:in_out_store port map (i => r(7),  clk => clk, o => i(7));
s9:in_out_store port map (i => r(8),  clk => clk, o => i(8));
s10:in_out_store port map (i => r(9),  clk => clk, o => i(9));
s11:in_out_store port map (i => r(10), clk => clk, o => i(10));
s12:in_out_store port map (i => r(11), clk => clk, o => i(11));
    
    s_out:out_downscale port map (input => c(11), clk => clk, output => output);
end Behavioral;
