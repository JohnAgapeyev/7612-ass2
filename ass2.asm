struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .data
    sock_err_msg db "Failed to initialize socket", 0x0a, 0
    sock_err_msg_len equ $-sock_err_msg

    bind_err_msg db "Failed to bind socket", 0x0a, 0
    bind_err_msg_len equ $-bind_err_msg

    lstn_err_msg db "Socket Listen Failed", 0x0a, 0
    lstn_err_msg_len equ $-lstn_err_msg

    accept_err_msg db "Accept Failed", 0x0a, 0
    accept_err_msg_len equ $-accept_err_msg

    accept_msg db "Client Connected!", 0x0a, 0
    accept_msg_len equ $-accept_msg

    ;; sockaddr_in structure for the address the listening socket binds to
    pop_sa istruc sockaddr_in
        ; AF_INET
        at sockaddr_in.sin_family, dw 2
        ; port 22222 in host byte order
        at sockaddr_in.sin_port, dw 0xce56
        ; localhost - INADDR_ANY
        at sockaddr_in.sin_addr, dd 0
        at sockaddr_in.sin_zero, dd 0, 0
    iend

    sockaddr_in_len     equ $-pop_sa

section .bss
    sock resd 1
    client resd 1
    echobuf resb 256
    read_count resd 1

section .text
global _start

_start:

    jmp exit

exit:
    mov eax, 1
    mov ebx, 0
    int 0x80

;; Performs a sys_socket call to initialise a TCP/IP listening socket.
;; Stores the socket file descriptor in the sock variable
_socket:
    ; SYS_SOCKET
    mov eax, 41
    ; AF_INET
    mov edi, 2
    ; SOCK_STREAM
    mov esi, 1
    mov edx, 0
    int 0x80

    cmp eax, 0
    jle _socket_fail

    mov [sock], eax
    ret

;; Error Handling code
;; _*_fail loads the rsi and rdx registers with the appropriate
;; error messages for given system call. Then call _fail to display the
;; error message and exit the application.
_socket_fail:
    mov esi, sock_err_msg
    mov edx, sock_err_msg_len
    call _fail

_connect_fail:
    mov esi, accept_err_msg
    mov edx, accept_err_msg_len
    call _fail

;; Calls the sys_write syscall, writing an error message to stderr, then exits
;; the application. rsi and rdx must be loaded with the error message and
;; length of the error message before calling _fail
_fail:
    mov eax, 1 ; SYS_WRITE
    mov edi, 2 ; STDERR
    int 0x8

    mov edi, 1
    call _exit
