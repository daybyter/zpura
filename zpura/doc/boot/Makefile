# Bootloader for the zpura system

PROJECT = bootload

SOURCES = boot-s.S crt0.S  $(wildcard *.c)

CC = zpu-elf-gcc

# Avoid optional opcodes for boot rom stage1 ?
CC_ARGS_BOOT_STAGE1 = -mno-poppcrel -mno-compare -mno-eq -mno-byteop \
-mno-shortop -mno-callpcrel -mno-call -mno-lshiftrt \
-mno-ashiftl -mno-ashiftrt -mno-neqbranch -mno-pushspadd \
-mno-neg -mno-mod -mno-div -mno-mult

CC_ARGS = -O3 -nostartfiles -nostdlib $(CC_ARGS_BOOT_STAGE1)


all: compile
	echo "Compiling the zpura bootloader"

compile:
	$(CC) $(CC_ARGS) $(SOURCES) -o $(PROJECT)

assembler:
	zpu-elf-objdump -d -S $(PROJECT) > $(PROJECT).s

# $(CC) $(CC_ARGS) -S $(SOURCES)

rom: compile
	zpu-elf-objcopy -O binary $(PROJECT) $(PROJECT).rom
