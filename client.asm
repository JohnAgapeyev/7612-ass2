struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .data
    sock_err_msg db "Failed to initialize socket", 0x0a, 0
    sock_err_msg_len equ $-sock_err_msg

    connect_err_msg db "Failed to connect to server", 0x0a, 0
    connect_err_msg_len equ $-connect_err_msg

    server_msg db "Server responded with: ", 0
    server_msg_len equ $-server_msg

    IP_1 equ 127
    IP_2 equ 0
    IP_3 equ 0
    IP_4 equ 1

    PORT equ 12345

    pop_sa istruc sockaddr_in
        ; AF_INET
        at sockaddr_in.sin_family, dw 2
        ; Will be filled in later
        at sockaddr_in.sin_port, dw 0
        ; Will be filled in later
        at sockaddr_in.sin_addr, dd 0
        at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddr_in_len equ $-pop_sa

section .bss
    sock resd 1
    client resd 1
    buffer resb 256
    read_count resd 1

section .text
global _start

_start:
    ; Fill address into struct
    lea edi, [pop_sa + sockaddr_in.sin_addr]
    call load_address
    ; Fill port into struct
    lea edi, [pop_sa + sockaddr_in.sin_port]
    call load_port

    call socket

    call connect

    .read:
    ; Read
    mov eax, 3
    ; stdin
    mov ebx, 0
    mov ecx, buffer
    mov edx, 256
    int 0x80

    cmp eax, 0
    jl exit

    mov edx, eax
    mov eax, 4
    mov ebx, [sock]
    mov ecx, buffer
    int 0x80

    ; Read
    mov eax, 3
    mov ebx, [sock]
    mov ecx, buffer
    mov edx, 256
    int 0x80

    cmp eax, 0
    jl exit

    push eax

    ; Write
    mov eax, 4
    mov ebx, 1
    mov ecx, server_msg
    mov edx, server_msg_len
    int 0x80

    ; Write
    mov eax, 4
    mov ecx, buffer
    pop edx
    int 0x80
    jmp .read

exit:
    mov eax, 1
    mov ebx, 0
    int 0x80

socket:
    ; socketcall
    mov eax, 102
    ; socket()
    mov ebx, 1

    push 0
    push 1
    push 2

    mov ecx, esp

    int 0x80

    add esp, 12

    cmp eax, 0
    jl .socket_fail

    mov [sock], eax

    ; syscall 102 - socketcall
    mov eax, 102
    ; socketcall type (sys_setsockopt 14)
    mov ebx, 14
    ; sizeof socklen_t
    push 4
    ; address of socklen_t - on the stack
    push esp
    ; SO_REUSEADDR = 2
    push 2
    ; SOL_SOCKET = 1
    push 1

    mov edx, [sock]

    ; sockfd
    push edx

    mov ecx, esp
    int 0x80

    add esp, 20

    ;mov [sock], eax
    ret
    .socket_fail:
    mov ecx, sock_err_msg
    mov edx, sock_err_msg_len
    jmp fail

connect:
    ; socketcall
    mov eax, 102
    ; connect()
    mov ebx, 3

    push sockaddr_in_len
    push pop_sa
    push DWORD [sock]

    mov ecx, esp

    int 0x80

    add esp, 12

    cmp eax, 0
    jl .connect_fail
    ret
    .connect_fail:
    mov ecx, connect_err_msg
    mov edx, connect_err_msg_len
    jmp fail

fail:
    mov eax, 4 ; SYS_WRITE
    mov ebx, 2 ; STDERR
    int 0x80
    jmp exit


load_address:
    mov BYTE [edi + 0], IP_1
    mov BYTE [edi + 1], IP_2
    mov BYTE [edi + 2], IP_3
    mov BYTE [edi + 3], IP_4
    ret

load_port:
    mov ax, PORT
    bswap eax
    shr eax, 16
    mov WORD [edi], ax
    ret
