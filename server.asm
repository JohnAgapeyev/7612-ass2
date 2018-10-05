struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .data
    sock_err_msg db "Failed to initialize socket", 0x0a, 0
    sock_err_msg_len equ $ - sock_err_msg

    bind_err_msg db "Failed to bind socket", 0x0a, 0
    bind_err_msg_len equ $ - bind_err_msg

    lstn_err_msg db "Socket Listen Failed", 0x0a, 0
    lstn_err_msg_len equ $ - lstn_err_msg

    accept_err_msg db "Accept Failed", 0x0a, 0
    accept_err_msg_len equ $ - accept_err_msg

    accept_msg db "Client Connected!", 0x0a, 0
    accept_msg_len equ $ - accept_msg

    port_prompt db "Enter the server port: ", 0
    port_prompt_len equ $-port_prompt

    ; address struct the listening socket binds to
    pop_sa istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2
        ; Will be filled in later
        at sockaddr_in.sin_port, dw 0
        at sockaddr_in.sin_addr, dd 0
        at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddr_in_len equ $ - pop_sa

section .bss
    sock resd 1
    client resd 1
    port resw 1
    buffer resb 256
    read_count resd 1

section .text
global _start

_start:
    mov word [sock], 0
    mov word [client], 0

    ; Write
    mov eax, 4
    mov ebx, 1
    mov ecx, port_prompt
    mov edx, port_prompt_len
    int 0x80

    call read_num_value
    mov DWORD [port], eax

    ; Bounds check the port
    cmp eax, 0
    jle exit
    cmp eax, 65535
    jg exit

    call load_port
    call socket
    call listen

    ; Main loop handles connection requests (accept()) then echoes data back to client
.mainloop:
    call accept

    ; Read and echo string back to the client
    ; up the connection on their end.
.readloop:
    call read
    call echo

    ; read_count is set to zero when client hangs up
    mov eax, [read_count]
    cmp eax, 0
    je .read_complete
    jmp .readloop

.read_complete:
    ; Close client socket
    mov edi, [client]
    call close_sock
    mov word [client], 0
    jmp .mainloop

    ; Exit with success (return 0)
    mov edi, 0
    call exit

load_port:
    mov eax, [port]
    bswap eax
    shr eax, 16
    mov WORD [pop_sa + sockaddr_in.sin_port], ax
    ret

; Performs a sys_socket call to initialise a TCP/IP listening socket.
; Stores the socket file descriptor in the sock variable
socket:
    mov eax, 41 ; SYS_SOCKET
    mov edi, 2 ; AF_INET
    mov esi, 1 ; SOCK_STREAM
    mov edx, 0
    int 0x80

    ; Check if socket was created successfully
    cmp eax, 0
    jle socket_fail

    ; Store the new socket descriptor
    mov [sock], eax

    ret

; Calls sys_bind and sys_listen to start listening for connections
listen:
    mov eax, 49 ; SYS_BIND
    mov edi, [sock] ; listening socket fd
    mov esi, pop_sa ; sockaddr_in struct
    mov edx, sockaddr_in_len ; length of sockaddr_in
    int 0x80

    ; Check call succeeded
    cmp eax, 0
    jl bind_fail

    ; Bind succeeded, call sys_listen
    mov eax, 50 ; SYS_LISTEN
    mov esi, 5 ; backlog
    int 0x80

    ; Check for success
    cmp eax, 0
    jl listen_fail

    ret

; Accept a cleint connection and store the new client socket descriptor
accept:
    ; Call sys_accept
    mov eax, 43 ; SYS_ACCEPT
    mov edi, [sock] ; listening socket fd
    mov esi, 0 ; NULL sockaddr_in value as we don't need that data
    mov edx, 0 ; NULLs have length 0
    int 0x80

    ; Check if call succeeded
    cmp eax, 0
    jl accept_fail

    ; Store returned client socket descriptor
    mov [client], eax

    ; Print connection message to stdout
    mov eax, 1 ; SYS_WRITE
    mov edi, 1 ; STDOUT
    mov esi, accept_msg
    mov edx, accept_msg_len
    int 0x80

    ret

; Reads up to 256 bytes from the client into buffer and sets the read_count variable
; to be the number of bytes read by sys_read
read:
    ; Call sys_read
    mov eax, 0 ; SYS_READ
    mov edi, [client] ; client socket fd
    mov esi, buffer ; buffer
    mov edx, 256 ; read 256 bytes
    int 0x80

    ; Copy number of bytes read to variable
    mov [read_count], eax

    ret

; Sends up to the value of read_count bytes from buffer to the client socket
; using sys_write
echo:
    mov eax, 1 ; SYS_WRITE
    mov edi, [client] ; client socket fd
    mov esi, buffer ; buffer
    mov edx, [read_count] ; number of bytes received in read
    int 0x80

    ret

; Performs sys_close on the socket in edi
close_sock:
    mov eax, 3 ; SYS_CLOSE
    int 0x80

    ret

; Error Handling code
; *_fail loads the esi and edx registers with the appropriate
; error messages for given system call. Then call fail to display the
; error message and exit the application.
socket_fail:
    mov esi, sock_err_msg
    mov edx, sock_err_msg_len
    call fail

bind_fail:
    mov esi, bind_err_msg
    mov edx, bind_err_msg_len
    call fail

listen_fail:
    mov esi, lstn_err_msg
    mov edx, lstn_err_msg_len
    call fail

accept_fail:
    mov esi, accept_err_msg
    mov edx, accept_err_msg_len
    call fail

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

; Calls the sys_write int 0x80, writing an error message to stderr, then exits
; the application. esi and edx must be loaded with the error message and
; length of the error message before calling fail
fail:
    mov eax, 1 ; SYS_WRITE
    mov edi, 2 ; STDERR
    int 0x80

    mov edi, 1
    call exit

; Exits cleanly, checking if the listening or client sockets need to be closed
; before calling sys_exit
exit:
    mov eax, [sock]
    cmp eax, 0
    je .client_check
    mov edi, [sock]
    call close_sock

.client_check:
    mov eax, [client]
    cmp eax, 0
    je .perform_exit
    mov edi, [client]
    call close_sock

.perform_exit:
    mov eax, 60
    int 0x80
