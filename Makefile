all:
	nasm -g -O0 -Wall -f elf client.asm -o client.o
	nasm -g -O0 -Wall -f elf server.asm -o server.o
	ld -m elf_i386 client.o -o client.out
	ld -m elf_i386 server.o -o server.out

clean:
	$(RM) client.o client.out server.o server.out
