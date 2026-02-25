----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2026 20:15:00
-- Design Name: 
-- Module Name: bram_ctrl_Motor_sim - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity bram_ctrl_Motor_sim is
    Port ( CLKO, RSTO : out STD_LOGIC;
           BrenO, PULSO, DirO : out STD_LOGIC;
           MstateO : out STD_LOGIC_VECTOR (2 downto 0);
           BwenO : out STD_LOGIC_VECTOR (3 downto 0);
           BdinO, BdoutO, BaddrO : out STD_LOGIC_VECTOR (31 downto 0);
           --MC, MS : out STD_LOGIC_VECTOR (31 downto 0);
           RUNaddr, MC0addr, MC1addr : in STD_LOGIC_VECTOR (31 downto 0));
           
end bram_ctrl_Motor_sim;

architecture Behavioral of bram_ctrl_Motor_sim is

component Bram_MemCon is
    Port ( CLK, RST : in STD_LOGIC;
           MS_valid : in STD_LOGIC;
           MS0, MS1, MS2 : in STD_LOGIC_VECTOR (31 downto 0);
           MC_valid : out STD_LOGIC;
           MC0, MC1 : out STD_LOGIC_VECTOR (31 downto 0);
           -- Bram connections
           Ben : out STD_LOGIC;
           Bread : in STD_LOGIC_VECTOR (31 downto 0);
           Bwrite : out STD_LOGIC_VECTOR (31 downto 0);
           Bwe : out STD_LOGIC_VECTOR (3 downto 0);
           Baddr : out STD_LOGIC_VECTOR (31 downto 0));
end component;

component Bram_Motorstates_Ctrl is
    Port ( CLK, RST     : in STD_LOGIC;
           MCinV        : in STD_LOGIC;
           DIR_REF      : in STD_LOGIC;
           --RUNSin, RTYPE      : in STD_LOGIC;
           BTNUP, BTNDOWN, BTNRST : in STD_LOGIC;
           CLsens      : in STD_LOGIC_VECTOR (11 downto 0); -- from ADC, decided by Clossed loop input
           MCin0, MCin1 : in STD_LOGIC_VECTOR (31 downto 0);-- 1 Steptype, 1 RUNSig, 21 PosNext, || 20 FreqTime, 21 bit free
           
           StateColor     : out STD_LOGIC_VECTOR (2 downto 0);
           PULS, DirOut : out STD_LOGIC; -- Motor Utput control
           MS_valid     : out STD_LOGIC; -- motor in state RUNtest or BTNSRUN
           StepGOALO, StepCURO, CLOOPino    : out STD_LOGIC_VECTOR (31 downto 0)); -- DIR ADD
end component;


    constant UPD : STD_LOGIC := '0';
    constant DOWND : STD_LOGIC := NOT UPD; 
    constant NJC : integer :=   4; -- new JUP command
    constant RaS : integer :=   5; -- read address' start
    
-- sim constants
    constant PERIOD : time := 10 ns; -- 0.01 us, normal clock timing
-- sim signals
    signal CLK : std_logic := '0';
    signal RST : std_logic := '0';

-- Signals inbetween Components
    signal MCv, MSv : std_logic;
    signal MC0, MC1 : STD_LOGIC_VECTOR (31 downto 0);
    signal MS0, MS1, MS2, MS3 : STD_LOGIC_VECTOR (31 downto 0);
    
-- Sim controlled signals
    signal Mstate :  STD_LOGIC_VECTOR (2 downto 0);
    signal BTN0, BTN1, BTN3 : std_logic;
    signal Bren : std_logic;
    signal Bwen : STD_LOGIC_VECTOR (3 downto 0);
    signal Bdin, Bdout, Bramaddr : STD_LOGIC_VECTOR (31 downto 0);
    signal Baddr : integer range 0 to 2047; -- 11 bit/ depth of bram
    
 -- array
    type DARRAY is array (0 to 30) of std_logic_vector(31 downto 0);
    signal Dreg, nDreg : DARRAY := (OTHERS => (OTHERS => '0'));
    
begin

BMemCon : Bram_MemCon
    port map ( 
       CLK => CLK, RST => RST,
       MS_valid => MSv,
       MS0 => MS0, MS1 => MS1, MS2 => MS2,
       MC_valid => MCv,
       MC0 => MC0, MC1 => MC1,
       -- Bram connections
       Ben => Bren,
       Bread => Bdout,
       Bwrite => Bdin,
       Bwe => Bwen,
       Baddr => Bramaddr
    ); 

BMotorS : Bram_Motorstates_Ctrl
    port map (  
       CLK => CLK, RST => RST,
       MCinV => MCv,
       DIR_REF => '0', 
       --RUNSin, RTYPE      : in STD_LOGIC;
       BTNUP => BTN1, BTNDOWN => BTN0, BTNRST => BTN3,
       CLsens => x"0fc",
       MCin0 => MC0, MCin1 => MC1,
       StateColor => Mstate,
       PULS => PULSO, DirOut => DirO,
       MS_valid => MSv,
       StepGOALO => MS0, StepCURO => MS1, CLOOPino => MS2
    ); 

CLK <= not CLK after (PERIOD/2);

-- sim output
CLKO <= CLK;
RSTO <= RST;
MstateO <= Mstate;
BrenO <= Bren;
BwenO <= Bwen; 
BdinO <= Bdin;
BdoutO <= Bdout;
BaddrO <= b"00" & Bramaddr(31 downto 2);

-- constants
BTN0 <= '0';
BTN1 <= '0';
BTN3 <= '0';

-- sim conversions
Baddr <= TO_INTEGER(unsigned(Bramaddr(31 downto 2)));


process(CLK, RST, Bren, Baddr, Dreg )
begin
    if rising_edge(CLK) then
    
        if Bren = '1' then
            Bdout <= Dreg(Baddr);  
        else
            Bdout <= x"00000000";
        end if;
        
    end if;
end process;


process(CLK, RST, Bren, Bwen, Bdin, Baddr, Dreg)
begin
    if rising_edge(CLK) then
        
        if RST = '0' or BTN3 = '1' then
            nDreg <= (OTHERS => (OTHERS => '0'));
            RST <= '1';
        else
            nDreg <= Dreg;
            if Bwen = b"1111" and Bren = '1' then
                nDreg(Baddr) <= Bdin;
            else --RUNaddr, MC0addr, MC1addr
                nDreg(NJC) <= RUNaddr;
                nDreg(RaS) <= MC0addr;
                nDreg(RaS+1)<=MC1addr;
            end if;
            
        end if;
        Dreg <= nDreg;
    end if;
end process;


end Behavioral;
