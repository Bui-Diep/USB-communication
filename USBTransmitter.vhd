library IEEE;
use IEEE.std_logic_1164.all;
entity USBTransmitter is
    port (
        Reset: in std_logic;
        Clock: in std_logic;
        Input: in std_logic_vector (7 downto 0);
        InputSelect: in std_logic_vector(2 downto 0);
        PacketIDSelect: in std_logic_vector(1 downto 0);
        TransmitterEnable: in std_logic;
        End_of_pkt_Send: in std_logic;
        Vpo: out std_logic;
        Vmo: out std_logic;
        ByteSentOut: out std_logic
);
end USBTransmitter;
architecture USBTransmitter of USBTransmitter is
signal PreviousOutput: std_logic;
signal DataStuffed: std_logic;
signal CountBit: integer range 0 to 6;
signal CountShift: integer range 0 to 8;
signal ShiftRegister: std_logic_vector(7 downto 0);
signal MuxOutput: std_logic_vector(7 downto 0);
signal SentByte: std_logic;
signal Output: std_logic;
---===================================================================
--- Declaration of signals for CRC 16 calculator.
---===================================================================
signal CRCState, NextCRCState, CRC16Out: std_logic_vector(15 downto 0);
---==================================================================
-- Declaration of signal for PacketID Generator. (Packet Identifier)
---==================================================================
signal PacketID: std_logic_vector(7 downto 0);
begin
TranInterface: process (Output, End_of_pkt_Send)
begin
    if End_of_pkt_Send = '1' then
        Vpo <= '0';
        Vmo <= '0';
    else
        if Output = '1' then
            Vpo <= '1';
            Vmo <= '0';
        else
            Vpo <= '0';
            Vmo <= '1';
        end if;
    end if;
end process;
Par_to_Ser_n_Bit_Add : process (Clock, Reset)
variable ShiftRegisterTemp: std_logic_vector(7 downto 0);
variable DataStuffedTemp: std_logic;
variable CountShiftTemp: integer range 0 to 8;
variable CountBitTemp: integer range 0 to 6;
begin
if Reset = '1' then
Output <= '1';
PreviousOutput <= '0';
DataStuffedTemp := '1';
CountBitTemp := 0;
CountShiftTemp := 0;
ShiftRegisterTemp := "00000000";
SentByte <= '0';
DataStuffed <= DataStuffedTemp;
CountShift <= CountShiftTemp;
CountBit <= CountBitTemp;
elsif Clock'EVENT and Clock = '1' then
DataStuffedTemp := DataStuffed;
CountShiftTemp := CountShift;
CountBitTemp := CountBit;
ShiftRegisterTemp := ShiftRegister;
if CountShiftTemp = 0 then
ShiftRegisterTemp := MuxOutput;
end if;
if TransmitterEnable = '1' then
if CountBitTemp = 6 then
DataStuffedTemp := '0';
CountBitTemp := 0;
else
DataStuffedTemp := ShiftRegisterTemp(7);
ShiftRegisterTemp := ShiftRegisterTemp(6 downto 0) & '1';
---==========================================================
-- Counter is incremented only if normal bit is sent.
---==========================================================
CountShiftTemp := CountShiftTemp + 1;
end if;
---==========================================================
-- Number of 1's is counted for the purpose of adding stuffed bit.
---==========================================================
if DataStuffedTemp = '1' then
CountBitTemp := CountBitTemp + 1;
else
CountBitTemp := 0;
end if;
if CountShiftTemp = 8 then
ByteSentOut <= '1';
CountShiftTemp := 0;
ShiftRegisterTemp := MuxOutput;
else
ByteSentOut <= '0';
end if;
end if;
if DataStuffedTemp = '0' then
PreviousOutput <= not(PreviousOutput);
Output <= PreviousOutput;
end if;
---Update signal values.
ShiftRegister <= ShiftRegisterTemp;
DataStuffed <= DataStuffedTemp;
CountShift <= CountShiftTemp;
CountBit <= CountBitTemp;
end if;
end process;
---======================================================
--- Calculation of 16 bit CRC
---======================================================
process(Clock, Reset, DataStuffed)
begin
if Clock'EVENT and Clock = '1' then
CRC16Out <= NextCRCState;
CRCState <= NextCRCState;
end if;
if Reset = '1' then
CRCState <= "0000000000000000";
CRC16Out <= "0000000000000000";
NextCRCState <= "0000000000000000";
else
NextCRCState (15) <= CRCState (14) XOR DataStuffed XOR CRCState (15);
NextCRCState (14) <= CRCState (13);
NextCRCState (13) <= CRCState (12);
NextCRCState (12) <= CRCState (11);
NextCRCState (11) <= CRCState (10);
NextCRCState (10) <= CRCState (9);
NextCRCState (9) <= CRCState (8);
NextCRCState (8) <= CRCState (7);
NextCRCState (7) <= CRCState (6);
NextCRCState (6) <= CRCState (5);
NextCRCState (5) <= CRCState (4);
NextCRCState (4) <= CRCState (3);
NextCRCState (3) <= CRCState (2);
NextCRCState (2) <= CRCState (1) XOR DataStuffed XOR CRCState (15);
NextCRCState (1) <= CRCState (0);
NextCRCState (0) <= DataStuffed XOR CRCState (15);
end if;
end process;
---==================================================================
---Generating Packet Identifier (PID)
---==================================================================
process (PacketIDSelect)
begin
case PacketIDSelect is
---ACKNOWLEDGMENT
when "00" => PacketID <= "01001011";
---NEGATIVE ACKNOWLEDGMENT
when "01" => PacketID <= "01011010";
--- DATA0 Packet.
when others =>PacketID <= "11000011";
end case;
end process;
---===============================================================
---The working of the Multiplexer
---================================================================
process (InputSelect, Input, CRC16Out)
begin
case InputSelect is
when "000" => MuxOutput <= PacketID;
when "100" => MuxOutput <= CRC16Out(7 downto 0);
when "101" => MuxOutput <= CRC16Out(15 downto 8);
when "011" => MuxOutput <= Input;
when "111" => MuxOutput <= "00000001";
when others => MuxOutput <= Input;
end case;
end process;
end USBTransmitter;