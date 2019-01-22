Z80N instructions tests
=======================

Table with mnemonics + byte code and key to launch test
launch all tests

 ADD BC,$nnnn   ED 	36 	low 	high 	16
*ADD BC,A       ED 	33 			8
 ADD DE,$nnnn   ED 	35 	low 	high 	16
*ADD DE,A       ED 	32 			8
 ADD HL,$nnnn   ED 	34 	low 	high 	16
*ADD HL,A       ED 	31 			8
 LDDRX          ED 	BC 			21/16
*LDDX           ED 	AC 			16
 LDIRX          ED 	B4 			21/16
*LDIX           ED 	A4 			16
*LDPIRX         ED 	B7 			21/16
*LDWS           ED 	A5 			14
*MIRROR         ED 	24 			8
*MUL D,E        ED 	30 			8
 NEXTREG $rr,$n ED 	91 	register 	value 	20
 NEXTREG $rr,A  ED 	92 	register 		17
*OUTINB         ED 	90 			16
*PIXELAD        ED 	94 			8
*PIXELDN        ED 	93 			8
 PUSH $nnnn     ED 	8A 	high 	low 	23
*SETAE          ED 	95 			8
*SWAPNIB        ED 	23 			8
*TEST $nn       ED 	27 	value 		11

; 23 instructions
