all:
	nasm -g -O0 -Wall -f elf ass2.asm -o ass2.o
	ld -m elf_i386 ass2.o -o ass2.out

clean:
	$(RM) ass2.o ass2.out
