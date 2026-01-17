----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.01.2026 20:21:15
-- Design Name: 
-- Module Name: CLoop_AXI_MUX - Behavioral
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

entity CLoop_AXI_MUX is
    Port ( CLK, RST : in STD_LOGIC;
           MUXsensor : in STD_LOGIC_VECTOR (3 downto 0); -- 16 int
           XADC_rvalid : in STD_LOGIC;
           XADC_addr : in STD_LOGIC_VECTOR (4 downto 0);
           XADC_Reader : in STD_LOGIC_VECTOR (15 downto 0);
           XADC_ready : out STD_LOGIC;
           CLsensorOut : out STD_LOGIC_VECTOR (11 downto 0));
end CLoop_AXI_MUX;

architecture Behavioral of CLoop_AXI_MUX is

 -- Constant address controls -- ADC Channel Select Table : https://docs.amd.com/r/en-US/ug480_7Series_XADC/Control-Registers?section=XREF_59086_ADC_Channel_Select
    constant ADDRT : STD_LOGIC_VECTOR (4 downto 0) := b"00000"; -- on chip sensor                     
    constant ADDR0 : STD_LOGIC_VECTOR (4 downto 0) := b"10001"; -- VAUXP1 
    constant ADDR1 : STD_LOGIC_VECTOR (4 downto 0) := b"11001"; -- VAUXP9
    constant ADDR2 : STD_LOGIC_VECTOR (4 downto 0) := b"10110"; -- VAUXP6
    constant ADDR3 : STD_LOGIC_VECTOR (4 downto 0) := b"11111"; -- VAUXP15 
    constant ADDR4 : STD_LOGIC_VECTOR (4 downto 0) := b"10101"; -- VAUXP5 
    constant ADDR5 : STD_LOGIC_VECTOR (4 downto 0) := b"11101"; -- VAUXP13 
    -- differential channels
    constant ADDR89 : STD_LOGIC_VECTOR (4 downto 0) := b"10000"; -- VAUXP0 
    constant ADDR67 : STD_LOGIC_VECTOR (4 downto 0) := b"11100"; -- VAUXP12 
    constant ADDR1011 :STD_LOGIC_VECTOR(4 downto 0) := b"11000"; -- VAUXP8
    
    signal Maddrs : STD_LOGIC_VECTOR (4 downto 0);
    
    signal CLS, nCLS : STD_LOGIC_VECTOR (11 downto 0); -- output 
    signal CLSv : STD_LOGIC;
    
begin

CLsensorOut <= CLS;
--CLsensor_valid <= CLSv;
XADC_ready <= '1';

Maddrs <= ADDRT when MUXsensor = x"1" else -- 1
          --ADDR0 when MUXsensor = x"1" else -- used as output
          --ADDR1 when MUXsensor = x"0" else -- used as output
          ADDR2  when MUXsensor = x"2" else -- 2
          ADDR3  when MUXsensor = x"3" else -- 3
          ADDR4  when MUXsensor = x"4" else -- 4
          ADDR5  when MUXsensor = x"5" else -- 5
          ADDR67 when MUXsensor = x"6" else -- 6
          ADDR89 when MUXsensor = x"8" else -- 8
          ADDR1011 when MUXsensor=x"a" else -- 10
          ADDRT; 

process(CLK, RST, Maddrs, XADC_rvalid, XADC_addr, XADC_Reader)
begin
    if rising_edge(CLK) then
        if RST = '0' then 
            nCLS <= x"000";
            CLSv <= '0';
        elsif XADC_addr = Maddrs AND XADC_rvalid = '1' then 
            nCLS <= XADC_Reader(15 downto 4);
            CLSv <= '1';
        else 
            nCLS <= CLS;
        end if;
    end if;
    CLS <= nCLS;
end process;

end Behavioral;
