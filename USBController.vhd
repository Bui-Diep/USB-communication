library IEEE;
use IEEE.std_logic_1164.all;
entity USBController is
port (
Input: in std_logic_vector (7 downto 0);
------- Output: out std_logic_vector (7 downto 0);
RCV: in std_logic;
Vmo: out std_logic;
Vpo: out std_logic;
ClockSpeed: in std_logic;
Reset: in std_logic;
End_of_Pkt: inout std_logic;
ByteSent: inout std_logic;
Pid:inout std_logic_vector (1 downto 0);
Mux: inout std_logic_vector (2 downto 0);
TransactionSetup: inout std_logic;
Enable: in std_logic
-----EndpointNo: out std_logic_vector (3 downto 0);
-----DeviceAddress: out std_logic_vector (6 downto 0)
);
end USBController;
architecture USBController of USBController is
component USBTransmitter
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
end component;
component USBReceiver
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
end component;
---=========================================================
---Declaration of signals for SpeedEnable
---=========================================================
signal SpeedEnable: std_logic;
signal MuxSelect: std_logic_vector (2 downto 0);
signal EnableTransmitter: std_logic;
signal EnableReceiver: std_logic;
---========================================================
---Declaration of signals which are to be applied on controller.
---========================================================
signal PacketIDToSend: std_logic_vector(1 downto 0);
signal End_of_pkt: std_logic;
signal ByteSentOut: std_logic;
signal ReceivedByte: std_logic;
---========================================================
---Declaration of signals for the controller
---========================================================
constant TransactionIn: std_logic_vector (3 downto 0) := "0011";
constant TransactionOut: std_logic_vector (3 downto 0) := "0010";
constant TransactionSOF: std_logic_vector (3 downto 0) := "0000";
signal TransmitterMuxSelect: std_logic_vector (2 downto 0);
---========================================================
---Declaration of signals that control the type of transaction going on.
---========================================================
signal TransactionType: std_logic_vector (3 downto 0);
---========================================================
---The state machine of the controller represented with 10 named states: ShiftRegister1 type.
---========================================================
type ShiftRegister1Type is (Start, PacketIDToken, FirstByte, SecondByte, SyncronData, PacketIDData, 
CRCData,
PacketIDHsk, Data, SyncronHsk);
signal ShiftRegister1: ShiftRegister1Type;
---=======================================================
---Declaration of signals for the controller which were ports initially.
---=======================================================
signal Resume: std_logic;
signal HandshakePkt: std_logic;
signal PacketIDType : std_logic_vector(3 downto 0);
signal Isochron: std_logic := '0';
signal Clock: std_logic;
begin
USBTransmitter1: USBTransmitter port map(Reset, Clock, Input, TransmitterMuxSelect, PacketIDToSend,
EnableTransmitter, End_of_pkt, Vpo, Vmo, ByteOut);
USBReceiver1: USBReceiver port map (Reset, ClockSpeed, RCV, MuxSelect,  EnableReceiver,  
SpeedEnable, Output,
ReceivedByte, PacketIDType,  EndpointNo, Resume,
HandshakePkt, TransactionSetup, DeviceAddress, Clock);
---====================================================
---The controller's internal process continues
---====================================================
StateControl: process (Clock, Reset)
    ---====================================================
    ---Declaration of variable for the state machine.
    ---====================================================
    variable EndCount: std_logic;
    begin
    if Reset='1' then
    ShiftRegister1 <= Start;
    ---====================================================
    ---Setting the states of the controller by providing default values and conditions.
    ---====================================================
    EndCount := '1';
    EnableReceiver <= '0';
    EnableTransmitter <= '0';
    Enable <= '0';
    PacketIDToSend <= "00";
    TransmitterMuxSelect <= "111";
    elsif Clock'event and Clock = '1' then
    if ReceivedByte = '1' OR Resume = '1' OR ByteOut = '1' then
    ---===================================================
    --- Values and conditions to move the controller from one state to onother..
    ---===================================================
    EndCount := '1';
    case ShiftRegister1 is
    when Start =>
    EnableReceiver <= '0';
    EnableTransmitter <= '0';
    if Resume = '1' then
    ShiftRegister1 <= PacketIDToken;
    EnableReceiver <= '1';
    end if;
    when PacketIDToken =>
    if HandshakePkt = '1' then
    ShiftRegister1 <= Start;
    elsif HandshakePkt = '0' then
    ShiftRegister1 <= FirstByte;
    end if;
    when FirstByte =>
    TransactionType <= PacketIDType;
    ShiftRegister1 <= SecondByte;
    when SecondByte =>
    if PacketIDType = TransactionSOF then
    ShiftRegister1 <= Start;
    elsif TransactionType = TransactionOut and Resume = '1' then
    ShiftRegister1 <= PacketIDData;
    elsif TransactionType = TransactionIn then
    ShiftRegister1 <= SyncronData;
    TransmitterMuxSelect <= "111";
    EnableReceiver <= '0';
    EnableTransmitter <= '1';
    end if;
    when SyncronData =>
    if TransactionType <= TransactionIn then
        EnableReceiver <= '0';
        EnableTransmitter <= '1';
        end if;
        if ByteSentOut = '1' then
        ShiftRegister1 <= PacketIDData;
        end if;
        TransmitterMuxSelect <= "000";
        PacketIDToSend <= "11";
        when PacketIDData =>
        if TransactionType = TransactionOut then
        ShiftRegister1 <= Data;
        elsif ByteOut = '1' then
        ShiftRegister1 <= Data;
        end if;
        TransmitterMuxSelect <= "011";
        when CRCData =>
        if Isochron = '1' and EndCount = '1' then
        ShiftRegister1 <= Start;
        elsif TransactionType = TransactionIn and Resume = '1'
        and EndCount = '1' then
        ShiftRegister1 <= PacketIDHsk;
        elsif Isochron = '0' and TransactionType = TransactionOut
        and EndCount = '1' then
        ShiftRegister1 <= SyncronHsk;
        EnableTransmitter <= '1';
        EnableReceiver <= '0';
        TransmitterMuxSelect <= "111";
        end if;
        when PacketIDHsk =>
        if ByteSentOut = '1' then
        ShiftRegister1 <= Start;
        end if;
        when Data =>
        if EndCount = '1' then
        if TransactionType = TransactionOut then
        ShiftRegister1<= CRCData;
        elsif (TransactionType = TransactionIn) and (ByteSentOut = '1') then
        ShiftRegister1 <= CRCData;
        end if;
        end if;
        when SyncronHsk =>
        if TransactionType = TransactionOut then
        EnableTransmitter<= '1';
        EnableReceiver <= '0';
        TransmitterMuxSelect <= "000";
        end if;
        if ByteOut = '1' then
        ShiftRegister1 <= PacketIDHsk;
        end if;
        when others =>
        null;
        end case;
        end if;
        end if;
        end process;
        ---======================================================
        ---Multiplexer outputs based on different selected values provided here.
        ---======================================================
        MuxSelectAssignment:
        MuxSelect <= "000" when (ShiftRegister1 = PacketIDToken) else
        "001" when (ShiftRegister1 = FirstByte) else
            "010" when (ShiftRegister1 = SecondByte) else
                "111" when (ShiftRegister1 = SyncronData) else
                "000" when (ShiftRegister1 = PacketIDData) else
                "100" when (ShiftRegister1 = CRCData) else
                "000" when (ShiftRegister1 = PacketIDHsk) else
                "011" when (ShiftRegister1 = Data) else
                "111" when (ShiftRegister1 = SyncronHsk) else
                "000";
                SpeedEnable: process(Resume)
                begin
                if Resume = '1' and ShiftRegister1 = Start then
                SpeedEnable <= '1';
                else
                SpeedEnable <= '0';
                end if;
                end process;
                end USBController;