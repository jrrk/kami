#!/bin/bash

COMP=riscv32-unknown-elf-gcc

$COMP -nostartfiles -nodefaultlibs -nostdlib -static -s -T config.ld dekker1.c
riscv32-unknown-elf-objdump -d a.out > dekker1.dmp
./BinaryToKamiPgm.native dekker1.dmp > PgmDekker1.v
rm dekker1.dmp a.out
$COMP -nostartfiles -nodefaultlibs -nostdlib -static -s -T config.ld dekker2.c
riscv32-unknown-elf-objdump -d a.out > dekker2.dmp
./BinaryToKamiPgm.native dekker2.dmp > PgmDekker2.v
rm dekker2.dmp a.out
