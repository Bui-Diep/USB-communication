library IEEE;
use IEEE.std_logic_1164.all;
entity USBReceiver is
port (
Reset: in std_logic;
Clock: in std_logic;
Input: in std_logic;
OutputSelect: in std_logic_vector(2 downto 0);
ReceiverEnable: in std_logic;
SpeedEnable: in std_logic;
Output: out std_logic_vector(7 downto 0);
ReceivedByte: out std_logic;
PacketIDOut: out std_logic_vector(3 downto 0);
Endpoint: out std_logic_vector(3 downto 0);
Start: out std_logic;
HandshakePkt: out std_logic;
TransactionSetup: out std_logic;
DeviceAddress: out std_logic_vector(6 downto 0);
ClockOut: out std_logic
);
end USBReceiver;
architecture USBReceiver of USBReceiver is
signal PreviousInput: std_logic;
signal DataStuffed: std_logic;
---==========================================================
--Signal for counting consecutive 1's
---==========================================================
signal CountBit: integer; --Keeps track of consecutive 1's.
signal Data: std_logic_vector (7 downto 0);
---==========================================================
---Signal for counting number of bits shifted by serial to parallel converter.
---==========================================================
signal CountShift: integer;
---==========================================================
--- clock signals
---==========================================================
signal LeadToBuffer: std_logic;
---============================================================
---Declaration of signals for Phase Locked Loop (PLL)
---============================================================
signal PreviousPllInput: std_logic;
signal UserClock: std_logic;
signal PreviousOutputSignal: std_logic;
signal CountPll: integer;
---============================================================
---Declaration of signals for Multiplexor.
---============================================================
signal ByteOut: std_logic_vector(7 downto 0);
---============================================================
---Declaration of signals for Packet ID checker.
---============================================================
signal PacketID: std_logic_vector(7 downto 0);
---============================================================
--Declaration of signals for SOP (start of packet detector).
---===========================================================
type SOPStateType is (S0,S1,S2,S3,S4,S5,S6,S7,S8);
signal SOPState,NextSOPState:SOPStateType;
---===========================================================
---Declaration of signals for CRC calculators.
---===========================================================
signal NextCRCState: std_logic_vector(15 downto 0);
signal CRCState: std_logic_vector(15 downto 0);
signal CRC16Out: std_logic_vector(15 downto 0);
signal NextCRC5State: std_logic_vector(4 downto 0);
signal CRC5State: std_logic_vector(4 downto 0);
signal CRC5Out: std_logic_vector(4 downto 0);
begin
Clock_Gen_or_Driver: process(UserClock)
begin
if UserClock = '1' then
ClockOut <= '1';
else
ClockOut <= '0';
end if;
end process;
StartOfPacketDetector: process(SOPState, Input)
begin
case SOPState is
when S0=>if Input = '0' then NextSOPState <= S1;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S1=>if Input = '1' then NextSOPState <= S2;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S2=>if Input = '0' then NextSOPState <= S3;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S3=>if Input = '1' then NextSOPState <= S4;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S4=>if Input = '0' then NextSOPState <= S5;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S5=>if Input = '1' then NextSOPState <= S6;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S6=>if Input = '0' then NextSOPState <= S7;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S7=>if Input = '0' then NextSOPState <= S8;Start <= '0';
else NextSOPState <= S0;Start <= '0';end if;
when S8=>NextSOPState <= S0;Start <= '1';
end case;
end process;
---==============================================================
---Process for updating the state of SOP detector.
---==============================================================
process(UserClock, Reset)
begin
if Reset = '1' then
SOPState <= S0;
elsif rising_edge(UserClock) then
SOPState <= NextSOPState;
end if;
end process;
---===============================================================
---Process for Phase Locked Loop (PLL) for clock recovery from data
---===============================================================
PhaseLL: process (Clock)
---===============================================================
---Declaration of variables
---===============================================================
variable PreviousOutput: std_logic;
begin
if Reset = '1' then
PreviousPllInput <= '0';
PreviousOutputSignal <= '0';
CountPll <= 0;
PreviousOutput := '0';
elsif clock'EVENT and clock='1' then
PreviousOutput := PreviousOutputSignal;
if not(PreviousPllInput = Input) then
PreviousOutput := not (PreviousOutput);
CountPll <= 0;
elsif CountPll = 1 then
PreviousOutput := not (PreviousOutput);
CountPll <= 0;
else
CountPll <= CountPll + 1;
end if;
end if;
PreviousPllInput <= Input;
PreviousOutputSignal <= PreviousOutput;
UserClock <= PreviousOutput;
end process;
ReceiverInternal: process (UserClock, Reset)
variable DataStuffedTemp: std_logic;
variable DataTemp: std_logic_vector(7 downto 0);
variable CountBitTemp: integer;
variable CountShiftTemp: integer; --Keeps track of number of bits
begin
if Reset = '1' then
PreviousInput <= '0';
DataStuffed <= '0';
CountBit <= 0;
Data <= "00000000";
CountShift <= 0;
ReceivedByte <= '0';
ByteOut <= "00000000";
---========================================================
---NRZI Decoder
---========================================================
elsif UserClock'EVENT and UserClock = '1' then
if ReceiverEnable = '1' OR SpeedEnable = '1' then
DataStuffedTemp := DataStuffed;
DataTemp := Data;CountBitTemp := CountBit;CountShiftTemp := CountShift;
if (Input = PreviousInput) then
DataStuffedTemp := '1';else
DataStuffedTemp := '0';end if;
---========================================================---Counting number of 1's for the purpose of removing stuffed bit.---========================================================
if DataStuffedTemp = '1' thenCountBitTemp := CountBitTemp + 1;
else
CountBitTemp := 0;end if;
---==========================================================---The input is added to the data register only if it is not a stuffed bit.---==========================================================
if not(CountBitTemp = 6) thenDataTemp(7) := DataTemp(6);DataTemp(6) := DataTemp(5);DataTemp(5):= DataTemp(4);DataTemp(4) := DataTemp(3);DataTemp(3) := DataTemp(2);DataTemp(2) := DataTemp(1);DataTemp(1) := DataTemp(0);DataTemp(0) := DataStuffedTemp;
CountShiftTemp := CountShiftTemp + 1;else
---===========================================================---The counter is set to '0' after the stuffed bit is removed.---=========================================================
CountBitTemp := 0;end if;
---==========================================================---When a byte is received the counter =8 and ReceivedByte=1.---==========================================================
if CountShiftTemp = 8 thenReceivedByte <= '1';ByteOut <= DataTemp;
---===========================================================---The counter is now being ready for the next work by reseting  it to 0.---=============================================================
CountShiftTemp := 0;else
ReceivedByte <= '0';end if;
DataStuffed <= DataStuffedTemp;Data <= DataTemp;
CountBit <= CountBitTemp;CountShift <= CountShiftTemp;
PreviousInput <= Input;end if;
end if;end process;
---===============================================================---Process for the working of the Demultiplexer---===============================================================-
process (OutputSelect, ByteOut)begin
case OutputSelect is
when "000" => PacketID <= ByteOut;when "001" =>
Endpoint(3) <= ByteOut(0);DeviceAddress <= ByteOut(7 downto 1);when "010" =>
Endpoint(2 downto 0) <= ByteOut(7 downto 5);when others => Output <= ByteOut;end case;
end process;
PacketIDChecker: process (Reset, PacketID)begin
if Reset = '1' thenHandshakePkt <= '0';PacketIDOut <= "0000";TransactionSetup <= '0';
---========================================================---Start of frame (SOF) transaction---==========================================================
elsif PacketID = "10100101" thenPacketIDOut <= "0000";HandshakePkt <= '0';
---=========================================================---SETUP Transaction---=========================================================
elsif PacketID = "10110100" thenPacketIDOut <= "0001";HandshakePkt <= '0';TransactionSetup <= '1';
---=========================================================--OUT  Transaction---=========================================================
elsif PacketID = "10000111" then--EnableReceiver <= '1';
PacketIDOut <= "0010";HandshakePkt<= '0';
---==========================================================---IN  Transaction---==========================================================
elsif PacketID = "10010110" thenPacketIDOut <= "0011";HandshakePkt <= '0';
---==========================================================---DATA0 transaction---==========================================================
elsif PacketID = "11000011" thenPacketIDOut <= "0100";HandshakePkt <='0';
---=========================================================---DATA1 transaction---=========================================================
elsif PacketID = "11010010" thenPacketIDOut <= "0101";HandshakePkt <= '0';
---=========================================================---ACKNOWLEDGMENT---=========================================================
elsif PacketID = "01001011" thenPacketIDOut <= "0110";HandshakePkt <= '1';
---=========================================================---NEGATIVE ACKNOWLEDGMENT---=========================================================
elsif PacketID = "01011010" thenPacketIDOut <= "0111";HandshakePkt <= '1';
---==============================================================---STALL---==============================================================
elsif PacketID = "01111000" thenPacketIDOut <= "1000";HandshakePkt<= '1';
end if;end process;
---=============================================================---Calculation of 16-bit CRC---=============================================================
process(Clock, Reset, DataStuffed)begin
if Clock'EVENT and Clock = '1' thenCRC16Out <= NextCRCState;CRCState <= NextCRCState;
end if;
if Reset = '1' then
CRCState <= "0000000000000000";CRC16Out <= "0000000000000000";NextCRCState <= "0000000000000000";
else
NextCRCState(15) <= CRCState(14) XOR DataStuffed XOR CRCState(15);NextCRCState (14) <= CRCState (13);
NextCRCState (13) <= CRCState (12);NextCRCState (12) <= CRCState (11);NextCRCState (11) <= CRCState (10);
NextCRCState (10) <= CRCState (9);NextCRCState (9) <= CRCState (8);NextCRCState (8) <= CRCState (7);NextCRCState (7) <= CRCState (6);NextCRCState (6) <= CRCState (5);NextCRCState (5) <= CRCState (4);NextCRCState (4) <= CRCState (3);NextCRCState (3) <= CRCState (2);
NextCRCState (2) <= CRCState (1) xor DataStuffed xor CRCState(15);NextCRCState (1) <= CRCState (0);
NextCRCState (0) <= DataStuffed XOR CRCState(15);
end if;end process;
---======================================================---Calculation of 5-bit CRC---======================================================
process(Clock)begin
if Clock'EVENT and Clock = '1' thenCRC5Out <= NextCRC5State;CRC5State <= NextCRC5State;
end if;
if Reset = '1' then
CRC5State <= "00000";CRC5Out <= "00000";NextCRC5State <= "00000";
else
NextCRC5State(4) <= CRC5State(3);NextCRC5State(3) <= CRC5State(2);
NextCRC5State(2) <= CRC5State(1) XOR DataStuffed XOR CRC5State(4);NextCRC5State(1) <= CRC5State(0);
NextCRC5State(0) <= DataStuffed XOR CRC5State(4);
end if;
end process;
end USBReceiver;