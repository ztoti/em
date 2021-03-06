' This script is an example of the EMDO101 energy manager
' Please visit us at www.swissembedded.com
' Copyright (c) 2015 - 20116 swissEmbedded GmbH, All rights reserved.
' This example reads a sunspec compatible inverter over modbus
' Please make sure that the inverters RS485 interface 
' is configured correctly. If multiple inverters are connected on a serial
' line make sure each device has a unique modbus slave address configured.
' Cable must be twisted pair with correct end termination on both ends
' Documentations
' SunSpec-EPRI-Rule21-Interface-Profile
' Fronius Datamanager TCP & RTU
' SMA SunSpec Modbus Schnittstelle
' Technical Note SunSpec Logging in Solaredge Inverters
SYS.Set "rs485", "baud=115200 data=8 stop=1 parity=n term=1"
itf$="RTU:RS485:1"
slv%=1
start:
 err%=SunspecCommon( itf$, slv%, iMan$, iMod$, iOpt$, iVer$, iSer$, iAddr%)
 print "Common" err% iMan$ iMod$ iOpt$, iVer$ iSer$ iAddr%
 err%=SunspecInverter(itf$, slv%, Iac1, Iac2, Iac3, Uac1, Uac2, Uac3, Pac, Fac, VA, VAR, PF, E, Idc, Udc, Pdc, T1, T2, T3, T4, Status%, Code% )
 print "Inverter" err% Iac1 Iac2 Iac3 Uac1 Uac2 Uac3 Pac Fac VA VAR PF E Idc Udc Pdc T1 T2 T3 T4 Status% Code%
 pause 30000
 goto start

' Sunspec Read block and check for magic
' itf$ Modbus Interface
' slv% Modbus Slave address
' bAddr% Modbus base address of the found block, if base is 0, address is detected automatically
' return negative value on error 
FUNCTION SunspecMagic(itf$,slv%,bAddr%)
  LOCAL err%, rsp$
  err%=mbFunc(itf$,slv%,3,bAddr%-1,2,rsp$,1000)  
  IF err% OR len(rsp$)<>4 THEN
   SunspecMagic=err%
   EXIT FUNCTION
  ENDIF 
  ' Expect SunSpec "SunS" magic and Common Model Block (1)  
  ' Block is at least 65 registers                                                  
  IF conv("bbe/u32", rsp$)<> &H53756e53 THEN
   print conv("bbe/u32", rsp$)
   SunspecMagic=-100
   EXIT FUNCTION
  ENDIF
  SunspecMagic=0
END FUNCTION

' Sunspec Read Block Id
' itf$   Modbus Interface
' slv%   Modbus Slave address
' bId%   Sunspec block id that is interesting
' bAddr% Modbus base address of the found block, if base is 0, address is detected automatically
' bLen%  Len of the block
' return negative value on error 
FUNCTION SunspecBlock(itf$,slv%,bId%, bAddr%,bLen%)
 LOCAL err%, ids%, rsp$
 IF bAddr%=0 THEN
  ' Autodetect the base of sunspec register at 40001,50001, 1  
  bAddr%=40001
  err%=SunspecMagic(itf$,slv%,bAddr%)
  IF err% THEN
   bAddr%=50001
   err%=SunspecMagic(itf$,slv%,bAddr%)
   IF err% THEN
    bAddr%=1
    err%=SunspecMagic(itf$,slv%,bAddr%)
    IF err% THEN
     SunspecBlock=err%
     EXIT FUNCTION
    ENDIF
   ENDIF
  ENDIF
  print "start" bAddr%
  ' We must point to start of block (e.g. 40003)
  bAddr%=bAddr%+2
 ENDIF 
 ' Now we iterate through the blocks, first on bAddr% is always block id
 DO 
  ' Read ID and L of the block
  err%=mbFunc(itf$,slv%,3,bAddr%-1,2,rsp$,1000)
  IF err% THEN
   SunspecBlock=err%
   EXIT FUNCTION
  ENDIF
  ids%=conv("bbe/u16",left$(rsp$,2))
  bLen%=conv("bbe/u16",right$(rsp$,2))
  'print bAddr% ids% bLen% len(rsp$)
  IF ids%=bId% THEN 
   ' We found the block     
   SunspecBlock=0
   EXIT FUNCTION  
  ELSEIF ids%=&HFFFF THEN
   ' Last block, we did not find the block
   SunspecBlock=-101
   EXIT FUNCTION    
  ENDIF
  bAddr%=bAddr%+bLen%+2 
 LOOP
END FUNCTION

' Sunspec Common Block for all manufacturers (id 0)
' itf$   Modbus Interface
' slv%   Modbus Slave address
' iMan$ Inverter Manufacturer
' iMod$ Inverter Model
' iVer$ Inverter Version
' iSer$ Inverter Serial Number
' iAddr% Inverter Modbus Device Address
' return negative value on error 
FUNCTION SunspecCommon(itf$,slv%,iMan$,iMod$,iOpt$,iVer$,iSer$,iAddr%)
 LOCAL err%, bId%, bAddr%, bLen%, rRsp$
 bId%=1
 bAddr%=0
 err%=SunspecBlock(itf$,slv%,bId%,bAddr%,bLen%)
 print "Block " bAddr%
 IF err% THEN
  SunspecCommon=err%
  EXIT FUNCTION
 ENDIF 
 err%=mbFunc(itf$,slv%,3,bAddr%+2-1,16,iMan$,2000) OR mbFunc(itf$,slv%,3,bAddr%+18-1,16,iMod$,2000) OR mbFunc(itf$,slv%,3,bAddr%+34-1,8,iOpt$,2000) 
 err%=err% OR mbFunc(itf$,slv%,3,bAddr%+42-1,8,iVer$,2000) OR mbFunc(itf$,slv%,3,bAddr%+50-1,16,iSer$,2000) OR mbFunc(itf$,slv%,3,bAddr%+66-1,1,rRsp$,500)
 IF err% THEN
  SunspecCommon=err%
  EXIT FUNCTION
 ENDIF  
 SunspecTrim(iMan$)
 SunspecTrim(iMod$)
 SunspecTrim(iOpt$)
 SunspecTrim(iVer$)
 SunspecTrim(iSer$)
 iAddr%=conv("bbe/u16",rRsp$)
 SunspecCommon=0
END FUNCTION

' Sunspec reader for Solaredge, SMA, Fronius
' itf$   Modbus Interface
' slv%   Modbus Slave address
' Iac1  AC Current Phase 1
' Iac2  AC Current Phase 2 (if available)
' Iac3  AC Current Phase 3 (if available)
' Uac1  AC Voltage Phase 1
' Uac2  AC Voltage Phase 2 (if available)
' Uac3  AC Voltage Phase 3 (if available)
' Pac   AC Power
' Fac   AC Frequency
' VA    Apparent Power
' VAR   Reactive Power
' PF    Power Factor
' E     AC Lifetime Energy Production
' Idc   DC Current
' Udc   DC Voltage
' Pdc   DC Power
' T1    Temperature 1 (Cabinet)
' T2    Temperature 2 (Coolant)
' T3    Temperature 3 (Transformer)
' T4    Temperature 4 (other)
' Status% Device Status
'  Solaredge only supports 1,2,4:
'  Fronius/SMA all:
'  1=off
'  2=auto shutdown
'  3=starting
'  4=normal operation
'  5=power limit activ
'  6=inverter shuting down
'  7=one or more error occured
'  8=standby
' Code% vendor specific code (see vendor sunspec documentation for details)
FUNCTION SunspecInverter(itf$, slv%, Iac1, Iac2, Iac3, Uac1, Uac2, Uac3, Pac, Fac, VA, VAR, PF, E, Idc, Udc, Pdc, T1, T2, T3, T4, Status%, Code%)
 LOCAL err%,bId%,bAddr%,bLen%,rRsp$,Iacsf,Uacsf,Pacsf,Facsf,VAsf,VARsf,PFsf,Esf,Idcsf,Udcsf,Pdcsf,Tsf
 ' Single Phase
 bAddr%=0 
 bId%=101
 err%=SunspecBlock(itf$,slv%,bId%,bAddr%,bLen%)
 IF err% THEN
  ' Split Phase
  bAddr%=0
  bId%=102
  err%=SunspecBlock(itf$,slv%,bId%,bAddr%,bLen%)
  IF err% THEN
   bAddr%=0
   bId%=103
   err%=SunspecBlock(itf$,slv%,bId%,bAddr%,bLen%)
   IF err% THEN
   bAddr%=0
   bId%=111
    err%=SunspecBlock(itf$,slv%,bId%,bAddr%,bLen%)
    IF err% THEN
    bAddr%=0
    bId%=112
     err%=SunspecBlock(itf$,slv%,bId%,bAddr%,bLen%)
     IF err% THEN
     bAddr%=0
     bId%=113
      err%=SunspecBlock(itf$,slv%,bId%,bAddr%,bLen%)
      IF err% THEN
       SunspecInverter=err%
       EXIT FUNCTION
      ENDIF
     ENDIF
    ENDIF
   ENDIF
  ENDIF  
 ENDIF
 
 IF bId%=101 OR bId%=102 OR bId%=103 THEN
  ' Normal format with scaling
  pNum%=id%-110
  err%=mbFunc(itf$,slv%,3,bAddr%+2-1,38,rRsp$,2000)
  IF err% THEN
   SunspecInverter=err%
   EXIT FUNCTION
  ENDIF  
  Iacsf=10.0^conv("bbe/i16",mid$(rRsp$,9,2))
  Iac1=conv("bbe/u16",mid$(rRsp$,3,2))*Iacsf
  Iac2=conv("bbe/u16",mid$(rRsp$,5,2))*Iacsf
  Iac3=conv("bbe/u16",mid$(rRsp$,7,2))*Iacsf
  Uacsf=10.0^conv("bbe/i16",mid$(rRsp$,23,2))
  Uac1=conv("bbe/u16",mid$(rRsp$,17,2))*Uacsf
  Uac2=conv("bbe/u16",mid$(rRsp$,19,2))*Uacsf
  Uac3=conv("bbe/u16",mid$(rRsp$,21,2))*Uacsf
  Pacsf=10.0^conv("bbe/i16",mid$(rRsp$,27,2))
  Pac=conv("bbe/i16",mid$(rRsp$,25,2))*Pacsf
  Facsf=10.0^conv("bbe/i16",mid$(rRsp$,31,2))
  Fac=conv("bbe/u16",mid$(rRsp$,29,2))*Facsf
  VAsf=10.0^conv("bbe/i16",mid$(rRsp$,35,2))
  VA=conv("bbe/i16",mid$(rRsp$,33,2))*VAsf
  VARsf=10.0^conv("bbe/i16",mid$(rRsp$,39,2))
  VAR=conv("bbe/i16",mid$(rRsp$,37,2))*VARsf
  PFsf=10.0^conv("bbe/i16",mid$(rRsp$,43,2))
  PF=conv("bbe/i16",mid$(rRsp$,41,2))*PFsf
  Esf=10.0^conv("bbe/u16",mid$(rRsp$,49,2))
  E=conv("bbe/u32",mid$(rRsp$,45,4))*Esf
  Idcsf=10.0^conv("bbe/i16",mid$(rRsp$,53,2))
  Idc=conv("bbe/u16",mid$(rRsp$,51,2))*Idcsf
  Udcsf=10.0^conv("bbe/i16",mid$(rRsp$,57,2))
  Udc=conv("bbe/u16",mid$(rRsp$,55,2))*Udcsf
  Pdcsf=10.0^conv("bbe/i16",mid$(rRsp$,61,2))
  Pdc=conv("bbe/i16",mid$(rRsp$,59,2))*Pdcsf
  Tsf=10.0^conv("bbe/i16",mid$(rRsp$,71,2))
  T1=conv("bbe/i16",mid$(rRsp$,63,2))*Tsf
  T2=conv("bbe/i16",mid$(rRsp$,65,2))*Tsf
  T2=conv("bbe/i16",mid$(rRsp$,67,2))*Tsf
  T2=conv("bbe/i16",mid$(rRsp$,69,2))*Tsf
  Status%=conv("bbe/u16",mid$(rRsp$,73,2))
  Code%=conv("bbe/u16",mid$(rRsp$,75,2)) 
 ELSE
  ' Floating point format
  pNum%=id%-100
  err%=mbFunc(itf$,slv%,3,bAddr%+2-1,49,rRsp$,2000)
  IF err% THEN
   SunspecInverter=err%
   EXIT FUNCTION
  ENDIF
  Iac1=conv("bbe/f32",mid$(rRsp$,5,2))
  Iac2=conv("bbe/f32",mid$(rRsp$,9,2))
  Iac3=conv("bbe/f32",mid$(rRsp$,13,2))
  Uac1=conv("bbe/f32",mid$(rRsp$,25,2))
  Uac2=conv("bbe/f32",mid$(rRsp$,29,2))
  Uac3=conv("bbe/f32",mid$(rRsp$,33,2))
  Pac=conv("bbe/f32",mid$(rRsp$,37,2))
  Fac=conv("bbe/f32",mid$(rRsp$,41,2))
  VA=conv("bbe/f32",mid$(rRsp$,45,2))
  VAR=conv("bbe/f32",mid$(rRsp$,49,2))
  PF=conv("bbe/f32",mid$(rRsp$,53,2))
  E=conv("bbe/u32",mid$(rRsp$,57,4))
  Idc=conv("bbe/f32",mid$(rRsp$,61,2))
  Udc=conv("bbe/f32",mid$(rRsp$,65,2))
  Pdc=conv("bbe/f32",mid$(rRsp$,69,2))
  T1=conv("bbe/f32",mid$(rRsp$,73,2))
  T2=conv("bbe/f32",mid$(rRsp$,77,2))
  T3=conv("bbe/f32",mid$(rRsp$,81,2))
  T4=conv("bbe/f32",mid$(rRsp$,85,2))   
  Status%=conv("bbe/u16",mid$(rRsp$,89,2))
  Code%=conv("bbe/u16",mid$(rRsp$,91,2)) 
 ENDIF 
 SunspecInverter=0
END FUNCTION

' Sunspec trim strings by removing 0 characters from name
SUB SunspecTrim(stg$)
 LOCAL i
 FOR i= 1 TO len(stg$)
  'print asc(mid$(stg$,i,1))
  IF mid$(stg$,i,1)=chr$(0) THEN
   stg$=left$(stg$,i-1)
   EXIT SUB
  ENDIF
 NEXT i
END SUB

' Modbus library comes here