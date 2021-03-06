' This script is an example of the EMDO101 energy manager
' Please visit us at www.swissembedded.com
' Copyright (c) 2015-2016 swissEmbedded GmbH, All rights reserved.
' EMDO enocean library, based on Enocean EPP 2.6.3 specification
' the enocean protocol description, see referenced pages below in source code
' http://www.enocean-alliance.org/eep
' Eltako enocean devices (see page 10 and following)
' http://www.eltako.com/fileadmin/downloads/en/_main_catalogue/Gesamt-Katalog_ChT_gb_highRes.pdf
' Omnio enocean devices (protocol details see individual modules)
' http://www.awag.ch/ekat/page_de/awagpg_n_5.html
start:
 'Poll the stack 
 eoReceive()
 goto start
 
 ' Send a RPS/1BS message over enocean
 ' 
 ' eoTransmitRPS(&H50, &H30, &H00000000, &HFFFFFFFF, &H00) -> switch light on
 ' eoTransmitRPS(&H70, &H30, &H00000000, &HFFFFFFFF, &H00) -> switch light off
SUB eoTransmitRPS(db0%, st%, txid%, rxid%, enc%)
 ' Pls see enocean EEP 2.6.2 specification and ESP3 specification
 ' Type = 1 is radio
 ' Data = F6 (RORG = RPS / 1BS), switch state (0x50 = on, 0x70 = off)
 ' OptData = 03 (send) Boardcast FF FF FF FF, dBm (FF), 00 (unencrypted)	 
  msg$ = chr$(&hF6)
  msg$ += chr$(db0%)  
  msg$ += conv("u32/bbe",txid%)
  ' &H30 'T21=1, NU = 1
  ' &H20 'T21=1, NU = 0
  ' &H10 'T21=0, NU = 1   
  ' &H00 'T21=0, NU = 0   
  msg$ += chr$(st%) 
  ' Send  
  msg$ += chr$(&H03)
  ' Broadcast &Hffffffff or actuator id
  msg$+=conv("u32/bbe",rxid%)
  msg$ += chr$(&HFF)
  ' no encryption &H00
  msg$+=chr$(enc%)	
  num% = EnoceanTransmit(1, msg$)	
END SUB

' Poll this routine periodically to parse the enocean packets on the stack. EMDO can hold 8 packets on its stack.
SUB eoReceive()
 n%=EnoceanReceive(tp%,da$,oda$) 
 IF NOT n% THEN    
  'check rx packet 
  'e.g. F6002A42DF20 / 1FFFFFFFF360
  '     A5005081823D780 / 1FFFFFFFF560
  'first two characters are rorg  
  rorg%=asc(left$(da$,1))  
  select case rorg%
   case &hf6 
   ' RPS telegram: DB0, Sender ID, Status (page 11)    
    ' Rocker switches come here 	
	db0%=asc(mid$(da$,2,1))
	id%=conv("bbe/u32",mid$(da$,3,4))    
	st%=asc(mid$(da$,7,1))
	eoRxRocker(tp%,id%,db0%,st%)
	EXIT SUB
   case &hd5
    ' Contacts and Switches
	' 1BS telegram: DB0, Sender ID, Status (page 11)
	eoLog(tp%,da$,oda$,"eo rx")  
	EXIT SUB
   case &ha5  
    ' 4BS telegram: DB3-DB0, Sender ID, Status (page 12)
    ' Temperature Sensors
	' Temperature and Humidity Sensor
	' Barometric Sensor
	' Light Sensor
	' Occupancy Sensor
	' Light, Temperature and Occupancy Sensor
	' Gas Sensor
	' Room Operating Panel
	' Controller Status
	' Automated Meter Reading
	' Environmental Applications
	' Multi-Func Sensor
	' HVAC Components
	' Digital Input
	' Energy Management
	' Central Commands
	' Universal	
    eoLog(tp%,da$,oda$,"eo rx") 
    db3%=asc(mid$(da$,2,1))
	db2%=asc(mid$(da$,3,1))
	db1%=asc(mid$(da$,4,1))
	db0%=asc(mid$(da$,5,1))
	id%=conv("bbe/u32",mid$(da$,6,4))    
	st%=asc(mid$(da$,10,1))
	eoRxSensor(tp%,id%,db3%,db2%,db1%,db0%,st%)	
	EXIT SUB
   case &hd2
    ' VLD telegram: DB_13-DB0 (depending on length), Sender ID, Status, CRC8
    ' Room Control Panel
	' Electronic switches and dimmers
	' Sensors for Temperature, Illumination, Occupancy and smoke
	' Light, Switching + Blind Control
	' CO2, Humidity, Temperature, Day / NIght and Autonomy
	' Blinds Control for Position and Angle
    eoLog(tp%,da$,oda$,"eo rx")  
	db$=mid$(da$, 2,len(da$)-7)
	id%=conv("bbe/u32",mid$(da$,len(da$)-6,4))    
	st%=asc(mid$(da$,len(da$)-1,1))
	crc8%=asc(right$(da$,1))
	eoRxVariable(tp%,id%,db$,st%,crc8%)
    EXIT SUB
	case else
	 eoLog(tp%,da$,oda$,"eo unknown rx ")  
  end select
 ENDIF ' rx
END SUB

' log a telegram
SUB eoLog(tp%,da$,oda$,msg$)
 s$=msg$+" tp:"+str$(tp%)+" da:"
 for i=1 TO len(da$)
  h$=hex$(asc(mid$(da$,i,1)))
  IF len(h$)=1 THEN 
   h$="0"+h$
  ENDIF
  s$=s$+h$
 next
 s$=s$+" oda:"
 for i=1 TO len(oda$)
  h$=hex$(asc(mid$(oda$,i,1)))
  IF len(h$)=1 THEN 
   h$="0"+h$
  ENDIF
  s$=s$+h$
 next
 print s$
END SUB

' Receive Rocker Switch, 2 Rocker, page 15
' We get type info and two bits on status which help us to interpret
' Depending on switch type press and release events can be parsed
SUB eoRxRocker(tp%,id%,db0%,st%)
 select case (st% and &h30)
  case &H30 ' T21=1, NU = 1
   rock1%=(db0% and &he0)/32
   bow1%=(db0% and &h10)/16
   rock2%=(db0% and &h0e)/2
   ac2%=(db0% and &h1)
   print "eoRxRocker30:" hex$(id%) tp% rock1% bow1% rock2% ac2%   
   ' add your code here press event on rock1% (switch 1-4) ptm210
  case &H20 'T21=1, NU = 0
   num%=(db0% and &he0)/32
   bow%=(db0% and &h10)/16  
   print "eoRxRocker20:" hex$(id%) tp% num% bow%  
   ' add your code here for release event on bow% ptm210
  case &H10 'T21=0, NU = 1   
   rock1%=(db0% and &he0)/32
   bow1%=(db0% and &h10)/16
   rock2%=(db0% and &h0e)/2
   ac2%=(db0% and &h1)
   print "eoRxRocker10:" hex$(id%) tp% rock1% bow1% rock2% ac2%   
   ' add your code here  
  case &H00 'T21=0, NU = 0   
   num%=(db0% and &he0)/32
   bow%=(db0% and &h10)/16  
   print "eoRxRocker00:" hex$(id%) tp% num% bow%  
   ' add your code here  
 end select
END SUB

' Receive Sensor info, page 15
SUB eoRxSensor(tp%,id%,db3%,db2%,db1%,db0%,st%)	
 print "eoRxSensor:" hex$(id%) tp% db3% db2% db1% db0% st%
 ' add your code here you can make subcalls here to your own routines
 select case id%
  case &H01823D78 ' your sensor id (from sensor backside)
   ' Enocean sensor STM3xx from demo kit
   ' 255=0 degree celsius, 0=40 degree celsius 
   print db1% (255-db1%)/255.0*40.0
 end select 
 ' Pressac Version 1 CT Clamp A5-12-01
 ' http://www.pressac.com/current-transducer-enocean-ct-clamp
 ' scale% = db0 AND 3 
 ' meter = (db3%*256 + db2%)*256 + db1%
 ' if scale% = 1 then
 '  meter = ((db3%*256 + db2%)*256 + db1%)*0.1
 ' else if scale% = 2 then
 '  meter = ((db3%*256 + db2%)*256 + db1%)*0.01
 ' else if scale% = 3 then
 '  meter = ((db3%*256 + db2%)*256 + db1%)*0.001
 ' else 
 '  meter = ((db3%*256 + db2%)*256 + db1%)
 ' endif
 ' cum% = db0% and 4
 ' lrn% =  not (db0% and 8)
 
 ' The following infos are taken from the Eltako documentation 
 ' referenced in the header (see page 10))
 ' Eltako FABH65S+FBH65B+FBH65S+FBH65TFB
 ' lux = db2% *2048.0/255.0
 ' lrn% = not (db0% and 8)
 ' motion% = not (db0% and 2)
 
 ' FAFT60+FIFT65S+FBH65TFB
 ' charge = db3% * 4.0 / 155.0
 ' humidity = db2% * 100.0 / 250.0
 ' temp = (db1% * 80.0 / 250.0)-20.0
 ' lrn% = not (db0% and 8)
 
 ' FAH60+FAH65S+FIH65S+FAH60B
 ' lux  = db3%*100.0
 ' lux2 = 300 + db2%*(30000-300)/255.0
 ' lrn% =  not (db0% and 8)
 
 ' FIH65B 
 ' lux = db2%*1024.0/255.0
 ' lrn% =  not (db0% and 8)
 
 ' FASM60+FSM14+FSM61+FSU65D
 ' status = db3%
 
 ' FSM60B
 ' status1 = db3%
 ' status2 = db1%

 ' FCO2TF65
 ' humidity = db3%*100.0/200.0*40
 ' co2      = db2%*2550.0/255.0
 ' temperature = db1%*51.0/255.5
  
 ' FKC+FKF
 ' status = db3%
 
 ' FRW
 ' status = db3%
 
 ' FSS12+FWZ12+FWZ61 
 ' value = db3% * &HFFFF
 ' value += db2% * &HFF
 ' value += db1%
 ' tariff = db0 and 16
 ' LRN_Button = db0 and 8
 ' switchover = db0 and 4
 '  if(db0% = 0x09){
 '     meterstatus$ = "meter status normal rate"
 ' }
 ' else if(db0% = 0x19){
 '     meterstatus$ = "meter status off-peak rate"
 ' }
 '  else if(db0% = 0x0C){
 '     meterstatus$ = "momentary power in W, normal"
 ' }
 ' else if(db0% = 0x1C){
 '     meterstatus$ = "momentary power in W, off-peak"
 ' }
 
 ' F4T65+FT4F+FT55
 ' status = db3%
 
 ' FTF65S
 ' temperature = (&HFF - db1%)*40.0/255.0
 ' lrn% = not (db9% and 8)
 
 ' FHF
 ' windowsstate% = db3%
 
 ' FTK+FTKB
 ' if db3% = &H09 then
 '     contact% = 0
 ' 
 ' else if db3% = &H08 then
 '     contact% = 1
 ' endif
 
 ' FTKE
 ' if db3% = &HF0 then
 '     windows% = 0
 ' 
 ' else if db3% = &HFE then
 '     windows% = 1
 ' endif
 
 ' FTR65DS+FTR65HS+FUTH65D
 ' select case db3%
 '    case &H00
 '        nightreduct% = &h0
 '    case &H06
 '        nightreduct% = &h1
 '    case &H0C
 '        nightreduct% = &h2
 '    case &H13
 '        nightreduct% = &h3
 '    case &H19
 '        nightreduct% = &h4
 '    case &H1F
 '        nightreduct% = &h5
 ' end select
 ' ref_temperature% = (&HFF - db1%)*40.0
 ' temperature% = (&HFF - db1%)*40.0
 ' lrn% = not (db0% and 8)
 
 ' FTR78S (EEP: A5-10-03)
 ' ref_temperature% = 8 + db2%*(22.0)/255.0
 ' temperature%      = (255.0 -db1%)*40.0/255.0
 
 ' FTS14EM (only telegrams for the Eltako-RS485-Bus)
 ' select case (db3%)
 '     case &H70
 '     controlof$ = "+E1"
 '     case &H50
 '     controlof$ = "+E2"
 '     case &H30
 '     controlof$ = "+E3"
 '     case &H10
 '     controlof$ = "+E4"
 '     case &H70
 '     controlof$ = "+E5"
 '     case &H50
 '     controlof$ = "+E6"
 '     case &H30
 '     controlof$ = "+E7"
 '     case &H10
 '     controlof$ = "+E8"
 '     case &H70
 '     controlof$ = "+E9"
 '     case &H50
 '     controlof$ = "+E10"
 ' end select
 
 ' FWS61 (EEP: A5-13-01 u. 02)

 'DSZ14DRS, DSZ14WDRS, FWZ14, FSDG14 (EEP: A5-12-01)
 ' value% = db3% * &HFFFF
 ' value% += db2% * &HFF
 ' value% += db1%
 ' tariff% = db0 and 16
 ' LRN_Button% = db0 and 8
 ' switchover% = db0 and 4
 '  if db0% = 0x09 then
 '     meterstatus$ = "meter status normal rate"
 ' 
 ' else if db0% = 0x19 then
 '     meterstatus$ = "meter status off-peak rate"
 ' 
 ' else if db0% = 0x0C then
 '     meterstatus$ = "momentary power in W, normal"
 ' 
 ' else if db0% = 0x1C then
 '     meterstatus$ = "momentary power in W, off-peak"
 ' endif

 ' FSR61VA, FSVA-230V (EEP: A5-12-01)
 ' value% = db3% * &HFFFF
 ' value% += db2% * &HFF
 ' value% += db1%
 ' LRN_Button% = db0 and 8
 ' switchover% = db0 and 4
 ' if db0% = 0x0C then
 '     meterstatus$ = "momentary power in W, normal"
 ' endif

 ' FZS
 ' status% = db3%
 
 ' FLC61-230V
 ' lrn% = not (db0% and 8)
 ' blksw% = db0% and 4
 ' swoutput% = db0% and 1
 
 ' FSB14, FSB61, FSB71
 ' runtime% = db2%
 ' command% = db1%
 ' lrn% = not (db0% and 8)

 ' FHK61SSR
 ' pwmval% = db2%
 ' pwmbasic% = db1%*10
 ' lrn% = not (db0% and 8)
 ' repeat% = db0% and 2
 ' pwmon%  = db0% and 1

 ' FSR14-2x, FSR14-4x, FSR14SSR, FSR71
 ' lrn% = not (db0% and 8)
 ' blksw% = db0% and 4
 ' swoutput% = db0% and 1

 ' FUD14, FUD14-800W, FUD61NP, FUD61NPN, FUD71,
 ' FSG14/1-10V, FSG71/1-10V, FRGBW71L, FSUD-230V
 ' dimval% = db2%
 ' if db1% = &H0 then
 '    dimspeed$ = "dimming normal"
 ' else if db1% = 0x01 then
 '    dimspeed$ = "dimming fast"
 ' else if db1% = 0xFF then
 '    dimspeed$ = "dimming slow"
 ' endif
 ' lrn% = not (db0% and 8)
 ' dim_on% = db0% and 1
 ' dim_block% = db0% and 4

 ' FADS60-230V 
 ' if db3% = &H70 then
 '    relay$ = "relay on"
 ' else if db3% = 0x01 then
 '    relay$ = "relay off"
 ' else
 '    relay$ = "relay release"
 ' endif

 ' FFR61-230V, FZK61NP-230V
 ' select case (db3%)
 '     case &H70
 ' 	    channelst$ = "channel 1 ON"
 ' 	case &H50
 ' 	    channelst$ = "channel 1 OFF"
 ' 	case &H30
 ' 	    channelst$ = "channel 2 ON"
 ' 	case &H10
 ' 	    channelst$ = "channel 2 OFF"
 ' 	case &H00
 ' 	    channelst$ = "released"
 ' end select

 ' FHK61U-230V
 ' if db3% = &H70 then
 '    relay$ = "relay on"
 ' else if db3% = 0x01 then
 '    relay$ = "relay off"
 ' else
 '    relay$ = "relay release"
 ' endif

 ' FHK61-230V, FHK61SSR-230V
 ' select case (db3%)
 '     case &H70
 ' 	    mode$ = "normal mode"
 ' 	case &H50
 ' 	    mode$ = "night reduction"
 ' 	case &H30
 ' 	    mode$ = "setback mode"
 ' end select

 ' FHK61SSR-230V
 ' select case (db3%)
 '     case &H70
 ' 	    signalmode$ = "thaw signal input active"
 ' 	case &H50
 ' 	    signalmode$ = "thaw signal input inactive"
 ' end select

 ' FMS61NP-230V
 ' select case (db3%)
 '     case &H70
 ' 	    channelst$ = "channel 1 ON"
 ' 	case &H50
 ' 	    channelst$ = "channel 1 OFF"
 ' 	case &H30
 ' 	    channelst$ = "channel 2 ON"
 ' 	case &H10
 ' 	    channelst$ = "channel 2 OFF"
 ' 	case &H00
 ' 	    channelst$ = "released"
 ' end select
 
 ' FMZ61-230V
 ' if db3% = &H70 then
 '    relay$ = "relay on"
 ' else if db3% = 0x01 then
 '    relay$ = "relay off"
 ' else
 '    relay$ = "relay release"
 ' endif

 ' FSB61NP-230V, FSB71
 ' select case (db3%)
 '  case &H70
 ' 	    position$ = "upper stop position"
 ' 	case &H50
 ' 	    position$ = "lower stop position"
 ' 	case &H10
 ' 	    position$ = "Start up"
 ' 	case &H20
 ' 	    position$ = "Start down"
 ' end select

 ' FSR61NP-230V, FSR61-230V, FSR61/8-24V, FSR61LN-230V,
 ' FSR61VA-10A, FTN61NP-230V, FLC61NP-230V, FSSA-230 V,
 ' FSVA-230 V, FSR71
 ' if db3% = &H70 then
 '    relay$ = "relay on"
 ' else if db3% = 0x50 then
 '    relay$ = "relay off"
 ' else
 '    relay$ = "relay release"
 ' endif

 ' FUD61NP-230V, FUD61NPN-230V, FUD71, FSG71/1-10V, FRGBW71L,
 ' FSUD-230 V
 ' ORG5
 ' select case (db3%)
 '  case &H70
 ' 	    dimstat$ = "dimmer on"
 ' 	case &H50
 ' 	    dimstat$ = "dimmer off"
 ' end select
 ' ORG = 0x07
 ' dimval = db2%
 ' select case (db3%)
 '  case &H09
 ' 	    dimstat$ = "dimmer on"
 ' 	case &H08
 ' 	    dimstat$ = "dimmer off"
 ' end select
 
 ' FUD14, FUD14/800W, FSG14/1-10V
 ' ORG5
 ' select case (db3%)
 '  case &H70
 ' 	    dimstat$ = "dimmer on"
 ' 	case &H50
 ' 	    dimstat$ = "dimmer off"
 ' end select
 ' ORG = 0x07
 ' dimval% = db2%
 ' select case (db3%)
 '  case &H09
 ' 	    dimstat$ = "dimmer on"
 ' 	case &H08
 ' 	    dimstat$ = "dimmer off"
 ' end select

 ' FSB14
 ' select case (db3%)
 '  case &H70
 ' 	    position$ = "upper stop position"
 ' 	case &H50
 ' 	    position$ = "lower stop position"
 ' 	case &H10
 ' 	    position$ = "Start up"
 ' 	case &H20
 ' 	    position$ = "Start down"
 ' end select

 ' F4HK14, FHK14, FAE14LPR, FAE14SSR
 ' select case (db3%)
 '  case &H70
 ' 	    mode$ = "normal mode"
 ' 	case &H50
 ' 	    mode$ = "night reduction"
 ' 	case &H30
 ' 	    mode$ = "setback mode"
 ' 	case &H10
 ' 	    mode$ = "OFF"
 ' end select

 ' FMSR14
 ' FSU14
 ' if db3% = &H70 then
 '    switch$ = "switch ON"
 ' else if db3% = 0x50 then 
 '    switch$ = "switch OFF"
 ' else
 '    switch$ = "switch OFF"
 ' endif
 
 ' FSR14-2x, FSR14-4x, FSR14SSR, FFR14, FMS14, FMZ14, FTN14,
 ' FZK14, F2L14
 ' if db3% = &H70 then
 '    relay$ = "relay on"
 ' else if db3% = 0x50 then
 '    relay$ = "relay off"
 ' else
 '    relay$ = "relay release"
 ' endif

END SUB

' Receibe variable length telegram
SUB eoRxVariable(tp%,id%,db$,st%,crc8%)
print "eoRxSensor:" hex$(id%) tp% db3% db2% db1% db0% st%
 ' add your code here you can make subcalls here to your own routines
 ' Versions 2&3 Single Phase CT Clamps -  D2-32-00
 ' http://www.pressac.com/enocean-single-phase-ct-clamp-v2
 ' pf% = asc(left$(db$,1)) AND 128
 ' div% = asc(left$(db$,1)) 64
 ' meter = (asc(mid$(db$,2,1))*16)+ (asc(right$(db$,1))/16)
 ' if div% then
 '   meter = meter * 0.1
 ' endif
 
 ' Version 2 &3 Dual Phase CT Clamps - D2-32-01         
 ' http://www.pressac.com/2-phase-current-transducer-enocean-ct-clamp
 ' pf% = asc(left$(db$,1)) AND 128
 ' div% = asc(left$(db$,1)) 64
 ' meter1 = (asc(mid$(db$,2,1))*16)+ (asc(mid$(db$,3,1))/16)
 ' meter2 = ((asc(mid$(db$,3,1)) AND &H0f)*256)+ asc(right$(db$,1))
 ' if div% then
 '   meter1 = meter1 * 0.1
 '   meter2 = meter2 * 0.1
 ' endif
 
 ' Version 2 &3 Three phase CT Clamps - D2-32-02
 ' http://www.pressac.com/3-phase-current-transducer-enocean-ct-clamp
 ' pf% = asc(left$(db$,1)) AND 128
 ' div% = asc(left$(db$,1)) 64
 ' meter1 = (asc(mid$(db$,2,1))*16)+ ((asc(mid$(db$,3,1)) and &Hf0) /16)
 ' meter2 = ((asc(mid$(db$,3,1)) AND &H0f)*256)+ asc(mid$(db$,4,1))
 ' meter3 = (asc(mid$(db$,5,1))*16)+ (asc(right$(db$,1))/16)
 ' if div% then
 '   meter1 = meter1 * 0.1
 '   meter2 = meter2 * 0.1
 '   meter3 = meter3 * 0.1
 ' endif
 
END SUB