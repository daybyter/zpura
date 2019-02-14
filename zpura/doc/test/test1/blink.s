
blink:     file format elf32-zpu

Disassembly of section .text:

00000000 <main>:
   0:	fe          	im -2
   1:	3d          	pushspadd
   2:	0d          	popsp
   3:	80          	im 0
   4:	53          	storesp 12

00000005 <.L2>:
   5:	0b          	nop
   6:	0b          	nop
   7:	0b          	nop
   8:	80          	im 0
   9:	d4          	im -44
   a:	08          	load
   b:	73          	loadsp 12
   c:	71          	loadsp 4
   d:	0c          	store
   e:	52          	storesp 8
   f:	72          	loadsp 8
  10:	09          	not
  11:	53          	storesp 12
  12:	83          	im 3
  13:	f4          	im -12
  14:	51          	storesp 4
  15:	0b          	nop
  16:	0b          	nop
  17:	0b          	nop
  18:	0b          	nop
  19:	9d          	im 29
  1a:	3f          	callpcrel
  1b:	0b          	nop
  1c:	0b          	nop
  1d:	0b          	nop
  1e:	80          	im 0
  1f:	d4          	im -44
  20:	08          	load
  21:	73          	loadsp 12
  22:	71          	loadsp 4
  23:	0c          	store
  24:	52          	storesp 8
  25:	72          	loadsp 8
  26:	09          	not
  27:	53          	storesp 12
  28:	83          	im 3
  29:	f4          	im -12
  2a:	51          	storesp 4
  2b:	0b          	nop
  2c:	0b          	nop
  2d:	0b          	nop
  2e:	0b          	nop
  2f:	87          	im 7
  30:	3f          	callpcrel
  31:	0b          	nop
  32:	0b          	nop
  33:	0b          	nop
  34:	0b          	nop
  35:	cf          	im -49
  36:	39          	poppcrel

00000037 <delay>:
  37:	ff          	im -1
  38:	3d          	pushspadd
  39:	0d          	popsp
  3a:	0b          	nop
  3b:	0b          	nop
  3c:	0b          	nop
  3d:	80          	im 0
  3e:	d8          	im -40
  3f:	08          	load
  40:	74          	loadsp 16
  41:	71          	loadsp 4
  42:	0c          	store
  43:	52          	storesp 8

00000044 <.L2>:
  44:	71          	loadsp 4
  45:	08          	load
  46:	51          	storesp 4
  47:	70          	loadsp 0
  48:	0b          	nop
  49:	0b          	nop
  4a:	0b          	nop
  4b:	0b          	nop
  4c:	f7          	im -9
  4d:	38          	neqbranch
  4e:	83          	im 3
  4f:	3d          	pushspadd
  50:	0d          	popsp
  51:	04          	poppc
