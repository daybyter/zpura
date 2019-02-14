	.file	"delay.c"
	.globl	countdown_adr
.data
	.balign 4;
	.type	countdown_adr, @object
	.size	countdown_adr, 4
countdown_adr:
	.long	1073741832
.text
	.globl	delay
	.type	delay, @function
delay:
	im -1
	pushspadd
	popsp
	im countdown_adr
	load
	loadsp 16
	loadsp 4
	store
	storesp 8
.L2:
	loadsp 4
	load
	storesp 4
	loadsp 0
	impcrel .L2
	neqbranch
	im 3
	pushspadd
	popsp
	poppc
	.size	delay, .-delay
	.ident	"GCC: (GNU) 3.4.2"
