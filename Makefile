all:
	nasm -g -O0 -Wall -f elf client.asm -o client.o
	ld -m elf_i386 client.o -o client.out
	nasm -g -O0 -Wall -f elf64 server.asm -o server.o
	ld -m elf_x86_64 server.o -o server.out

clean:
	$(RM) client.o client.out server.o server.out
