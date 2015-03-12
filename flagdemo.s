
	;;  KES - 5/13/2009



	;; ****** constants ******

MainScanLineCount = 192
StripeCount = 13

	;; ****** parameters ******
	
clRed = $44
clWhite = $0e
clBlue = $84
clStar = clWhite
clBkg = $00

;StripeHeight = 5
StripeHeight = 9
FlagTopY = 30

ScanLinesLeftAtBottom = MainScanLineCount - FlagTopY - StripeCount * StripeHeight


	; ******  variables ******
	
.bss
StripeIndex:	.res 1
CurrentStripeColor:	.res 1
CurrentLeftColor:	.res 1
SaveStripeY:		.res 1
CurrentX0:		.res 1
CurrentX:		.res 1
ScanLineVector:		.res 2
WaveLineOffset:		.res 1
VWaveDT:		.res 1
VWaveT:			.res 1


.segment "VECTORS"



	.word Reset ; NMI 
	.word Reset ; RESET 
	.word Reset ; IRQ 

	
.code


	;; ******** register *******
VSYNC       = $00  ; 0000 00x0   Vertical Sync Set-Clear
VBLANK	    = $01  ; xx00 00x0   Vertical Blank Set-Clear
WSYNC	    = $02  ; ---- ----   Wait for Horizontal Blank
COLUBK      = $09  ; xxxx xxx0   Color-Luminance Background
	
.proc Reset
	sei
	ldx #0
	txs
	pha
	txa
Clear:
	dex
	bne Clear

	lda #0
	sta WaveLineOffset
	sta VWaveT

	lda #$77
	sta VWaveDT
.endproc

	
StartOfFrame :

	; Start of vertical blank processing 

	lda #0 
	sta VBLANK 

	lda #2 
	sta VSYNC 

	; 3 scanlines of VSYNCH signal... 

	sta WSYNC 
	sta WSYNC 
	sta WSYNC 
	lda #0 
	sta VSYNC

	; 37 scanlines of vertical blank... 

	ldy #37

:
	sta WSYNC
	dey
	bne :-

	jsr MainPic

	lda #%01000010 
	sta VBLANK ; end of screen - enter blanking 

	; 30 scanlines of overscan... 

;	.REPEAT 30 
;	sta WSYNC 

;	.ENDREPEAT 

	inc CurrentX0
	
	jmp StartOfFrame 




	

.code



.macro LeftSide ofs0, ofs1
	lda VStripLeft + 2 * ofs0 + ofs1, y
	sta COLUBK
.endmacro

.macro RightSide ofs0, ofs1
	lda VStripRight + 2 * ofs0 + ofs1, y
	sta COLUBK
.endmacro

.macro MakeScanLine ofs0, ofs1, ofs2, ofs3, ofs4, ofs5 
	lda #clBkg
	sta COLUBK
	nop
	nop
	LeftSide ofs0, 0
	LeftSide ofs1, 1
	RightSide ofs2, 1
	RightSide ofs3, 0		
	RightSide ofs4, 0
;	RightSide ofs5, 0
	iny			; need the 2 cycles
	lda #clBkg
	sta COLUBK
.endmacro


.proc MainPic
	
	
	ldx WaveLineOffset
	lda WaveLineLookupLo, x
	sta ScanLineVector
	lda WaveLineLookupHi, x
	sta ScanLineVector + 1

	ldy VWaveDT
	lda VWaveSpeed, y
	clc
	adc VWaveT
	sta VWaveT
	bcc SkipVWave
	
	inx
	cpx #5
	bne :+
	ldx #0
:
	stx WaveLineOffset

SkipVWave:
	iny
	sty VWaveDT
		
	ldx #clBkg
	stx COLUBK

	ldy #FlagTopY

:
	sta WSYNC
	dey
	bne :-
	
	; 192 scanlines of picture... 
	ldx #StripeHeight * 14
	ldy #0	

	sta WSYNC
ScanLine:
	txa
	lsr a
	bcc :+
	nop
:	
	jmp (ScanLineVector)

EndOfLine:	
	sta WSYNC

	dex
	bne ScanLine
	
	rts
.endproc

WaveLine0:
	MakeScanLine 0, 0, 1, 2, 3, 2
	jmp MainPic::EndOfLine
WaveLine1:
	MakeScanLine 0, 1, 2, 3, 2, 0
	jmp MainPic::EndOfLine
WaveLine2:
	MakeScanLine 1, 2, 3, 2, 0, 0
	jmp MainPic::EndOfLine
WaveLine3:
	MakeScanLine 2, 3, 2, 0, 0, 1
	jmp MainPic::EndOfLine
WaveLine4:
	MakeScanLine 3, 2, 0, 0, 1, 2
	jmp MainPic::EndOfLine
WaveLine5:
	MakeScanLine 2, 0, 0, 1, 2, 3
	jmp MainPic::EndOfLine


.rodata

.align $100

	
VStripLeft:
		.res StripeHeight, clBkg
	.repeat 7
		.res StripeHeight, clBlue
	.endrepeat

	.repeat 3
		.res StripeHeight, clWhite
		.res StripeHeight, clRed
	.endrepeat


VStripRight:	
		.res StripeHeight, clBkg ; shared between left and right

	.repeat 6
		.res StripeHeight, clRed
		.res StripeHeight, clWhite
	.endrepeat

		.res StripeHeight, clRed
		.res StripeHeight, clBkg

.define WaveLineList WaveLine0, WaveLine1, WaveLine2, WaveLine3, WaveLine4, WaveLine5  

WaveLineLookupLo:
	.lobytes WaveLineList
WaveLineLookupHi:
	.hibytes WaveLineList

VWaveSpeed:
	.repeat $40, I
		.byte $35+I, $35+I
	.endrepeat
	.repeat $40, I
		.byte $75-I, $75-I
	.endrepeat
	

	
	
	
