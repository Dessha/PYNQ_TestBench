----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2026 13:31:24
-- Design Name: 
-- Module Name: Bram_Motorstates_Ctrl - Behavioral
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

entity Bram_Motorstates_Ctrl is
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
           --StepITest    : out STD_LOGIC_VECTOR (21 downto 0);-- FreqCOUNT 18, state 3, --- testing signal
           StepGOALO, StepCURO, CLOOPino    : out STD_LOGIC_VECTOR (31 downto 0)); -- DIR ADD
           --StepINFO0, StepINFO1     : out STD_LOGIC_VECTOR (31 downto 0));-- DirCon 1, StepCUR 21,  10 |GOALstep 21| 11 , ForceIN 11

end Bram_Motorstates_Ctrl;

architecture Behavioral of Bram_Motorstates_Ctrl is

-- add ERROR state, Difine Difference between IDLE & START
    type State_names is (IDLE, START, WDATA, RUNTest, BTNSRUN); --https://vhdlwhiz.com/finite-state-machine/
    signal CURstate, NEXTstate : State_names;

--Constants
    constant MinHPULS : integer := 300; --- clks/ns, 3 us/0.01 us CLK = 300 , since min puls with = 2.5 us
    constant MinFreq : integer := MinHPULS + MinHPULS; -- 6 us, 600 clks, 6000 ns, 166.7 kHz <=> 0.1667 MHz
    constant BTNFreq : integer := 30000;
    constant MaxedFreq : integer := 104857500; --2^27 -104,857,500 = 29,360,228 unused numbers, 
    constant MaxedStep : integer := 2097151; --2^21-1
    signal UPD : STD_LOGIC := '0';
    signal DOWND : STD_LOGIC; 
    
    
-- control signals

    signal DirCon, nDirCon : STD_LOGIC;
    signal Pstep : integer range 0 to 128; -- NR of posistions of motor 
    
-- input comand slice sig
    signal Steptype, RUNSig, SteptypeT, RUNSigT :  STD_LOGIC; -- type 1 = distance, 0 = force
    signal PosNext, MAXFORCE, PosNextT, MAXFORCET : STD_LOGIC_VECTOR (20 downto 0); -- 21 bit counter  
                                                        -- 1 sec => 1,000,000 us ~=> 2^20 -1 => 1,048,574 us, for lowest less then 1 step a second  
    signal FreqTime, FreqTimeT   : STD_LOGIC_VECTOR (19 downto 0); -- 2^20-1 => 1,048,574 us /0.01 us = 4857400 CLK cycles above needed clk=100Mhz=10ns
    
    
-- change to signed int
    signal StepGoal, NStepGOAL, ForceGOAL, IPosNext, IPosTESTNR : integer range 0 to MaxedStep; -- 2^21-1 
    signal NForceGOAL, IForceIN : integer range 0 to MaxedStep; -- 2^21-1 
    --Signal SCUR : STD_LOGIC_VECTOR (20 downto 0);
    signal FreqIN : integer range 0 to MaxedFreq; 
    
-- counters 
    signal StepCUR, STEPtemp, Rvar : integer range 0 to MaxedStep := 0; -- 2^21-1 -- should it be signed?? -1048575 to 1048575
    signal FreqCOUNT, FreqCOUNTtemp, IFreqTime : integer range 0 to MaxedFreq := 0;
    signal ENFreqRUN : STD_LOGIC := '0';
    signal Npuls, Opuls : STD_LOGIC := '0'; 
    
    
-- temp signals
    signal PS :  STD_LOGIC_VECTOR (6 downto 0);-- conversion sig Pstep
    signal SGlv : STD_LOGIC_VECTOR (20 downto 0);-- conversion sig StepGoal out
    
    signal BTNS, StepFS, msv : STD_LOGIC;
    signal SGaSI  : STD_LOGIC_VECTOR (20 downto 0);
    
    signal ErA,ErQ : STD_LOGIC_VECTOR (7 downto 0) := x"00"; --ErrorAnswer ????- x1=FreqIn<MinFreq,  currently not functional
    signal SITstate  : STD_LOGIC_VECTOR (2 downto 0);
    
    
begin

UPD <= DIR_REF; -- 0 standart 
DOWND <= NOT UPD; -- decides witch direction counts up vs down;

-- input comand slicing
process(CLK, MCin0, MCin1)
begin
    if rising_edge(CLK) then
        if RST = '0' then
            RUNSigT   <= '0';
            SteptypeT <= '0';
            PosNextT  <= b"000000000000000000000"; 
            MAXFORCET <= b"111111111111111110000"; 
            FreqTimeT <= b"00000000000000000000";
        elsif MCinV = '1' then 
            RUNSigT   <= MCin1(31); --RUNSin;
            SteptypeT <= MCin1(30); -- RTYPE; -- type 1 = distance, 0 = force 
            PosNextT  <= MCin1(29 downto 9); 
            MAXFORCET(20 downto 12)  <= MCin1(8 downto 0); -- top 9 of 21 bits
            MAXFORCET(11 downto 0)   <= MCin0(31 downto 20); 
            FreqTimeT <= MCin0(19 downto 0); -- user control down to 1 us
        end if;
    end if;
    RUNSig   <= RUNSigT;
    Steptype <= SteptypeT;
    PosNext  <= PosNextT; 
    MAXFORCE <= MAXFORCET; 
    FreqTime <= FreqTimeT;
end process;

-- input conversion signal type
BTNS <= BTNUP or BTNDOWN;
FreqIN <= to_integer(unsigned(FreqTime))*100; -- from us to clkcycles 10 ns, (min 6 us)
IPosNext <= to_integer(unsigned(PosNext)); -- Steps, Jupyther handelse mm to Step ratio for easier, qalibration?
IForceIN <= to_integer(unsigned(CLsens)); -- Voltage, Jupyter handelse N to V ratio, (messurement tool change)
Rvar <= STEPCUR when(StepFS = '1') else IForceIN; -- type 1 = distance, 0 = force, turns on/off clossed loop control



process (CLK, CURstate, MCinV, RUNSig, StepGoal, FreqIN)--CURstate, PosNext, RUNSig, FreqIN) -- change NEXTstate
begin
    NEXTstate <= CURstate;
    case CURstate is
        when IDLE => -- reset
            if MCinV = '1' then 
                NEXTstate <= START;
            end if;
        when START => 
            if (RUNSig = '1') then 
                NEXTstate <= WDATA;
            elsif (RUNSig = '0') then 
                NEXTstate <= IDLE;
            end if;
        when WDATA =>
            if (RUNSig = '0') then 
                NEXTstate <= IDLE;
            elsif StepGoal /= 0 AND IFreqTime >= MinFreq then  
                NEXTstate <= RUNTest;
            elsif FreqIN < MinFreq then 
                ErA <= x"01";
            end if;
        when RUNTest => 
            if (RUNSig = '0' and IForceIN = 0) then 
                NEXTstate <= IDLE; -- runsig = 0 when last expected values optained in Jupyter
            end if;
        when BTNSRUN => -- add non global reset button???
            if BTNRST = '1' then 
                NEXTstate <= IDLE;
            end if;
            -- ends with Reset
    end case;
end Process;


process (CLK, RST, Nextstate, BTNS) -- change CURstate
begin
    if rising_edge(CLK) then
        if RST = '0' then CURstate <= IDLE;
        elsif BTNS ='1' then CURstate <= BTNSRUN;
        else  CURstate <= Nextstate;
        end if;
    end if;

end Process;


----  state specific input check ----- 
process (CLK, CURstate, Rvar, IPosNext, FreqIN, StepType, UPD, DOWND) -- Rvar(STEPCUR/IForceIN), MAXForce
begin-- Difines DIRCON, ENFreqRUN, NStepGoal, StepGoal
    if rising_edge(CLK) then
        case CURstate is
            when IDLE => -- Reset
                SITstate <= b"001";--state red
                nDIRCON <= UPD; 
                ENFreqRUN <= '0';
                NStepGoal <= 0;
                IFreqTime <= MinFreq;
            when START =>
                SITstate <= b"010";--state green
                nDIRCON <= DOWND; 
                ENFreqRUN <= '0';
                NStepGoal <= 0;
                IFreqTime <= MinFreq; 
            when WDATA =>
                             
                SITstate <= b"010";--state green
                ENFreqRUN <= '0';
                NStepGoal <= IPosNext;
                StepFS <= StepType;
                IFreqTime <= FreqIN; 
                if PosNext(20) = '0' then -- PosNext = positive
                    nDIRCON <= DOWND;
                else -- PosNext = negative
                    nDIRCON <= UPD;
                end if;
            when RUNTest =>
                SITstate <= b"100";--state blue
                 if IForceIN >= MAXForce then  -- security func, add step limits?
                    -- add if repeated x times -> forced New NStepGoal??
                    DIRCON <= UPD;
                    ENFreqRUN <= '1';
                 elsif (DIRCON = DOWND AND Rvar >= StepGoal) or (DIRCON = UPD AND Rvar <= StepGoal) then -- stuck here when done
                    ENFreqRUN <= '0';
                    if StepGoal /= IPosNext or StepFS /= StepType then -- wait/endQ-sig? 
                        if StepType = '1' then 
                            if IPosNext > STEPCUR then
                                nDIRCON <= DOWND;
                            else -- IPosNext =< Rvar then
                                nDIRCON <= UPD;
                            end if;
                        else
                            if IPosNext > IForceIN then
                                nDIRCON <= DOWND;
                            else -- IPosNext =< Rvar then
                                nDIRCON <= UPD;
                            end if;
                        end if;
                        NStepGoal <= IPosNext;
                        IFreqTime <= FreqIN; 
                        StepFS <= StepType; 
                    end if;
                    
                 elsif DIRCON = DOWND AND Rvar < StepGoal then -- 
                    ENFreqRUN <= '1';
                 elsif DIRCON = UPD AND Rvar > StepGoal then 
                    ENFreqRUN <= '1';
                 else --- SCREAM IN ERROR/HOW DID YOU GET HERE
                    ENFreqRUN <= '0';
                 end if;
                 
                 
            when BTNSRUN => -- buttons tested and work
                IFreqTime <= BTNFreq; -- add so user can control BTNFreq??
                SITstate <= b"101";--state purple(blue/red)
                NStepGoal <= 8725;
                if BTNUP = '1' then -- prioritises going up
                    nDIRCON <= UPD; 
                    ENFreqRUN <= '1';
                elsif BTNDOWN = '1' then
                    nDIRCON <= DOWND; 
                    ENFreqRUN <= '1';
                else 
                    nDIRCON <= UPD; 
                    ENFreqRUN <= '0';
                end if;
        end case;
    end if;
    StepGoal <= NStepGoal;
    DIRCON <= nDIRCON; 
end Process;


----------------------------------------------------------------
-- Counters


process(CLK, RST, FreqCOUNT, IFreqTime, ENFreqRUN) ------------- Frequency counter ------------- 
begin 
   if rising_edge(CLK) then 
   -- add error for MaxedFreq surpassed??
        if FreqCOUNT >= IFreqTime OR RST = '0' then --- zeros counter when requeset time reached or Reset done
            FreqCOUNTtemp <= 0;
        elsif ENFreqRUN = '0' AND FreqCOUNT = 0 then
            FreqCOUNTtemp <= 0;
        else
            FreqCOUNTtemp <= FreqCOUNT + 1;
        end if;       
    end if;
    
    FreqCOUNT <= FreqCOUNTtemp;
end process;


-------------  puls generator  -------------
Npuls <= '1' when FreqCOUNT <= MinHPULS AND FreqCOUNT > 0 else '0';

process(CLK, RST, Npuls, StepCUR, DOWND, DirCon)  -------------  StepCounter  -------------
begin 
    if rising_edge(CLK) then 
        if RST = '0' then --- add overflow error...
            STEPtemp <= 0; 
        elsif Npuls = '0' AND Opuls = '1' then
            if DirCon = DownD then 
                STEPtemp <= StepCUR + 1 ;
            else -- DirCon = UPD
                STEPtemp <= StepCUR - 1 ;
            end if;
        end if;
        StepCUR <= STEPtemp;
        Opuls <= Npuls;
    end if;
    
    
end process;


------------------- outputs ------------------- 
PULS <= NPULS; -- Set freq to min sig 
DirOut <= DIRCON;
MS_valid <= '1' when CURstate = RUNtest or CURstate = BTNSRUN else '0';

--- StepGOALO, StepCURO, CLOOPino
--STEPINFO0(31) <= DIRCON; !!!!!!!!
StepGOALO <= DIRCON & b"0000000000" & std_logic_vector(to_unsigned(StepGoal , 21)); 
StepCURO <= b"00000000000" & std_logic_vector(to_unsigned(StepCUR, 21));
CLOOPino <= x"00000" & CLSens;   -- 12 bit 20 bit
StateColor <= SITstate;


end Behavioral;
