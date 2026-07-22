; Relógio de tempo real por BIOS INT 1Ah.
; A função AH=02h retorna CH:CL:DH = hora:minuto:segundo em BCD.

init_module:
    mov byte [rtc_last_second], 0xff
    sti

.read:
    mov ah, 0x02
    int 0x1a
    jc .wait                  ; CF=1 indica que o RTC não pôde ser lido

    cmp dh, [rtc_last_second]
    je .wait                  ; evita redesenhar durante o mesmo segundo

    mov [rtc_last_second], dh
    mov [rtc_hour], ch
    mov [rtc_minute], cl
    mov [rtc_second], dh

    mov dh, 3                 ; linha quatro (contagem começa em zero)
    mov dl, 0                 ; primeira coluna
    call video_set_cursor

    mov si, rtc_label
    call video_print_string

    mov al, [rtc_hour]
    call video_print_bcd
    mov al, ':'
    call video_print_char

    mov al, [rtc_minute]
    call video_print_bcd
    mov al, ':'
    call video_print_char

    mov al, [rtc_second]
    call video_print_bcd

.wait:
    sti
    hlt                       ; IRQ do timer acorda a CPU periodicamente
    jmp .read

rtc_label:       db "RTC ", 0
rtc_last_second: db 0xff
rtc_hour:        db 0
rtc_minute:      db 0
rtc_second:      db 0

; Auxiliares exclusivos do RTC. Eles permanecem neste módulo para não ocupar
; espaço quando outro módulo, como snake.asm, é selecionado.
video_set_cursor:
    mov ah, 0x02
    mov bh, 0
    int 0x10
    ret

video_print_bcd:
    push ax
    shr al, 4
    and al, 0x0f
    add al, '0'
    call video_print_char
    pop ax
    and al, 0x0f
    add al, '0'
    call video_print_char
    ret
