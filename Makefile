all:
	nasm -g -O0 -Wall -f elf client.asm -o client.o
	ld -m elf_i386 client.o -o client.out

clean:
	$(RM) client.o client.out
