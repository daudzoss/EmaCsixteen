;;; EmaC=s alternative screen editor for the Commodore 16 in 1.5KB
;;; Copyright (C) Daud A. Zoss
;;; 
;;; This program is free software: you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation, either version 3 of the
;;; License, or (at your option) any later version.
;;; 
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;; 
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;; 
;;; Contact zoss@hp.com or 16399 W Bernardo Dr San Diego CA 92127 USA
	
;;; build syntax with xa65
;;; 
;;;	C16:  xa -M main.asm -o EmaC=s.prg -DINSERT
;;;	C128: TBD, not attempted yet
;;; 
;;; (-DINSERT aliases shift-DEL to Esc-x O)
;;; (-M option ignores comments to EOL rather than colon-terminated)

MAJOR  = "0"
MINOR  = "9"
MINOR0 = "0"

;;; // 264 memory map standard names
TXTTAB = $2b		; char* TXTTAB;// pointer to start of BASIC text
PNTR   = $ca		; volatile uint8_t PNTR;// current cursor logical column
TBLX   = $cd		; volatile uint8_t TBLX;// current cursor absolute row
UNUSED = $d8		; void* UNUSED;// unclaimed space above speech, >4 bytes
RS232  = $03f7		; char* RS232; // RS232 text buffer, 124 bytes
RPTFLG = $0540		; volatile uint8_t RPTFLG; // key repeat control
SHFLAG = $0543		; volatile uint8_t SHFLAG; // modifier key indicator
SCBOT  = $07e5		; volatile uint8_t SCBOT;  // bottom row of window, 0-24
SCTOP  = $07e6		; volatile uint8_t SCTOP   // top row of window, 0-24
SCLF   = $07e7		; volatile uint8_t SCLF;   // left column of window, <39
SCRT   = $07e8		; volatile uint8_t SCRT;   // right column of window,<39
INSFLG = $07ea		; volatile uint8_t INSFLG; // 00=legacy, ff=auto-insert
LSTX   = $07f6		; volatile uint8_t LSTX;   // last keyscan row (C-5=C-e)
TEDSCR = $0c00		; volatile char* TEDSCR;
*      = $0fe8		; //main()@last 24 bytes of "offscreen" RAM before BASIC
TEDCHR = $ff13		; volatile uint8_t TEDCHR; // 
CHROUT = $ffd2		; extern void CHROUT(char); extern char CHRIN(void);
CHRIN  = $ffe4		; #define putchar CHROUT

;;; // 264 color/keyboard constants
ORANGE = 88
GREEN  = 58

;;; PETSCII constants
RETURN = 13
CRSRDN = 17
ULHOME = 19
ESC    = 27
CRSRRT = 29
BLANK  = 32
CRSRUP = 145
CRSRLF = 157

;;; // variables within the UNUSED space, and shorthand names for the above
CP = UNUSED+0 			;#define CP ((char*)(UNUSED+0))  // Char Pointer
AC = UNUSED+2 			;#define AC ((uint8_t)(UNUSED+2))// ACcumulator
K  = UNUSED+3 			;#define K  ((uint8_t)(UNUSED+3))// Key input
CC = UNUSED+4 			;#define CC ((uint8_t)(UNUSED+4))// Cursor Color

YANKLEN = RS232			;#define YANKLEN (&RS232+0) 
				; // use 41 for a buffer, 83 for const str:
				; // $03f7 "YANKLEN" bits 5:0, CR flag in bit 7
				; // $03f8~041f "YANKBUF" for screen line buffer
				; // $0420~0447 "TOPBAR" for 40 codes of inverse
				; // $0448~046f "BOTBAR" for 40 codes of inverse
				; // $0470~0472 'O','V','R' when not insert mode
YANKBUF = YANKLEN+1		;#define YANKBUF (YANKLEN+1)
LINELEN = 40			;#define LINELEN (40)
TOPBAR	= YANKBUF+LINELEN	;#define TOPBAR (YANKBUF+LINELEN)
BOTBAR	= TOPBAR+LINELEN	;#define BOTBAR (TOPBAR+LINELEN)
OVRWRIT = BOTBAR+LINELEN	;#define OVERWRIT (BOTBAR+LINELEN)

;;; put the decimal address of resume() in the BASIC stub
RESADR0 = main/1000		;#define RESADR0 (main/1000)
ADSOFAR = RESADR0*1000		;
REMAIND = main-ADSOFAR		;#define REMAIND0 (main-(RESADR0*1000))
RESADR1 = REMAIND/100		;#define RESADR1 (REMAIND0/100)
-ADSOFAR= RESADR1*100		;
-REMAIND= REMAIND-ADSOFAR	;#define REMAIND1 (REMAIND0-(RESADR1*100))
RESADR2 = REMAIND/10		;#define RESADR2 (REMAIND1/10)
-ADSOFAR= RESADR2*10		;
-REMAIND= REMAIND-ADSOFAR	;#define REMAIND (REMAIND1-(RESADR2*10))
CHRADR0 = RESADR0 + "0"		;#define CHRADR0 (RESADR0 + '0')
CHRADR1 = RESADR1 + "0"		;#define CHRADR1 (RESADR1 + '0')
CHRADR2 = RESADR2 + "0"		;#define CHRADR2 (RESADR2 + '0')
CHRADR3 = REMAIND + "0"		;#define CHRADR3 (RESADR3 + '0')

	.text
*=*-2
header	.byte	<movbas,>movbas	;// first two bytes in file must be load address
	
movbas	lda	#>LASTADR	;void main(void(*start_adr)(void)) {    /*0fe8*/
	sta	1+TXTTAB	; if (start_adr == resume)              /*0fea*/
	lda	#<LASTADR	;  resume();                            /*0fec*/
	sta	TXTTAB		; else                                  /*0fee*/
main	lda	1+TXTTAB	;  while (TXTTAB < LASTADR)             /*0ff0*/
	cmp	#>LASTADR	;   TXTTAB = LASTADR;                   /*0ff2*/
	bcc	movbas		;                                       /*0ff4*/
	bne	main2		;                                       /*0ff6*/
	lda	TXTTAB		;                                       /*0ff8*/
	cmp	#<LASTADR	;                                       /*0ffa*/
	bcc	movbas		; exit(main2());                        /*0ffc*/
	bcs	main2		;}                                      /*0ffe*/
	
syscmd	.byte	$00	    	;
syscmd1	.byte	$0b,$10,$00 	;// 0                                   
	.byte	$00,$9e		;//   SYS                               
	.byte	CHRADR0,CHRADR1 ;//      40                             
	.byte	CHRADR2,CHRADR3 ;//        80                           
	.byte	$00,$00,$00	;// (i.e. main2()) allows RUN from BASIC/*100a*/

main2	jmp	main3		;void main2 (void(*start_adr)(void)) { main3();}

KEYLIST .byte	146		;static uint8_t KEYLIST[] = { 146, // C-0
	.byte	144		;			      144, // C-1
	.byte	5		;			      5,   // C-2
	.byte	28		;			      28,  // C-3
	.byte	159		;			      159, // C-4
	.byte	156		;			      156, // C-5
	.byte	30		;			      30,  // C-6
	.byte	31		;			      31,  // C-7
	.byte	158		;			      158, // C-8
	.byte	18		;			      18,  // C-9
	.byte	9		;			      9,   // C-i =>Tab
	.byte	24		;			      24,  // C-x
	.byte	2		;			      2,   // C-b => Lf
	.byte	6		;			      6,   // C-f => Rt
	.byte	16		;			      16,  // C-p => Up
	.byte	14		;			      14,  // C-n => Dn
	.byte	1		;			      1,   // C-a =>SOL
	.byte	0		;/* really 5, special case: */0,   // C-e =>EOL
	.byte	27		;			      27,  // C-[/Esc
	.byte	7		;			      7,   // C-g
	.byte	11		;			      11,  // C-k =>Cut
	.byte	15		;			      15,  // C-o =>Opn
	.byte	20		;                             20,  // C-t =>Tsp
#ifdef INSERT
	.byte	148		;			      148, // Insert
#endif
	.byte	4		;			      4,   // C-d =>Rub
	.byte	25		;			      25}; // C-y =>Ynk
	.byte	12		;			      12,  // C-l =>Drw

KEYVEC	.byte	<cdigit,>cdigit ; static char(*KEYVEC)(char)[] = { cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<cdigit,>cdigit ;				   cdigit,
	.byte	<ctrl_i,>ctrl_i ;				   ctrl_i,
	.byte	<ctrl_x,>ctrl_x ;				   ctrl_x,
	.byte	<ctrl_b,>ctrl_b ;				   ctrl_b,
	.byte	<ctrl_f,>ctrl_f ;				   ctrl_f,
	.byte	<ctrl_p,>ctrl_p ;				   ctrl_p,
	.byte	<ctrl_n,>ctrl_n ;				   ctrl_n,
	.byte	<ctrl_a,>ctrl_a ;				   ctrl_a,
	.byte	<ctrl_e,>ctrl_e ;				   ctrl_e,
	.byte	<escape,>escape ;				   escape,
	.byte	<ctrl_g,>ctrl_g ;				   ctrl_g,
	.byte	<ctrl_k,>ctrl_k ;				   ctrl_k,
	.byte	<ctrl_o,>ctrl_o ;				   ctrl_o,
	.byte	<ctrl_t,>ctrl_t ;				   ctrl_t,
#ifdef INSERT
	.byte	<insert,>insert ;				   insert,
#endif
	.byte	<ctrl_d,>ctrl_d ;				   ctrl_d,
	.byte	<ctrl_y,>ctrl_y ;				   ctrl_y};
	.byte	<repaint,>repaint;				   repaint,

resume	jsr	hygiene		;void resume(void) {
	lda	#0		; hygiene();
zeroacc sta	AC		; AC = 0; 
zerobuf sta	YANKLEN		; YANKLEN = 0; 
fullscr sta	SCLF		; SCLF = 0;  // not yet working w/reduced screen
	ldx	#39		;
	stx	SCRT		; SCRT = 0; 
	ldx	#23		;
	jsr	top_bot		; top_bot(a = 0, x=23); 

	jsr	printEv		; printEv(); // scroll screen up to print below
	lda	#CRSRUP		;
	jsr	CHROUT		; putchar(145); // cursor follows text up

	jsr	repaint		; repaint(); 
	jsr	crsron		; crsron(); 

mainlp	jsr	getchar		; do {
	sta	K		;  K = getchar(); 
	cmp	#5		;
	bne	inpdone		;
	lda	LSTX		;
	clc			;
	adc	#256-14		;
	bne	inpdone		;  if (K == 5 && LSTX = 14) // was C-e, not c-2
	sta	K		;   K = 0; 

inpdone jsr	crsroff		;  crsroff(); 
	lda	K		;
	ldy	#KEYVEC-KEYLIST ;  for (uint8_t	 y = KEYVEC-KEYLIST; y > 0; y--)
inpfind cmp	KEYLIST-1,y	;   if (K == KEYLIST[y-1])
	beq	special		;    goto special; 
	dey			;
	bne	inpfind		;
	beq	normal		;  goto normal;// skip over special-char handler

jumper	jmp	(CP)		;
special tya			; special:
	pha			;  uint8_t stack = y;
	asl			;
	tay			;
	lda	KEYVEC-2,y	;
	sta	CP		;
	lda	KEYVEC-1,y	;
	sta	1+CP		;  CP = KEYVEC[(y<<1)/2];
	pla			;
	tay			;  y = stack;
	lda	K		;
	jsr	jumper		;
	sta	K		;  K = (*CP)(K, y);// 0 (or K modified) into "a"

	cmp	#3		;
	bne	normal		;  if (K == 3) // C-x C-c unloads from memory:
	ldx	#>syscmd1	;
	stx	1+TXTTAB	;
	ldx	#<syscmd1	;
	stx	TXTTAB	     	;
	rts			;   exit(TXTTAB = (char*)syscmd1); // i.e. $1001
	
normal	ora	#1		; normal:
	cmp	#ESC		;  if (K == 26 || K == 27) // Esc-Esc or C-z
	beq	quit		;   break;
	cmp	#ULHOME		;
	bne	checkac		;
	
	lda	#0		;  if (K == 18 || K == 19) // Home
	sta	AC		;   AC = 0;
	lda	PNTR		;  if ((K != 19) // prevent HOME key pressed at 
	bne	checkac		;      ||
	lda	TBLX		;      (PNTR != 0) // upper left of screen
	cmp	SCTOP		;      ||
	beq	noprint		;      (TBLX != SCTOP)) { 

checkac	lda	K      		;
	beq	noprint		;   if (K) {
	jsr	ACmin1		;
printk	lda	K		;    for (AC = AC ? AC : 1; AC > 0; AC--)
	jsr	CHROUT		;     putchar(K); 
	dec	AC		;
	bne	printk		;    AC = 0;
	lda	#0		;    repaint(); 
	sta	AC		;   }
	jsr	repaint		;  } else {
	
noprint jsr	recrsr		;   recrsr(); 
	jsr	crsron		;   crsron(); 
	jmp	mainlp		;  }

quit	jsr	crsroff		; } while (1);
	jsr	fullwin		; fullwin();
goodbye lda	#0		; crsroff();        
	ldx	#24		; goodbye();
	jsr	top_bot		;}

	jsr	printEw		;void goodbye(void) {
	lda	#9		; top_bot(a = 0, x = 24);// fullscreen then down
	jsr	CHROUT		; printEw();

	ldy	#$28		; putchar(9); // allow Shift-C=
goodby1 lda	TOPBAR-1,y	; for (uint8_t y = 40; y > 0; y--)
	sta	TEDSCR-1,y	;  TEDSCR[y-1] = TOPBAR[y-1];
	dey			;
	bne	goodby1		;
	inc	SCTOP		; SCTOP++;// preserve EXITSTR on top screen line
	rts			;} // back from SYS call or to buffer setup stub

hygiene cld			;void hygiene(void) {
	lda	#8		; //clear decimal mode when restarting execution
	jsr	CHROUT		; putchar(8); // disallow Shift-C= while in edit
;	lda	#0		;
;	sta	RPTFLG		; RPTFLG = 0; // only cursor-movement key repeat
	rts			;}

cdigit	dey			;char cdigit(unit8_t a, uint8_t y) {
	sty	K		; K = --y;
	asl	AC		;
	lda	AC		; /*AC = AC*2 */
	asl			;
	asl			;
	clc			; /* a = AC*8 */
	adc	AC		; AC *= 10;
	clc			;
	adc	K		; AC += K; 
	cmp	#100		;
	bcc	cdigitx		; if (AC > 99)
	lda	#0		;  AC = 0;
cdigitx	sta	AC		; return reaccum();
	jmp	reaccum		;}

ctrl_b	lda	#CRSRLF		;char ctrl_b(char a) { return CRSRLF;
	rts			;} 

ctrl_f	lda	#CRSRRT		;char ctrl_f(char a) { return CRSRRT;
	rts			;} 

ctrl_p	lda	#CRSRUP		;char ctrl_p(char a) { return CRSRUP;
	rts			;} 

ctrl_n	lda	#CRSRDN		;char ctrl_n(char a) { return CRSRDN;
	rts			;} 

ctrl_a	jsr	printE		;char ctrl_a(char a) {
	lda	#0		; putchar(27);
	sta	AC		; AC = 0;
	lda	#64+10		; return 'J';
	rts			;} 

ctrl_e	jsr	printEk		;char ctrl_e(char a) {
	jsr	findcsr		; printEk(); // to end of lin
	ldy	#0		;
	sty	AC		; AC = 0;
	lda	(CP),y		;
	cmp	#BLANK		;
	bne	ctrl_e2		; if ((*findcsr() == BLANK) // not atop nonblank
ctrl_e1 tya			;
	rts			;
ctrl_e2 ldx	PNTR		;     || (PNTR == SCRT)) // along right margin
	cmp	SCRT		;  return 0;
	beq	ctrl_e1		; else
	lda	#CRSRRT		;  return CRSRRT; 
ctrl_e3 rts			;}

newsize jsr	top_bot		;char newsize(uint8_t a, uint8_t x) {
	lda	#ULHOME		; putchar(19); print_l(); // preclude HOME+HOME
	jsr	CHROUT		; return repaint();
	jsr	print_l		;}
	
repaint jsr	findbar		;char repaint() {
	ldy	#LINELEN	; findbar(CP);
repain1 lda	BOTBAR-1,y	; for (y = LINELEN; y > 0; y--)
	cmp	#128+27		;
	bcs	notlogo		;  if ((BOTBAR[y - 1] & 0x7f <= 'Z') &&
	lda	TEDCHR		;
	and	#$04		;
	beq	notlcas		;      (TEDCHR & 4 == 0))//upcase "EMAC=S Vx.xx"
	lda	#$40		;
notlcas	ora	BOTBAR-1,y	;   CP[y - 1] = BOTBAR[y - 1] | 0x40;
notlogo	dey			;  else
	sta	(CP),y		;   CP[y - 1] = BOTBAR[y - 1];
	bne	repain1		;
	lda	INSFLG		;
	bne	_recrsr		; if (INSFLG == 0)
	ldy	#11		;
repain2 lda	OVRWRIT-9,y	;  for (y = 11; y > 8; y--)
	sta	(CP),y		;   CP[y] = y[OVRWRIT - 9];
	dey			;
	cpy	#8		; return _recrsr(CP);
	bne	repain2		;}// call after bar move, C-g or ins-mode change

_recrsr lda	#2		;char _recrsr() { // assumes CP @col 0
	jsr	inc_cp		; inc_cp(a = 2);
	lda	TBLX		;
	sec			; // comment me out to display absolute row #s
	sbc	SCTOP		; // in the indicator bar (instead of logical)
	jsr	printdd		; printdd(a = TBLX - SCTOP, CP);
	lda	#3		; inc_cp(a = 3);
	jsr	inc_cp		; printdd(a = PNTR, CP); // CP now @col 5
	lda	PNTR		; return _reaccu(CP);
	jsr	printdd		;}

_reaccu lda	AC		;char _reaccu() { // assumes CP @col 5
	beq	_reacc1		; if ((AC == 0) && (*CP & 1 == 0)) // reaccum()
	lda	#10		;  return 0;
	jsr	inc_cp		; inc_cp(a = 15); // CP now @col 15
_reacc0 ldy	#0		;
	clc			;
	jsr	cp_cx		; cp_cx(c = 0); // print "C-"
	lda	#2		;
	jsr	inc_cp		; inc_cp(a = 2);
	lda	AC		; if (AC < 1)
	beq	_reacc1		;  return AC = a = 0; // required for vector fns
	jsr	printdd		; printdd(a = AC, CP);
	lda	#0		; return 0;
_reacc1 rts			;}

ctrl_g	lda	#0		;char ctrl_g(char a) {
	sta	AC		; AC = 0; return repaint(); 
	jmp	repaint		;}

ctrl_x	jsr	repaint		;char ctrl_x(char a) {
	jsr	findbar		; repaint();
	ldy	#20		; findbar(); // redundant?
	sec			;
	jsr	cp_cx		; cp_cx(c = 1); // print "C-X"

ctrl_x0	jsr	getchar		;
	sta	K		; K = getchar(); 
	cmp	#3		;
	bne	ctrl_xg		; if (K == 3) // C-x C-c
	rts			;  return 3;  // special code to mainlp

ctrl_xg cmp	#7		;
	bne	ctrl_x1		; else if (K == 7) // C-x C-g
	beq	ctrl_g		;  return ctrl_g(); 
	
ctrl_x1 cmp	#49		;
	bne	ctrl_x2		; else if (K == '1') {  // C-x 1
fullwin	ldx	#23		;  if (SCBOT == 23)
	cpx	SCBOT		;   return repaint();
	beq	ctrl_x3		;  else     // X=bn, new SCBOT
	ldy	#24		;           // Y=nb, new bar row
	jsr	bar_row		;           // A=ob, old bar row
	sec			;           // C=1 so that extent is from 0 to X
	jmp	bardown		;   return bardown(c=1, bar_row(), 23, 24); 

ctrl_x2	cmp	#50		; } else if (K == '2') { // C-x 2
	bne	ctrl_xo		;
	lda	SCTOP		;
	bne	ctrl_x3		;
	lda	SCBOT		;  if (SCTOP != 0 || SCBOT != 23)//already split
	cmp	#23		;   return repaint();
	bne	ctrl_x3		;  else { // fullscreen
	ldx	#12		;   x = 12; new top (c=1) or bottom (c=0) row
	txa			;
	tay			;   y = 12; new indicator bar row
	asl			;   a = 24; old indicator bar row
	cpx	TBLX		;
	bcs	expand		;
	bne	nosplat		;
	inx			;
nosplat	inx			;   if (12 < TBLX) // cursor in bottom half
	jmp	barup		;    return barup(c = 0, a, x == 12 ? x+2 : x+1, y);
expand	dex			;   else
	jmp	barup		;    return barup(c = 1, a, --x, y);
ctrl_x3 jmp	repaint		;  }
	
ctrl_xo and	#$5f
	cmp	#64+15		; } else if (K == 'O' || K == 'o') {
	bne	ctrl_x8		;
	lda	SCTOP		;
	ldx	SCBOT		;
	cpx	#23		;  if (SCBOT == 23) // in fullscreen (not split)
	beq	ctrl_x3		;   return 0;
	bcc	ctrl_x7		;  else if (SCBOT > 23) // at bot, move to top
	tax			;
	lda	#0		;
	dex			;
	dex			;
	jmp	newsize		;   return newsize(a = 0, x = SCTOP-2);
ctrl_x7	inx			;
	inx			;
	txa			;
	ldx	#24		;  else // SCBOT < 23, i.e. SCTOP == 9
	jmp	newsize		;   return newsize(a = SCBOT+2, x = 24);

ctrl_x8	jsr	ACmin1		; } else
	lda	SCTOP		;  return grwshrk(a = SCTOP, x = SCBOT,
	ldx	SCBOT		;                 y = AC ? AC : 1);
	ldy	AC		;}
	
grwshrk cmp	#00		;char grwshrk(uint8_t a, uint8_t x, uint8_t y) {
	bne	grwshr2		; if (a == 0) { // adjust bottom of upper window
	lda	K		;
	cmp	#"+"		;
	bne	grwshr1		;  if (K == '+') { // bar down by y rows
	sty	K		;   uint8_t* temp = &K;
	txa			;
; sec	
	clc			;   *temp = y; // y was delta row count AC
	adc	K		;
	sta	K		;   *temp += x; // x was bottom of window (old)
	cmp	#23		;
	bcs	grwshr5		;   if (*temp < 23) { 
	inx			;
	txa			;    a = ++x; // a now the old bar position
	ldx	K		;    x = *temp;// x still bottom of window (new)
	inc	K		;
	ldy	K		;    y = ++*temp; // y now the new bar position
	sec			;    c = 1; // indicates new window from 0 to x
; jmp barup
	jmp	bardown		;    return bardown(c, a, x, y);
; // if this works now delete bardown?!?

grwshr1 cmp	#"-"		;   }
	bne	grwshr5		;  } else if (K == '-') { // bar up by y rows
	sty	K		;   uint8_t* temp = &K;
	txa			;
	sec			;   *temp = y; // y was delta row count AC
	sbc	K		;
	sta	K		;   *temp = x-*temp;//x was bottom of wind (old)
	bmi	grwshr5		;   if (*temp >= 0) { 
	inx			;
	txa			;    a = ++x; // a now the old bar position
	ldx	K		;    x = *temp;// x still bottom of window (new)
	inc	K		;
	ldy	K		;    y = ++*temp; // y now the new bar position
	sec			;    c = 1; // indicates new window from 0 to x
	jmp	barup		;    return barup(c, a, x, y);

grwshr2 pha			;  }
	lda	K		; } else { // adjust top of lower window
	cmp	#"+"		;  uint8_t stack = a;//a was top of window (old)
	bne	grwshr3		;  if (K == '+') { // bar up by y rows
	sty	K		;   uint8_t* temp = &K
	pla			;
	tay			;   *temp = y;// y was delta row count AC
	dey			; 
	tya			;
	pha			;   stack--; // now the old bar position
	clc			;
	sbc	K		;   a -= *temp; // a still top of window (new)
	cmp	#2		;
	bcc	grwshr4		;   if (a > 1) { 
	tax			;    x = a; // x was bot, now the new window top
	tay			;
	dey			;    y = a - 1; // y now the new bar position
	pla			;    a = stack; // a now the old bar position
	clc			;    c = 0; // indicates new window from x to 23
	jmp	barup		;    return barup(c, a, x, y);

grwshr3 cmp	#"-"		;   }
	bne	grwshr4		;  } else if (K == '-') { // bar down by y rows
	sty	K		;   uint8_t* temp = &K;
	pla			;
	tay			;   *temp = y;//y was delta row count AC
	dey			; 
	tya			;
	pha			;   stack--; // now the old bar position
	sec			;
	adc	K		;   a += *temp; // a still top of window (new)
	cmp	#25		;
	bcs	grwshr4		;   if (a <= 24) { 
	tax			;    x = a; // x was bot, now the new window top
	tay			;
	dey			;    y = a - 1; // y now the new bar position
	pla			;    a = stack; // a now the old bar position
	clc			;    c = 0; // indicates new window from x to 23
	jmp	barup		;    return barup(c, a, x, y);

grwshr4 pla			;   }
grwshr5 lda	#0		;  }
	sta	AC		; } AC = 0; return repaint();
	jmp	repaint		;}

ctrl_i	lda	PNTR		;char ctrl_i(char a) {
	and	#7		;
	sta	AC		;
	lda	#8		;
	sec			;
	sbc	AC		;
	sta	AC		; AC = 8 - (PNTR & 7); 
	clc			;
	adc	PNTR		;
	cmp	SCRT		; if (PNTR + AC < SCRT)  // past EOL
	lda	#BLANK		;  return BLANK;
	bcc	ctrl_i1		; else {
	lda	#0		;  AC = 0;
	sta	AC		;  return RETURN;
	lda	#RETURN		; }
ctrl_i1 rts			;}
	
escape	lda	#0		;char escape(char a) {
	sta	AC		; AC = 0;
	jsr	repaint		; repaint(); 
	jsr	findbar		; findbar(); // redundant
	ldy	#20		;
	clc			;
	jsr	cp_escx		; cp_escx(c = 0); // print "ESC-"
escap0	jsr	getchar		;
	sta	K		; K = getchar(); 
	cmp	#60		;
	bne	escape1		;
	lda	#ULHOME		; if (K == '<')
	rts			;  return 19; 
escape1 cmp	#62		;
	bne	escape4		; if (K == '>') {
	lda	SCBOT		;
	sta	TBLX		;  for (TBLX = SCBOT; TBLX > SCTOP; TBLX--) {
escape2 jsr	printEk		;   printEk();
	jsr	findcsr		;
	ldy	#0		;
	lda	(CP),y		;
	cmp	#BLANK		;   if (*findcsr() != BLANK)
	bne	escape3		;    break; 
	lda	SCTOP		;
	dec	TBLX		;
	cmp	TBLX		;
	bne	escape2		;  }
escape3 jmp	ctrl_e		;  return ctrl_e(); 

escape4	lda	K		;
	and	#$5f		;
	cmp	#64+24		; } else if (K == 'x' || K == 'X') {
	beq	meta_x		;  return meta_x(); 

	cmp	#64+2		; } else if (K == 'b' || K == 'B') {
	bne	escape5		;  // try to actually set window bottom
	lda	SCBOT		;
	cmp	#24		;
	beq	escape9		;  if (SCBOT != 24) // in top window
	ldx	TBLX		;
	ldy	TBLX		;
	iny			; 
	clc			;
	adc	#1		;
	sec			;
	jmp	barup		;   return barup(c=1,a=SCBOT+1,x=TBLX,y=TBLX+1);

escape5	cmp	#64+20		; } else if (K == 't' || K == 'T') {
	bne	escape8		;  // try to actually set window bottom
	lda	SCTOP		;
	beq	escape9		;  if (SCTOP != 0) // in bottom window
	sec			;
	sbc	#1		;
	ldx	TBLX		;
	ldy	TBLX		;
	dey			;
	clc			;   return
	jmp	bardown		;        bardown(c=0,a=SCTOP-1,x=TBLX,y=TBLX-1);
	
escape8	cmp	#64+14		; else if (K == 'n' || K == 'N' ||
	beq	escape9		;          K == 'r' || K == 'R') {
	cmp	#64+18		;
	beq	escape9		;  return 0;
	
	jsr	printE		; } else {
	lda	#0		;  printE(); // putchar(27);
	sta	AC		;  AC = 0;
	lda	K		;
	rts			;  return K;
escape9	lda	#0		; }
escap10	rts			;}
	
meta_x	ldy	#20		;void meta_x(void) {
	sec			; char a;
	jsr	cp_escx		; cp_escx(c = 1); // print "ESC-X"
	jsr	getchar		; a = getchar();  
	and	#$5f		;
	cmp	#64+15		; if (a == 'O' || a == 'o')
	beq	insert		;  return insert();
meta_x1	lda	#0		; return 0;
	rts			;} /*7200 placeholder*/
	
insert	lda	INSFLG		;char insert(char a) {
	eor	#$ff		;
	sta	INSFLG		; INSFLG = ~INSFLG; 
	lda	#0		;
	sta	AC		; return repaint(); 
	jmp	repaint		;}

ctrl_k	jsr	findcsr		;char ctrl_k(char a) {
	ldy	#0		; findcsr();
	sty	AC		; AC = 0;
	sty	K		; for (y = K = 0; 1; y++) { 
ctrl_k1 tya			;  char a;
	clc			;
	adc	PNTR		;
	cmp	SCRT		;  if (PNTR+y > SCRT) // fixme: can't del @ 39
	beq	notyet		;
	bcs	ctrl_k2		;   break; 
notyet	lda	(CP),y		;  a = CP[y];
	
	cmp	#BLANK		;
	bne	noblank		;  if (a == BLANK) {// came across BLANK, incr.
	iny			;
	inc	K		;   K++; // add 1 to count of consecutive BLANK
	bne	ctrl_k1		;   continue;
noblank	ldx	K		;
	beq	chr2buf		;  } else
	tya			;
	tax			;
	lda	#BLANK		;   while (K > 0) //1st nonblank in a while
noblan2	sta	YANKBUF-1,x	;    YANKBUF[y - K--] = BLANK;
	dex			;
	dec	K		;
	bne	noblan2		;
	lda	(CP),y		;
	
chr2buf	tax			;
	lda	#BLANK		;
	sta	(CP),y		;  CP[y] = BLANK; 
	txa			;
	sta	YANKBUF,y	;  YANKBUF[y] = a; 
	iny			;
	bne	ctrl_k1		; }

ctrl_k2	cpy	K		;
	bne	ctrl_k3		; if (y == K) {// nothing but BLANK on this line
	lda	YANKLEN		;
	ora	#$80		;
	sta	YANKLEN		;  YANKLEN |= 0x80;
	bne	ctrl_k5		; } else
ctrl_k3	tya			;
	sec			;
	sbc	K		; // comment me
	tay			;
ctrl_k4 sty	YANKLEN		; YANKLEN = y; 
	bne	ctrl_k6		; if (YANKLEN <= 0) {
ctrl_k5	jsr	printE		;  putchar(ESC);
	lda	#64+4		;  return 'D'; // C-k on empty line deletes it
	bne	ctrl_k7		; } else
ctrl_k6	lda	#0		;  return 0;
ctrl_k7	rts			;}

ctrl_y	jsr	findcsr		;char ctrl_y(char a) {
	lda	YANKLEN		;
	and	#$7f		;
	sta	K		; K = YANKLEN & 0x7f;
	jsr	ACmin1		; for (AC = AC ? AC : 1; AC > 0; AC--) {
ctrl_y0	bit	YANKLEN		;
	bpl	ctrl_y1		;  if (YANKLEN & 0x80)
	lda	#64+9		;
	jsr	printE_		;   printE_('I'); // insert a line
	ldy	#0		;
ctrl_y1 lda	PNTR		;  for (y = 0; y < K; y++) { 
	cmp	SCRT		;
	lda	#BLANK		;
	bcc	yankchr		;   if (PNTR+y >= SCRT)
	
yanklf	jsr	CHROUT		;    while (PNTR > SCLF)
	ldx	PNTR		;     putchar(BLANK);
	cpx	SCLF		;
	bne	yanklf		;
	beq	yankch2		;

yankchr	jsr	CHROUT		;   putchar(' ');
yankch2	lda	YANKBUF,y	;
	sta	(CP),y		;   CP[y] = YANKBUF[y]; 
	iny			;
	cpy	K		;
	bne	ctrl_y1		;  } // end for (y)

	lda	YANKLEN		;
	bpl	ctrl_y3		;  if ((YANKLEN & 0x80)// C-y after C-k on empty
	cmp	#$80|LINELEN	;      && (YANKLEN & 0x7f == LINELEN))
	beq	ctrl_y2		;
	lda	#RETURN		;
	jsr	CHROUT		;   putchar('\r');
	
ctrl_y2	lda	TBLX		;
	jsr	row_adr		;   CP = row_adr(TBLX);
	bne	ctrl_y4		;  } else
	
ctrl_y3	tya			;
	jsr	inc_cp		;   CP += y;
ctrl_y4	dec	AC		; } // end for (AC)
	bne	ctrl_y0		;
	lda	#0		; return 0;
	rts			;}

ctrl_o	jsr	printE		;char ctrl_o(char a) {
	lda	#0		; printE();
	sta	AC		; AC = 0;
	lda	#64+9		; return 'I'; 
	rts			;}

ctrl_d	jsr	ACmin1		;char ctrl_d(char a) {
ctrl_d2	jsr	print_r		; for (AC = AC ? AC : 1; AC > 0; AC--) {
	lda	#20		;  putchar(CRSRRT); 
	jsr	CHROUT		;  putchar(20); // backspace
	dec	AC		; }
	bne	ctrl_d2		;
	lda	AC		; return 0;
	rts			;}

ctrl_t	ldx	LSTX		;char ctrl_t(char a) {
	beq	ctrl_t2		;
	lda	TBLX		;
	bne	ctrl_t0		;
	lda	PNTR		;
	beq	ctrl_t2		; if (LSTX && TBLX && PNTR)// not DEL or at home
ctrl_t0	jsr	ACmin1		;  for (AC = AC ? AC : 1; AC > 0; AC--) {
ctrl_t1	jsr	print_l		;   print_l(); // cursor left so we can read it
	jsr	findcsr		;   findcsr();
	ldx	#0		;
	ldy	#1		;
	lda	(CP,x)		;
	sta	K		;   K = CP[0];
	lda	(CP),y		;
	sta	(CP,x)		;   CP[0] = CP[1];
	lda	K		;
	sta	(CP),y		;   CP[1] = K;
	jsr	print_r		;   print_r(); // now cursor right twice so that
	jsr	print_r		;   print_r(); // net movement is one right
	dec	AC		;  }
	bne	ctrl_t1		;
	lda	#0		; return 0;
ctrl_t2	rts			;}
	
findbar ldx	SCBOT		;uint1_t findbar() {
	inx			;
	txa			; if (SCBOT + 1 <= 24)
	cmp	#25		;  return row_adr(SCBOT + 1, CP);
	bcc	row_adr		; else
	lda	#256-1		;  return row_adr(SCTOP - 1, CP);
	clc			;
	adc	SCTOP		;}

row_adr sta	CP		;void row_adr(uint8_t a /*row<25*/) {
	asl			;
	asl			;
	clc			;
	adc	CP		;
	asl			;
	sta	CP		; /* *CP = a*10; // <= 240 */
	lda	#0		;
	asl	CP		;
	rol			;
	sta	1+CP		; /* *CP = a*20; // <= 480 */
	asl	CP		;
	rol	1+CP		; /* *CP = a*40; // <= 960 */
	lda	#>TEDSCR	;
	clc			;
	adc	1+CP		;
	sta	1+CP		; *CP = TEDSCR + 40 * a;
	rts			;}

findcsr lda	TBLX		;void findcsr() {
	jsr	row_adr		; row_adr(TBLX, CP);
	lda	PNTR		; char* a = PNTR;
inc_cp	clc			; inc_cp(a, CP);
	adc	CP		;}
	sta	CP		;
	lda	1+CP		;uint8_t inc_cp(uint_8t a) {
	adc	#0		;
	sta	1+CP		; return (*CP += a) >> 8; // incidental
	rts			;}

crsroff jsr	findcsr		;void crsroff() {
	ldy	#0		; findcsr(CP);
	lda	(CP),y		;
	eor	#$80		;
	sta	(CP),y		; 0[*CP] ^= 0x80;
	lda	1+CP		;
	and	#$0b		;
	sta	1+CP		;
	lda	CC		;
	sta	(CP),y		; 0[*CP -= 1024] = CC;
	rts			;}

crsrclr .byte	ORANGE,GREEN	;void crsron() {
crsron	jsr	findcsr		; static uint8_t crsrclr[2] = {ORANGE, GREEN};
	ldy	#0		;
	lda	(CP),y		; findcsr(CP);
	eor	#$80		;
	sta	(CP),y		;
	lda	1+CP		; 0[*CP] ^= 0x80;
	and	#$0b		;
	sta	1+CP		;
	lda	(CP),y		;
	sta	CC		; CC = 0[CP -= 1024]; // read $07ED instead?
	lda	INSFLG		;
	tay			; // y = 0xff (auto-insert) or 0x00 (overwrite)
	iny			;
	lda	crsrclr,y	;
	ldy	#0		;
	sta	(CP),y		; 0[CP] = crsrclr[INSFLAG ? 0 : 1];
	rts			;}
	
bar_row lda	SCTOP		;uint8_t bar_row(void) {
	clc			;
	adc	#256-1		;
	bpl	bar_ro1		;
	lda	SCBOT		;
	clc			;
	adc	#1		; return SCTOP>0 ? SCTOP-1 : SCBOT+1;
bar_ro1 rts			;}
	
barup	sta	SCTOP		;char barup(uint1_t c, uint8_t a, uint8_t x,
	rol			;	    uint8_t y) {
	sta	K		; uint8_t stack1, stack2, temp = (a <<= 1) | c; 
	lda	#24		; SCTOP = a>>1; // a was old bar position, now
	sta	SCBOT		; SCBOT = 24; // left-shifted by 1 to preserve c
	txa			;
	pha			; stack2 = x; // per c, top/bottom of new window
	tya			;
	pha			; stack1 = y; // new bar position
	jsr	printEv		; printEv(); // obliterate old bar via scroll
	pla			;
	sta	SCTOP		; SCTOP = stack1;
	jsr	printEw		; printEw(); // open new line at new bar row
	lda	#0		;
	sta	AC		; AC = 0; // beware: all returners must lda#0->K
	pla			;
	lsr	K		;
	bcs	barup1		; if (temp & 1 == 0)
	ldx	#24		;  return newsize(a = stack2, x = 24);
	bcc	barup2		;
barup1	tax			; else
	lda	#0		;  return newsize(a = 0, x = stack2);
barup2	jmp	newsize		;}

bardown sta	SCBOT		;char bardown(uint1_t c, uint8_t a, uint8_t x,
	rol			;	      uint8_t y) {
	sta	K		; uint8_t stack1, stack2, temp = (a <<= 1) | c; 
	lda	#0		; SCBOT = a>>1; // a was old bar position, now
	sta	SCTOP		; SCTOP = 0; // left-shifted by 1 to preserve c
	txa			;
	pha			; stack2 = x; // per c, top/bottom of new window
	tya			;
	pha			; stack1 = y; // new bar position
	jsr	printEw		; printEw(); // obliterate old bar via scroll
	pla			;
	sta	SCBOT		; SCBOT = stack1;
	jsr	printEv		; printEv(); // open new line at new bar row
	lda	#0		;
	sta	AC		; AC = 0; // beware: all returners must lda#0->K
	pla			;
	lsr	K		;
	bcs	bardow1		; if (temp & 1 == 0)
	ldx	#24		;  return newsize(a = stack2, x = 24);
	bcc	bardow2		;
bardow1	tax			; else
	lda	#0		;  return newsize(a = 0, x = stack2);
bardow2	jmp	newsize		; return gohome();
	
top_bot sta	SCTOP		;void top_bot(uint8_t a, uint8_t x) {
	stx	SCBOT		; SCTOP = a, SCBOT = x; // 0 <= a <= x <= 24
	rts			;}

recrsr	jsr	findbar		;void recrsr() {// also does _reaccum()
	jmp	_recrsr		; findbar(CP); (void) _recrsr(CP);
				;} // call after any keystroke (saves bar redo)

reaccum jsr	findbar		;void reaccum() {
	lda	#15		; findbar(CP); inc_cp(a = 20); // CP bit 0 now 0
	jsr	inc_cp		; (void) _reaccu(CP); // prints "C- 0" if AC==0
	jmp	_reacc0		;}

ACmin1	lda	AC		;void ACmin1(uint8_t* AC) {
	bne	ACmin		;
	inc	AC		; *AC = *AC ? *AC : 1;
ACmin	rts			;}
	
DECDIG	.byte	10,20,30,40,50	;void printdd(uint7_t a) {
	.byte	60,70,80,90	; static uint7_t DECDIG[] = {10, 20, 30, 40, 50,
printdd tay			;			     60, 70, 80, 90};
	ldx	#9		; uint7_t temp, x, y = a;
printd1 cmp	DECDIG-1,x	;
	bcs	printd2		; for (x = 9; x > 0; x--) 
	dex			;  if (a >= x[DECDIG - 1])
	bne	printd1		;   break;

	stx	K		; if (x == 0) {
	lda	#128+BLANK	;  temp = 0;
	bcc	printd3		;  a = ' '; // suppress a leading zero

printd2 lda	DECDIG-1,x	; } else {
	sta	K		;  temp = x[DECDIG - 1];
	txa			;
	ldx	#0		;
	clc			;  a = x + '0';
	adc	#128+"0"	; }
	
printd3 sta	(CP,x)		; (*CP)[0] = a;
	tya			;
	sec			;
	sbc	K		;
	clc			;
	adc	#128+"0"	; a = y - temp + '0';
	ldy	#1		; (*CP)[1] = a;
	sta	(CP),y		;
	rts			;}

print_l	lda	#CRSRLF		;void print_l(void) { putchar(CRSRLF); }
	bne	printit		;

print_r	lda	#CRSRRT		;void print_r(void) { putchar(CRSRRT); }
	bne	printit		;

printE	lda	#ESC		;void printE(void) { putchar(ESC); }
	bne	printit		;

printEk	lda	#"K"		;void printEk(void) { printE_('K'); }
	bne	printE_		;

printEv	lda	#"V"		;
	bne	printE_		;void printEv(void) { printE_('V'); }

printEw	lda	#"W"		;void printEk(void) { printE_('W'); }
	
printE_	pha			;void printE_(char a) {
	jsr	printE		; printE();
	pla			; putchar(a);
printit	jmp	CHROUT		;}


cp_escx	lda	#"E"-"@"+128	;void cp_escx(uint1_t c) {
	sta	(CP),y		; CP[y++] = 0x80 | ('E'-'@');
	iny			;
	lda	#"S"-"@"+128	; CP[y++] = 0x80 | ('S'-'@');
	sta	(CP),y		; cp_cx(c);
	iny			;}
cp_cx	lda	#"C"-"@"+128	;void cp_cx(uint1_t c) {
	sta	(CP),y		; CP[y++] = 0x80 | ('C'-'@');
	iny			;
	lda	#"-"+128	;
	sta	(CP),y		; CP[y++] = 0x80 | '-';
	iny			;
	bcc	cp_retn		;
	lda	#"X"-"@"+128	; if (c)
	sta	(CP),y		;  CP[y++] = 0x80 | ('X'-'@');
	iny			;
cp_retn	rts			;}

getchar	jsr	CHRIN		;char getchar(void) {
	beq	getchar		; char a; while ((a = CHRIN()) == 0); return a;
	rts			;}
	
	.byte	$00
LASTADR .byte	$00,$00		;void LASTADR() {//can be overwritten with BASIC
	.byte	$00
	
-RESADR0= resume/4096		;#define RESADR0 (resume/4096)
-ADSOFAR= RESADR0*4096		;
-HEXFLAG= (((RESADR0 + 6) & 16) / 16)
-RESADR0-= HEXFLAG * "9"
-REMAIND= resume-ADSOFAR	;#define REMAIND0 (resume-(RESADR0*4096))
	
-RESADR1= REMAIND/256		;#define RESADR1 (REMAIND0/256)
-ADSOFAR= RESADR1*256		;
-HEXFLAG= (((RESADR1 + 6) & 16) / 16)
-RESADR1-= HEXFLAG * "9"
-REMAIND= REMAIND-ADSOFAR	;#define REMAIND1 (REMAIND0-(RESADR1*256))

-RESADR2= REMAIND/16		;#define RESADR2 (REMAIND1/16)
-ADSOFAR= RESADR2*16		;
-HEXFLAG= (((RESADR2 + 6) & 16) / 16)
-RESADR2-= HEXFLAG * "9"
-REMAIND= REMAIND-ADSOFAR	;#define REMAIND (REMAIND1-(RESADR2*16))

-HEXFLAG= (((REMAIND + 6) & 16) / 16)
-REMAIND-= HEXFLAG * "9"

-CHRADR0= RESADR0 + "0" + 128	;#define CHRADR0 (RESADR0 + '0')
-CHRADR1= RESADR1 + "0" + 128	;#define CHRADR1 (RESADR1 + '0')
-CHRADR2= RESADR2 + "0" + 128	;#define CHRADR2 (RESADR2 + '0')
-CHRADR3= REMAIND + "0" + 128	;#define CHRADR3 (RESADR3 + '0')
	
main3	jsr	hygiene		;void main3(void) {
	jsr	goodbye		; hygiene(); // same steps taken every time run
	ldy	#$53		; goodbye(); // prints wrong string, overwritten
copystr lda	EXITSTR-1,y	; for (y = 83; y > 0; y--)   
	eor	#$80		;
	sta	TOPBAR-1,y	;
	cpy	#$29		;
	bcs	nextstr		;  if (y <= 40)
	sta	TEDSCR-1,y	;   TEDSCR[y-1]= TOPBAR[y-1]= 0x80^EXITSTR[y-1];
nextstr dey			;  else
	bne	copystr		;   BOTBAR[y-41] = 0x80^EXITSTR[y-1]; 
	
	lda	#<INSTRUC	;
	sta	CP		;
	lda	#>INSTRUC	;
	sta	1+CP		; CP = INSTRUC;
nextins	ldy	#0		; while (uint8_t a = *CP++)
	lda	(CP),y		;
	beq	back2u		;
	jsr	CHROUT		;  putchar(a);
	lda	#1		;
	jsr	inc_cp		;
	bne	nextins		; exit(TXTTAB = main3); // setup done, kill self
back2u	rts			;}

EXITSTR	.byte	"F"-"@","O"-"@","R"-"@"," "    ,"E"-"@","M"-"@","A"-"@","C"-"@"
	.byte	"="    ,"S"-"@"," "    ,"T"-"@","O"-"@"," "    ,"R"-"@","E"-"@"
	.byte	"A"-"@","C"-"@","T"-"@","I"-"@","V"-"@","A"-"@","T"-"@","E"-"@"
	.byte	":"    ,"S"-"@","Y"-"@","S"-"@"," "    ,"D"-"@","E"-"@","C"-"@"
	.byte	"(",	34     ,CHRADR0,CHRADR1,CHRADR2,CHRADR3,34     ,")"    
;;; BOTBAR...
	.byte	" "    ,"("    ," "    ," "    ,","    ," "    ," "    ,")"
	.byte	" "    ,"I"-"@","N"-"@","S"-"@"," "    ," "    ," "    ," "
	.byte	" "    ," "    ," "    ," "    ," "    ," "    ," "    ," "
	.byte	" "    ," "    ," "    ," "    ,"E"-"@","M"-"@","A"-"@","C"-"@"
	.byte	"="    ,"S"-"@"," "    ,"V"-"@",MAJOR  ,"."    ,MINOR  ,MINOR0
;;; OVRWRIT...
	.byte	"O"-"@","V"-"@","R"-"@"

INSTRUC	.byte	13
	.byte	"SCREEN EDITOR OFFERS FAMILIAR BINDINGS: ",13
	.byte	"                                        ",13
	.byte	"ESC-X O TOGGLES INS","ERT CURSOR, MOVE WITH",13
	.byte	"C-A C-B C-E C-F C-N C-P C-T ESC-< ESC-> ",13
	.byte	"                                        ",13
	.byte	"C-X THEN 1,2,+ OR - TO SET WINDOW SIZES ",13
	.byte	"C-0 THROUGH C-9 REPEATS A SUBSEQUENT KEY",13
	.byte	"                                        ",13
	.byte	"C-D DELETE CHAR, C-O INSERTS BLANK LINES",13
	.byte	"C-I TABS, C-K KILLS LINE, C-Y YANKS BACK",13
	.byte	"                                        ",13
	.byte	"C-G CANCELS A COMMAND, C-Z SUSPENDS EDIT",13
	.byte	"                                        ",13
	.byte	" EMAC=S COPYRIGHT (C) 2015 DAUD A. ZOSS ",13
	.byte	"                                        ",13
	.byte	" THIS PROGRAM COMES WITH ABSOLUTELY NO  ",13
	.byte	" WARRANTY; FOR DETAILS CONSULT THE GNU  ",13
	.byte	" PUBLIC LICENSE VERSION 3 AT WWW.GNU.ORG",13
	.byte	"                                        ",13
	.byte	" THIS IS FREE SOFTWARE, AND YOU ARE     ",13
	.byte	" WELCOME TO DISTRIBUTE IT UNDER CERTAIN ",13
	.byte	" CONDITIONS. READ DETAILS IN THE SOURCE."
	.byte	0
end
