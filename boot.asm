; boot.asm
; NASM: nasm -f bin boot.asm -o boot.bin

bits 16
org 0x7c00

start:
    ; BIOS inicia o processador em modo real de 16 bits.
    ; Não dá pra assumir valores confiáveis para os segmentos, pode ter lixo.
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    sti
    cld

    call video_init

    mov si, message
    call video_print_string

.finished:
    call init_module

%include "include/video.asm"
%include MODULE_FILE

message:
    db "IGNITION 86", 0x0D, 0x0A
    db MODULE_FILE, 0

; Área de código do MBR: bytes 0–445.
times 446 - ($ - $$) db 0

; Tabela tradicional de quatro partições.
; Está vazia neste exemplo.
times 64 db 0

; Assinatura obrigatória do setor inicializável.
; No arquivo aparecem os bytes 55 AA por causa do little-endian.
dw 0xaa55
