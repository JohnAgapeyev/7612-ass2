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

    server_msg db " responded with: ", 0
    server_msg_len equ $-server_msg

    ip_prompt db "Enter the server IP: ", 0
    ip_prompt_len equ $-ip_prompt

    port_prompt db "Enter the server port: ", 0
    port_prompt_len equ $-port_prompt

    count_prompt db "Enter the message count: ", 0
    count_prompt_len equ $-count_prompt

    client_msg db "This is a client message!", 0xa, 0
    client_msg_len equ $-client_msg

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
    buffer resb 256
    temp_buf resb 256
    mesg_count resd 1
    address resd 1
    port resw 1

section .text
global _start

; function:
;     _start
;
;  notes:
;   the global entry point
_start:
    call socket

    ; Write
    mov eax, 4
    mov ebx, 1
    mov ecx, ip_prompt
    mov edx, ip_prompt_len
    int 0x80

    call read_address
    call load_address

    ; Write
    mov eax, 4
    mov ebx, 1
    mov ecx, port_prompt
    mov edx, port_prompt_len
    int 0x80

    call read_num_value
    mov WORD [port], ax

    ; Bounds check the port
    cmp eax, 0
    jle exit
    cmp eax, 65535
    jg exit

    call load_port

    ; Write
    mov eax, 4
    mov ebx, 1
    mov ecx, count_prompt
    mov edx, count_prompt_len
    int 0x80

    call read_num_value
    mov DWORD [mesg_count], eax

    call connect

    mov edi, [mesg_count]

    .read:
    mov eax, 4
    mov ebx, [sock]
    mov ecx, client_msg
    mov edx, client_msg_len
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

    mov ecx, eax
    xor edx, edx
    .save_buf:
    mov eax, [buffer + (edx * 4)]
    mov [temp_buf + (edx * 4)], eax
    inc edx
    loop .save_buf

    mov eax, [address]
    call write_address

    ; Write
    mov eax, 4
    mov ebx, 1
    mov ecx, server_msg
    mov edx, server_msg_len
    int 0x80

    ; Write
    mov eax, 4
    mov ecx, temp_buf
    pop edx
    int 0x80

    dec edi
    test edi, edi
    jz exit

    jmp .read

; function:
;     exit
;
;  notes:
;   cleanly exit the program
exit:
    mov eax, 1
    mov ebx, 0
    int 0x80

; function:
;     socket
;
;  notes:
;   setup the socket using the socketcall syscall and load it into sock
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

; function:
;     connect
;
;  notes:
;   connect the socket in sock to the address in sockaddr_in
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

; function:
;     fail
;
;  notes:
;   print an error about connecting and exit the program
fail:
    mov eax, 4 ; SYS_WRITE
    mov ebx, 2 ; STDERR
    int 0x80
    jmp exit

; function:
;     load_address
;
;  notes:
;   load the address in address into the sockaddr_in
load_address:
    mov eax, [address]
    bswap eax
    mov DWORD [pop_sa + sockaddr_in.sin_addr], eax
    ret

; function:
;     load_port
;
;  notes:
;   load the port in port into the sockaddr_in
load_port:
    mov eax, [port]
    bswap eax
    shr eax, 16
    mov WORD [pop_sa + sockaddr_in.sin_port], ax
    ret

; function:
;     read_address
;
;  notes:
;   get the string from the user and load it into address
read_address:
    ;Read string into buffer
    mov eax, 3
    mov ebx, 0
    mov ecx, buffer
    mov edx, 15
    int 0x80

    ;Grab number of bytes read
    mov ecx, eax
    sub ecx, 2

    xor eax, eax
    mov ebx, 1

    xor edi, edi

    jmp .loop_start

    .loo:
    ;Grab current buffer byte
    mov dl, [buffer + ecx]
    ;Check if byte is less than '.'
    cmp dl, '.'
    je .next_term
    ;Check if byte is less than '0'
    cmp dl, '0'
    jl exit
    ;Check if byte is greater than '9'
    cmp dl, '9'
    jg exit

    ;eax = (buffer[ecx] & 0xf) * ebx
    and edx, 0xf
    imul edx, ebx
    add eax, edx

    ;ebx *= 10
    imul ebx, 10

    dec ecx

    .loop_start:
    ;Loop condition
    cmp ecx, 0
    jge .loo
    ;Prevent overflow on ip term
    cmp eax, 255
    jg exit
    mov BYTE [address + edi], al
    ret
    .next_term:
    dec ecx
    ;Prevent overflow on ip term
    cmp eax, 255
    jg exit
    ;Save byte somewhere before xoring
    mov BYTE [address + edi], al
    inc edi
    xor eax, eax
    mov ebx, 1
    jmp .loop_start

; function:
;     read_num_value
;
; return:
;    eax - the number read
;
;  notes:
;   get a numerical value from the user
read_num_value:
    ;Read string into buffer
    mov eax, 3
    mov ebx, 0
    mov ecx, buffer
    mov edx, 10
    int 0x80

    ;Grab number of bytes read
    mov ecx, eax
    sub ecx, 2

    xor eax, eax
    mov ebx, 1

    jmp .loop_start

    .loo:
    ;Grab current buffer byte
    mov dl, [buffer + ecx]
    ;Check if byte is negative sign
    cmp dl, 0x2d
    je .negative
    ;Check if byte is less than '0'
    cmp dl, 0x30
    jl exit
    ;Check if byte is greater than '9'
    cmp dl, 0x39
    jg exit

    ;eax = (buffer[ecx] & 0xf) * ebx
    and edx, 0xf
    imul edx, ebx
    add eax, edx

    ;ebx *= 10
    imul ebx, 10

    dec ecx

    .loop_start:
    ;Loop condition
    cmp ecx, 0
    jge .loo
    ret
    .negative:
    neg eax
    ret

; eax is the address
; function:
;     write_address
;
; parameters:
;    eax the address to print
;
;  notes:
;   print address out
write_address:
    push eax
    shr eax, 24
    call write_val

    mov eax, 4
    mov ebx, 1
    push '.'
    mov ecx, esp
    mov edx, 1
    int 0x80

    add esp, 4
    pop eax
    push eax
    shr eax, 16
    and eax, 0x000000ff
    call write_val

    mov eax, 4
    mov ebx, 1
    push '.'
    mov ecx, esp
    mov edx, 1
    int 0x80
    add esp, 4
    pop eax
    push eax
    shr eax, 8
    and eax, 0x000000ff
    call write_val

    mov eax, 4
    mov ebx, 1
    push '.'
    mov ecx, esp
    mov edx, 1
    int 0x80
    add esp, 4
    pop eax
    and eax, 0x000000ff
    call write_val
    ret

;eax is the value
; function:
;     write_val
;
; parameters:
;    eax the value to print
;
;  notes:
;   print out the ascii of the value
write_val:
    cmp eax, 0
    jns .write_pos

    ;Negate value
    neg eax

    ;Save on stack
    push eax

    ;Write negative sign
    mov eax, 4
    mov ebx, 1
    ;0x2d is the '-' char
    push 0x2d
    mov ecx, esp
    mov edx, 1
    int 0x80

    ;Pop char off the stack
    pop ecx

    ;Read back saved positive value
    pop eax

    .write_pos:
    ;Store value in ebx
    mov ebx, eax

    ;Zero out byte counter
    xor esi, esi

    ;Clear edx
    xor edx, edx

    ;Set the dividend
    mov eax, ebx
    ;Divide by 10k
    mov ecx, 10000
    div ecx

    cmp al, 0
    jz .thousand

    inc esi

    ;Convert number to character equivalent
    ;al += '0'
    add al, 48
    ;Store the 10k byte
    mov BYTE [buffer], al

    ;Store remainder
    mov ebx, edx

    .thousand:
    ;Clear edx
    xor edx, edx

    ;Set the dividend
    mov eax, ebx
    ;Divide by 1k
    mov ecx, 1000
    div ecx

    cmp al, 0
    jz .hundred

    inc esi

    ;Convert number to character equivalent
    ;al += '0'
    add al, 48
    ;Store the 1k byte
    mov BYTE [buffer + 1], al

    ;Store remainder
    mov ebx, edx

    .hundred:
    ;Clear edx
    xor edx, edx

    ;Set the dividend
    mov eax, ebx
    ;Divide by 100
    mov ecx, 100
    div ecx

    cmp al, 0
    jz .ten

    inc esi

    ;Convert number to character equivalent
    ;al += '0'
    add al, 48
    ;Store the 100 byte
    mov BYTE [buffer + 2], al

    ;Store remainder
    mov ebx, edx

    .ten:
    ;Clear edx
    xor edx, edx

    ;Set the dividend
    mov eax, ebx
    ;Divide by 100
    mov ecx, 10
    div ecx

    cmp al, 0
    jz .one

    inc esi

    ;Convert number to character equivalent
    ;al += '0'
    add al, 48
    ;Store the 10 byte
    mov BYTE [buffer + 3], al

    .one:
    add dl, 48
    ;Store the 1 byte
    mov BYTE [buffer + 4], dl

    inc esi

    ;Write
    mov eax, 4
    mov ebx, 1
    mov ecx, buffer

    ;Offset ecx by byte counter to prevent zero padding the string
    add ecx, 5
    sub ecx, esi

    mov edx, esi
    int 0x80
    ret
