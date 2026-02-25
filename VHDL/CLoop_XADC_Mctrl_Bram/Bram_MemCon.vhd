----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.01.2026 13:31:52
-- Design Name: 
-- Module Name: Bram_MemCon - Behavioral
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

entity Bram_MemCon is
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
end Bram_MemCon;

architecture Behavioral of Bram_MemCon is
 -- states
    type State_names is (IDLE, CheckJUP, ReadJUP, WriteJCR, WriteSData); --https://vhdlwhiz.com/finite-state-machine/
    signal CURstate, NEXTstate : State_names;
 
 -- constants
    constant ADDRMAX : integer := 50;
    constant Pwait : integer := 2; -- pointer waiting address
    constant NJC : integer :=   4; -- new JUP command
    constant RaS : integer :=   5; -- read address' start
    constant RaE : integer :=  15; -- read address' end 
    
    constant WaS : integer :=  17; -- write address' start
    constant WaE : integer :=  20; -- write address' end
    constant NSD : integer :=  WaE+1; -- new Step data
    
 -- arrays
    type IDARRAY is array (RaS to RaE) of std_logic_vector(31 downto 0);
    signal IDreg, nIDreg : IDARRAY := (OTHERS => (OTHERS => '0'));
    
    type ODARRAY is array (WaS to NSD) of std_logic_vector(31 downto 0);
    signal ODreg : ODARRAY := (OTHERS => (OTHERS => '0')); -- , nODreg

 -- pointing counter
    signal Ipoint, nIpoint  : integer range 0 to 2047 :=  0; -- 11 bit
    signal RaDelta, WaDelta : STD_LOGIC;
    
 -- internal I/O signals 
    signal rov : STD_LOGIC; -- read out valid
    signal aen : STD_LOGIC; -- address enable
    
    signal woen :  STD_LOGIC_VECTOR (3 downto 0); -- write out enable
    signal wod  :  STD_LOGIC_VECTOR (31 downto 0); -- write out data
    
    signal data_hold : STD_LOGIC;
    

begin

-- output
MC_valid <= '1' when IDreg(RaS) /= x"00000000" and IDreg(RaS+1) /= x"00000000" else
            '0';
            
MC0 <= IDreg(RaS);
MC1 <= IDreg(RaS+1);

Ben <= '1';-- aen;

Baddr <= b"0000000000000000000" & std_logic_vector(to_unsigned(Ipoint,11)) & b"00";
Bwrite <= wod;

RaDelta <= '1' when Ipoint >= RaS  AND Ipoint <= RaE   else
           '0';
          
WaDelta <= '1' when Ipoint >= WaS AND WaE >= Ipoint else
           '0';

wod <= ODreg(Ipoint) when Curstate = WriteSData else
       x"00000000"   when Curstate = WriteJCR else -- clears New Jupyter Address data
       x"00000000"; 

---ODreg(NJC) <=   -- when WriteJCR = CURstate and Ipoint = NJC else -- writing 
ODreg(NSD) <=  x"0000000f"; -- when Ipoint = NSD else -- set New Step data /= 0
ODreg(WaS) <=  MS0;         -- when Ipoint = WaS   else
ODreg(WaS+1)<= MS1;         -- when Ipoint = WaS+1 else
ODreg(WaS+2)<= MS2; 


woen <= x"f" when Ipoint = NSD or WaDelta = '1' else
        x"f" when (CURstate = WriteJCR) and (Ipoint = NJC) else
        x"0" when Ipoint = NJC or RaDelta = '1' else
        x"0";
       
Bwe <= woen;       

process(CLK, RST, Bread, RaDelta, WaDelta, CURstate, IDreg, Ipoint ) -- Data control
begin
    if rising_edge(CLK) then -- Nextstate
        if RST = '0' then 
            nIDreg <= (OTHERS => (OTHERS => '0'));
            nIpoint <= Pwait;
            NEXTstate <= IDLE;
            data_hold <= '0';
        elsif data_hold = '0' then
            nIDreg <= IDreg;
            data_hold <= '1';
            case CurState is -- CheckJUP, ReadJUP, WriteSData
                when CheckJUP =>
                    nIpoint <= NJC;
                    if Ipoint = NJC then
                        if Bread /= x"00000000" then
                            nIpoint <= RaS;
                            NEXTstate <= ReadJUP;
                        else
                            nIpoint <= WaS;
                            NEXTstate <= WriteSData;
                        end if;
                    else
                        NEXTstate <= CheckJUP;
                    end if;
                    
                when ReadJUP =>
                    if Ipoint = RaE then
                        nIDreg(Ipoint) <= Bread; 
                        NEXTstate <= WriteJCR;
                    elsif RaDelta = '1' then
                        nIpoint <= Ipoint + 1;
                        nIDreg(Ipoint) <= Bread; 
                        NEXTstate <= ReadJUP;
                    else
                        nIpoint <= RaS;
                        NEXTstate <= ReadJUP;
                    end if;
                    
                when WriteJCR =>
                    nIpoint <= NJC;
                    -- if Ipoint = NJC then woen = '1';
                    if Ipoint = NJC and Bread = x"00000000" then
                        nIpoint <= WaS;
                        NEXTstate <= WriteSData;
                    else
                        NEXTstate <= WriteJCR;
                    end if;
                    
                when WriteSData =>
                    if Ipoint = NSD then
                        nIpoint <= Ipoint;
                        NEXTstate <= CheckJUP;
                    elsif WaDelta = '1' then 
                        nIpoint <= Ipoint + 1; -- Runs over into Ipoint = NSD
                        NEXTstate <= WriteSData;
                    else --  Ipoint /= WaS to NSD
                        nIpoint <= WaS; 
                        NEXTstate <= WriteSData;
                    end if;
                when others => 
                    nIpoint <= Pwait;
                    NEXTstate <= CheckJUP;
            end case;
        else
--            nIDreg <= nIDreg;
--            nIpoint <= nIpoint;
--            Nextstate <= CURstate;
            data_hold <= '0';
        end if;
    end if;
    CURstate <= Nextstate;
    IDreg <= nIDreg;
    Ipoint <= nIpoint;
    
end process;


--process(CLK, RST, Nextstate, nIDreg, nIpoint) -- 
--begin
--    if rising_edge(CLK) then
        
----        if RST = '0' then
----            CURstate <= IDLE;
----        else
            
----        end if;
        
--    end if;
--end process;


end Behavioral;
