; Mini Snake para VGA modo 13h.
; Grade lógica: 40x16 células de 8x8 pixels. Setas: BIOS INT 16h.

SNAKE_MAX equ 12

init_module:
    call snake_food_draw

    mov ah, 0
    int 0x1a
    mov [snake_tick], dx

.loop:
    mov ah, 1
    int 0x16
    jz .timer
    mov ah, 0
    int 0x16
    cmp ah, 0x48
    jne .key_down
    mov byte [snake_dir], 0
.key_down:
    cmp ah, 0x50
    jne .key_left
    mov byte [snake_dir], 2
.key_left:
    cmp ah, 0x4b
    jne .key_right
    mov byte [snake_dir], 3
.key_right:
    cmp ah, 0x4d
    jne .timer
    mov byte [snake_dir], 1

.timer:
    mov ah, 0
    int 0x1a
    mov ax, dx
    sub ax, [snake_tick]
    cmp ax, 3
    jb .wait
    mov [snake_tick], dx
    call snake_step
.wait:
    sti
    hlt
    jmp .loop

snake_step:
    mov dl, [snake_x]
    mov dh, [snake_y]
    mov al, [snake_dir]
    test al, al
    jz .up
    dec al
    jz .right
    dec al
    jz .down
    dec dl
    jns .wrap_y
    mov dl, 39
    jmp .wrap_y
.up:
    dec dh
    jmp .wrap_y
.right:
    inc dl
    cmp dl, 40
    jb .wrap_y
    xor dl, dl
    jmp .wrap_y
.down:
    inc dh
.wrap_y:
    and dh, 15                ; retorno vertical: 0..15

    cmp dl, [snake_food_x]
    jne .erase
    cmp dh, [snake_food_y]
    jne .erase
    cmp byte [snake_len], SNAKE_MAX
    jae .erase
    inc byte [snake_len]
    mov al, [snake_food_x]
    add al, 11
    cmp al, 40
    jb .food_x_ready
    sub al, 40
.food_x_ready:
    mov [snake_food_x], al
    add byte [snake_food_y], 5
    and byte [snake_food_y], 15
    push dx                    ; snake_food_draw altera DL:DH
    call snake_food_draw
    pop dx                     ; restaura a nova posição da cabeça
    jmp .shift

.erase:
    xor bx, bx
    mov bl, [snake_len]
    dec bx
    push dx
    mov dl, [snake_x + bx]
    mov dh, [snake_y + bx]
    xor al, al
    call snake_cell
    pop dx

.shift:
    xor cx, cx
    mov cl, [snake_len]
    dec cx
.one:
    jz .head
    mov si, cx
    mov al, [snake_x + si - 1]
    mov [snake_x + si], al
    mov al, [snake_y + si - 1]
    mov [snake_y + si], al
    dec cx
    jmp .one
.head:
    mov [snake_x], dl
    mov [snake_y], dh
    mov al, 0x0a
    jmp snake_cell

snake_food_draw:
    mov dl, [snake_food_x]
    mov dh, [snake_food_y]
    mov al, 0x0c

; Entrada: DL=x, DH=y e AL=cor. A área do jogo começa no pixel y=32.
snake_cell:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    mov bl, al
    xor ax, ax
    mov al, dh
    add al, 4
    shl ax, 3                 ; converte a linha lógica em pixels (y * 8)
    mov di, ax
    shl di, 6
    shl ax, 8
    add di, ax
    xor ax, ax
    mov al, dl
    shl ax, 3
    add di, ax
    mov ax, 0xa000
    mov es, ax
    mov al, bl
    mov dx, 8
.row:
    mov cx, 8
    rep stosb
    add di, 312
    dec dx
    jnz .row
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

snake_len:    db 3
snake_dir:    db 1
snake_food_x: db 24
snake_food_y: db 8
snake_tick:   dw 0
snake_x:      db 16, 15, 14
              times SNAKE_MAX - 3 db 0
snake_y:      db 8, 8, 8
              times SNAKE_MAX - 3 db 0
