; Serviços mínimos de vídeo para o boot stub.
video_init:
    mov ax, 0x0013            ; BIOS: VGA 320x200, 256 cores
    int 0x10
    ret

; Entrada: DS:SI aponta para uma string terminada em zero.
; Saída:   SI aponta para o byte seguinte ao terminador.
video_print_string:
.next:
    lodsb
    test al, al
    jz .done
    call video_print_char
    jmp .next

.done:
    ret

; Entrada: AL contém o caractere ASCII.
video_print_char:
    mov ah, 0x0e              ; BIOS: saída por teletype
    mov bh, 0                 ; página de vídeo zero
    mov bl, 0x0f              ; cor branca
    int 0x10
    ret
