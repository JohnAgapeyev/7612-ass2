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

    ; address struct the listening socket binds to
    pop_sa istruc sockaddr_in
    at sockaddr_in.sin_family, dw 2 ; AF_INET
    at sockaddr_in.sin_port, dw 0xce56 ; port 22222 in host byte order
    at sockaddr_in.sin_addr, dd 0 ; localhost - INADDR_ANY
    at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddr_in_len equ $ - pop_sa

section .bss
    sock resd 1
    client resd 1
    buffer resb 256
    read_count resd 1

section .text
global _start

_start:
    ; Initialize listening and client socket values to 0, used for cleanup
    mov word [sock], 0
    mov word [client], 0

    ; Initialize socket
    call socket

    ; Bind and Listen
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
    mov rax, [read_count]
    cmp rax, 0
    je .read_complete
    jmp .readloop

.read_complete:
    ; Close client socket
    mov rdi, [client]
    call close_sock
    mov word [client], 0
    jmp .mainloop

    ; Exit with success (return 0)
    mov rdi, 0
    call exit

; Performs a sys_socket call to initialise a TCP/IP listening socket.
; Stores the socket file descriptor in the sock variable
socket:
    mov rax, 41 ; SYS_SOCKET
    mov rdi, 2 ; AF_INET
    mov rsi, 1 ; SOCK_STREAM
    mov rdx, 0
    syscall

    ; Check if socket was created successfully
    cmp rax, 0
    jle socket_fail

    ; Store the new socket descriptor
    mov [sock], rax

    ret

; Calls sys_bind and sys_listen to start listening for connections
listen:
    mov rax, 49 ; SYS_BIND
    mov rdi, [sock] ; listening socket fd
    mov rsi, pop_sa ; sockaddr_in struct
    mov rdx, sockaddr_in_len ; length of sockaddr_in
    syscall

    ; Check call succeeded
    cmp rax, 0
    jl bind_fail

    ; Bind succeeded, call sys_listen
    mov rax, 50 ; SYS_LISTEN
    mov rsi, 5 ; backlog
    syscall

    ; Check for success
    cmp rax, 0
    jl listen_fail

    ret

; Accept a cleint connection and store the new client socket descriptor
accept:
    ; Call sys_accept
    mov rax, 43 ; SYS_ACCEPT
    mov rdi, [sock] ; listening socket fd
    mov rsi, 0 ; NULL sockaddr_in value as we don't need that data
    mov rdx, 0 ; NULLs have length 0
    syscall

    ; Check if call succeeded
    cmp rax, 0
    jl accept_fail

    ; Store returned client socket descriptor
    mov [client], rax

    ; Print connection message to stdout
    mov rax, 1 ; SYS_WRITE
    mov rdi, 1 ; STDOUT
    mov rsi, accept_msg
    mov rdx, accept_msg_len
    syscall

    ret

; Reads up to 256 bytes from the client into buffer and sets the read_count variable
; to be the number of bytes read by sys_read
read:
    ; Call sys_read
    mov rax, 0 ; SYS_READ
    mov rdi, [client] ; client socket fd
    mov rsi, buffer ; buffer
    mov rdx, 256 ; read 256 bytes
    syscall

    ; Copy number of bytes read to variable
    mov [read_count], rax

    ret

; Sends up to the value of read_count bytes from buffer to the client socket
; using sys_write
echo:
    mov rax, 1 ; SYS_WRITE
    mov rdi, [client] ; client socket fd
    mov rsi, buffer ; buffer
    mov rdx, [read_count] ; number of bytes received in read
    syscall

    ret

; Performs sys_close on the socket in rdi
close_sock:
    mov rax, 3 ; SYS_CLOSE
    syscall

    ret

; Error Handling code
; *_fail loads the rsi and rdx registers with the appropriate
; error messages for given system call. Then call fail to display the
; error message and exit the application.
socket_fail:
    mov rsi, sock_err_msg
    mov rdx, sock_err_msg_len
    call fail

bind_fail:
    mov rsi, bind_err_msg
    mov rdx, bind_err_msg_len
    call fail

listen_fail:
    mov rsi, lstn_err_msg
    mov rdx, lstn_err_msg_len
    call fail

accept_fail:
    mov rsi, accept_err_msg
    mov rdx, accept_err_msg_len
    call fail

; Calls the sys_write syscall, writing an error message to stderr, then exits
; the application. rsi and rdx must be loaded with the error message and
; length of the error message before calling fail
fail:
    mov rax, 1 ; SYS_WRITE
    mov rdi, 2 ; STDERR
    syscall

    mov rdi, 1
    call exit

; Exits cleanly, checking if the listening or client sockets need to be closed
; before calling sys_exit
exit:
    mov rax, [sock]
    cmp rax, 0
    je .client_check
    mov rdi, [sock]
    call close_sock

.client_check:
    mov rax, [client]
    cmp rax, 0
    je .perform_exit
    mov rdi, [client]
    call close_sock

.perform_exit:
    mov rax, 60
    syscall
