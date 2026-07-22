# Anatomia do boot stub Ignition 86

Este documento descreve o funcionamento do arquivo [`boot.asm`](boot.asm), um
setor de boot para BIOS legado em processadores x86. O objetivo não é carregar
um sistema operacional nem acessar um sistema de arquivos. O núcleo inicializa
o modo gráfico VGA, mostra `IGNITION 86`, imprime o caminho do módulo selecionado
e chama o ponto de entrada `init_module`. O comportamento seguinte depende de
`halt.asm`, `rtc.asm`, `snake.asm` ou de outro módulo escolhido no build.

O binário resultante tem exatamente 512 bytes e pode ser usado como primeiro
setor de uma imagem de disco para fins didáticos.

## 1. Visão geral do processo de boot

Quando uma máquina configurada para BIOS legado é ligada, ocorre, de forma
simplificada, a seguinte sequência:

1. O processador começa executando o firmware BIOS.
2. O BIOS realiza o POST (*Power-On Self-Test*) e inicializa dispositivos.
3. O BIOS escolhe um dispositivo de boot.
4. O primeiro setor do dispositivo, com 512 bytes, é carregado na memória.
5. O BIOS verifica se os dois últimos bytes são `55 AA`.
6. Se a assinatura for válida, o BIOS transfere a execução ao setor carregado.

O endereço físico tradicional de carga é `0x7C00`. O BIOS pode representar
esse mesmo endereço como `CS:IP = 0000:7C00` ou `CS:IP = 07C0:0000`, pois, em
modo real, ambos apontam para o mesmo endereço físico:

```text
endereço físico = segmento × 16 + deslocamento

0000:7C00 = 0x0000 × 16 + 0x7C00 = 0x07C00
07C0:0000 = 0x07C0 × 16 + 0x0000 = 0x07C00
```

O programa não deve presumir valores úteis em `AX`, `BX`, `DS`, `ES`, `SS`,
`SP` ou na maior parte dos demais registradores. O registrador `DL` normalmente
contém a unidade escolhida pelo BIOS (`0x00` para o primeiro disquete ou `0x80`
para o primeiro disco rígido), mas este stub não acessa o disco e não usa `DL`.

## 2. Modo real de 16 bits

Mesmo um processador x86-64 começa o fluxo de BIOS legado em um ambiente
compatível com o modo real. Nesse modo:

- as instruções e registradores usados pelo stub são predominantemente de 16 bits;
- o espaço endereçável convencional é baseado em pares `segmento:deslocamento`;
- serviços do firmware são chamados por interrupções de software, como `INT 10h`;
- não há proteção de memória, processos, bibliotecas ou sistema operacional;
- o programa é responsável por preparar sua própria pilha e registradores de segmento.

Os registradores de segmento têm 16 bits. O endereço físico é calculado
deslocando o segmento quatro bits à esquerda e somando o deslocamento de 16
bits. Por isso, segmentos diferentes podem representar o mesmo endereço físico.

## 3. Mapa de memória relevante

Este é um mapa simplificado do primeiro megabyte durante o boot:

| Endereço físico | Região | Uso típico |
|---:|---|---|
| `0x00000–0x003FF` | IVT | Tabela de vetores de interrupção do modo real |
| `0x00400–0x004FF` | BDA | Dados mantidos pelo BIOS |
| `0x00500–0x07BFF` | Memória convencional baixa | Área frequentemente disponível para bootloaders |
| `0x07C00–0x07DFF` | Setor de boot | Os 512 bytes de `boot.bin` |
| `0x07E00...` | Memória convencional | Possível área para estágios posteriores |
| `0xA0000–0xAFFFF` | Memória de vídeo VGA | Framebuffer linear do modo gráfico 13h |
| `0xB8000...` | Memória de texto VGA colorido | Usada em modos de texto, não pelo modo 13h |
| `0xC0000...` | ROM de vídeo | Firmware da placa VGA |
| `0xF0000–0xFFFFF` | ROM do BIOS | Código e dados do BIOS do sistema |

O mapa exato pode variar. Em particular, a EBDA (*Extended BIOS Data Area*) é
posicionada pelo firmware e deve ser consultada por bootloaders maiores. O stub
é pequeno e usa somente o setor em `0x7C00`, uma pilha logo abaixo dele e os
serviços do BIOS.

## 4. Organização dos 512 bytes

O arquivo segue a disposição tradicional de um MBR:

| Offset no setor | Tamanho | Conteúdo |
|---:|---:|---|
| `0x000–0x1BD` | 446 bytes | Código, mensagem e preenchimento |
| `0x1BE–0x1FD` | 64 bytes | Quatro entradas de partição de 16 bytes, todas vazias |
| `0x1FE–0x1FF` | 2 bytes | Assinatura de boot `55 AA` |

O núcleo e o módulo de vídeo têm posições iguais em todas as variantes. O
tamanho do módulo e o comprimento de `MODULE_FILE` determinam os offsets
seguintes:

| Região | `halt` | `rtc` | `snake` |
|---|---:|---:|---:|
| Fluxo principal | `0x000–0x019` | `0x000–0x019` | `0x000–0x019` |
| `include/video.asm` | `0x01A–0x033` | `0x01A–0x033` | `0x01A–0x033` |
| Módulo selecionado | `0x034–0x037` | `0x034–0x0A6` | `0x034–0x19C` |
| Mensagem | `0x038–0x055` | `0x0A7–0x0C3` | `0x19D–0x1BB` |
| Preenchimento até a tabela | `0x056–0x1BD` | `0x0C4–0x1BD` | `0x1BC–0x1BD` |
| Bytes utilizados antes da tabela | 86 | 196 | 444 |
| Bytes livres na área de código | 360 | 250 | 2 |

Reservar a tabela de partições não é estritamente necessário para uma imagem
didática de apenas um setor, mas mantém a estrutura compatível com um MBR
tradicional. As entradas estão vazias; portanto, o stub não descreve partições.

## 5. Diretivas do NASM

As linhas a seguir não são executadas pela CPU. São instruções para o montador.

### `bits 16`

```asm
bits 16
```

Informa ao NASM que as instruções devem usar, por padrão, operandos e endereços
de 16 bits. Isso corresponde ao ambiente de modo real fornecido pelo BIOS.

Essa diretiva é o que determina a codificação x86 de 16 bits. A arquitetura do
Mac que executa o NASM não determina a arquitetura do binário produzido.

### `org 0x7c00`

```asm
org 0x7c00
```

`org` significa *origin*. Ele informa ao montador que o primeiro byte do
programa será executado como se estivesse no endereço `0x7C00`.

`org` não insere bytes, não move o programa e não configura nenhum registrador.
Ele apenas influencia o cálculo dos endereços dos símbolos. Como o módulo é
incluído antes de `message`, esse endereço varia:

| Módulo | Endereço de `message` | Bytes de `mov si,message` |
|---|---:|---|
| `halt` | `0x7C38` | `BE 38 7C` |
| `rtc` | `0x7CA7` | `BE A7 7C` |
| `snake` | `0x7D9D` | `BE 9D 7D` |

Os dois bytes do endereço imediato aparecem em ordem *little-endian*: o byte
menos significativo é armazenado primeiro.

### `db`, `dw` e `times`

```asm
db "IGNITION 86", 0x0D, 0x0A
db MODULE_FILE, 0
```

`db` (*define byte*) insere bytes no binário. Cada caractere é armazenado em
ASCII. `0x0D` é `CR` (*carriage return*), que leva o cursor à coluna zero;
`0x0A` é `LF` (*line feed*), que avança uma linha. `MODULE_FILE` é uma macro de
string e, portanto, também pode ser emitida por `db`. O zero final termina a
string. Por exemplo, `MODULE=rtc` mostra `modules/rtc.asm` na segunda linha.

### `%include`

```asm
%include "include/video.asm"
%include MODULE_FILE
```

`MODULE_FILE` chega do Makefile como `"modules/rtc.asm"`,
`"modules/snake.asm"` ou outro caminho válido. `%include` é uma diretiva do
pré-processador do NASM. O conteúdo do arquivo é
inserido textualmente naquele ponto antes da montagem. Isso fornece separação
em módulos no código-fonte, mas não cria carregamento dinâmico nem arquivos
independentes em tempo de execução: todas as rotinas terminam dentro dos mesmos
446 bytes do MBR.

```asm
times 446 - ($ - $$) db 0
```

`times` repete uma emissão. Na expressão:

- `$` é a posição atual do montador;
- `$$` é o início da seção atual;
- `$ - $$` é a quantidade de bytes já emitida;
- `446 - ($ - $$)` é a quantidade que falta até completar 446 bytes.

Assim, o NASM adiciona zeros até o começo da tabela de partições.

```asm
times 64 db 0
```

Reserva 64 bytes zerados para quatro entradas de partição.

```asm
dw 0xaa55
```

`dw` (*define word*) emite uma palavra de 16 bits. Como x86 é *little-endian*,
`0xAA55` é gravado no arquivo como `55 AA`, a assinatura esperada pelo BIOS.

## 6. Registradores utilizados

| Registrador | Partes | Função no stub |
|---|---|---|
| `AX` | `AH` e `AL` | Zerar segmentos, selecionar serviços do BIOS, transportar caracteres, cores e resultados intermediários |
| `BX` | `BH` e `BL` | Página/cor do teletipo e índice da cauda no Snake |
| `CX` | `CH` e `CL` | Hora/minuto do RTC, contadores de laço e repetição de pixels |
| `DX` | `DH` e `DL` | Unidade de boot na entrada, segundos do RTC, ticks, coordenadas e scan-related data dos módulos |
| `SI` | — | Ponteiro da mensagem e índice dos vetores da cobra |
| `DI` | — | Offset calculado dentro do framebuffer VGA |
| `SP` | — | Ponteiro do topo da pilha |
| `CS` | — | Segmento do código; preparado pelo BIOS |
| `DS` | — | Segmento usado para ler a mensagem por `DS:SI` |
| `ES` | — | Zerado no núcleo e depois apontado para `0xA000` pelo Snake |
| `SS` | — | Segmento da pilha usado com `SP` |
| `IP` | — | Endereço da próxima instrução, alterado implicitamente por saltos e interrupções |
| `FLAGS` | — | Contém, entre outros, `IF`, `DF` e `ZF` |

Os registradores de 16 bits podem ser divididos em bytes. Em `AX`, por exemplo,
`AH` é o byte alto e `AL` é o byte baixo:

```text
AX = [ AH ][ AL ]
      15–8   7–0
```

Alterar `AH` preserva `AL`, e alterar `AL` preserva `AH`.

## 7. Execução instrução por instrução

### 7.1 Desabilitação temporária das interrupções

```asm
cli
```

`CLI` (*Clear Interrupt Flag*) limpa o bit `IF` de `FLAGS`. Enquanto `IF=0`, a
CPU não atende interrupções externas mascaráveis.

Isso é necessário porque `SS` e `SP` serão modificados. Se uma interrupção
externa ocorresse quando apenas um deles tivesse sido configurado, a CPU poderia
salvar dados em uma posição incorreta da memória.

`CLI` não impede uma interrupção de software explícita, como `INT 10h`. Também
não bloqueia NMI, SMI ou reset.

### 7.2 Produção do valor zero

```asm
xor ax, ax
```

`XOR` realiza ou-exclusivo bit a bit. Qualquer valor comparado consigo mesmo
produz zero, portanto `AX` passa a valer `0x0000`.

Essa forma é tradicionalmente menor que carregar um imediato zero:

```asm
xor ax, ax     ; 2 bytes: 31 C0
mov ax, 0      ; 3 bytes: B8 00 00
```

Além de modificar `AX`, `XOR` atualiza flags como `ZF`, `SF`, `PF`, `CF` e
`OF`. Esses valores não são utilizados imediatamente pelo programa.

### 7.3 Inicialização dos segmentos de dados e pilha

```asm
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00
```

Como `AX=0`, os registradores `DS`, `ES` e `SS` tornam-se zero.

`DS=0` é essencial para a string. Na variante padrão `halt`, por exemplo,
`SI=0x7C38` e o endereço físico lido por `DS:SI` é:

```text
0x0000 × 16 + 0x7C38 = 0x7C38
```

Nas outras variantes, `SI` recebe o endereço correspondente apresentado na
tabela da seção 5; `DS` continua sendo zero.

`SS:SP = 0000:7C00` posiciona o topo inicial da pilha imediatamente antes do
setor de boot. A pilha x86 cresce para endereços menores. Um `PUSH` de 16 bits,
por exemplo, primeiro reduziria `SP` para `0x7BFE` e depois gravaria dois bytes
em `0000:7BFE`.

O próprio `INT 10h` usa a pilha. Ao executar a interrupção, a CPU empilha
`FLAGS`, `CS` e `IP`, consumindo pelo menos seis bytes antes de entrar no BIOS.

### 7.4 Reativação das interrupções e direção das strings

```asm
sti
cld
```

`STI` (*Set Interrupt Flag*) solicita que `IF` seja ativado. Em x86, a
habilitação efetiva de interrupções mascaráveis ocorre depois da instrução
seguinte. Isso dá uma pequena janela segura para a instrução que segue `STI`.

`CLD` (*Clear Direction Flag*) limpa `DF`. As instruções de string consultam
essa flag:

- `DF=0`: `SI` e `DI` avançam;
- `DF=1`: `SI` e `DI` recuam.

O laço usa `LODSB` e precisa que `SI` avance, por isso `CLD` é explícito.

### 7.5 Seleção do modo gráfico VGA 13h

```asm
mov ax, 0x0013
int 0x10
```

O BIOS de vídeo é acessado pela interrupção `10h`. O byte `AH` seleciona a
função e `AL` contém o parâmetro da função.

Com `AX=0x0013`:

```text
AH = 0x00    função: definir modo de vídeo
AL = 0x13    modo solicitado: VGA 320×200 com 256 cores
```

`INT 10h` faz a CPU:

1. salvar `FLAGS`, `CS` e `IP` na pilha;
2. consultar o vetor 16 (`0x10`) na IVT;
3. transferir o controle para o BIOS de vídeo;
4. executar o serviço solicitado;
5. retornar normalmente por `IRET`.

O modo 13h possui 320 × 200 = 64.000 pixels e 256 índices de cor. Cada pixel
ocupa exatamente um byte. Como 64.000 bytes cabem em uma janela de 65.536
bytes, o framebuffer inteiro é acessível linearmente pelo segmento `0xA000`:

```text
endereço físico inicial = 0xA000 × 16 = 0xA0000
bytes por linha         = 320
offset do pixel         = y × 320 + x
endereço do pixel       = 0xA0000 + y × 320 + x
```

O byte gravado não contém componentes RGB diretamente; ele seleciona uma das
256 entradas da paleta VGA. O stub ativa o framebuffer, mas delega a
renderização das letras ao teletipo do BIOS.

O código presume o comportamento convencional do BIOS de preservar `DS` nessa
chamada. Uma versão mais defensiva poderia zerar `DS` novamente após `INT 10h`.

### 7.6 Inicialização do ponteiro da mensagem

```asm
mov si, message
```

`message` é resolvido pelo NASM depois que o módulo escolhido foi incluído. Na
variante padrão `halt`, seu valor é `0x7C38`. A instrução carrega esse valor em
`SI`; ela ainda não lê a mensagem, apenas cria um ponteiro.

O endereço efetivo é o par `DS:SI`:

```text
DS:SI = 0000:7C38       ; variante halt
```

### 7.7 Leitura de um caractere

```asm
lodsb
```

`LODSB` significa *load string byte*. Ela equivale conceitualmente a:

```text
AL = memória[DS:SI]
SI = SI + 1            porque DF=0
```

Na primeira passagem da variante `halt`, `AL` recebe o código ASCII de `I`
(`0x49`) e `SI` avança de `0x7C38` para `0x7C39`.

### 7.8 Detecção do fim da string

```asm
test al, al
jz .done
```

`TEST` realiza um AND bit a bit apenas para atualizar as flags; o resultado não
é armazenado. Quando `AL=0`, o resultado é zero e `ZF` (*Zero Flag*) recebe 1.

`JZ` (*Jump if Zero*) salta quando `ZF=1`. Assim, o zero inserido após a string
por `db ..., 0` encerra o laço sem ser desenhado.

### 7.9 Impressão pelo teletipo do BIOS

```asm
mov ah, 0x0e
mov bh, 0
mov bl, 0x0f
int 0x10
```

A função `AH=0x0E` de `INT 10h` é o serviço de teletipo:

| Entrada | Valor | Significado |
|---|---:|---|
| `AH` | `0x0E` | Número da função de teletipo |
| `AL` | caractere | Código ASCII produzido por `LODSB` |
| `BH` | `0` | Página de vídeo |
| `BL` | `0x0F` | Índice de cor usado em modo gráfico |

O BIOS desenha o glifo correspondente e avança sua posição de cursor. Esse
serviço permite mostrar a mensagem sem armazenar uma tabela de fonte no MBR.

Embora `AH` seja alterado, `AL` continua contendo o caractere, pois ambos são
metades diferentes de `AX`. Da mesma forma, configurar `BH` não altera `BL`.

### 7.10 Retorno ao início do laço

```asm
jmp .next
```

`JMP` realiza um salto incondicional. Neste caso, o NASM gera um salto relativo
curto. O binário contém apenas a distância com sinal até `.next`, e não um
endereço absoluto. O próximo `LODSB` lê o caractere apontado pelo `SI` já
incrementado.

### 7.11 Transferência ao módulo selecionado

```asm
.finished:
    call init_module
```

`CALL` empilha o endereço da instrução seguinte e transfere `IP` para
`init_module`. Esse é o contrato comum de entrada para todos os arquivos em
`modules/`. Os módulos atuais não retornam.

Não existe uma instrução de salvaguarda depois do `CALL`: o byte seguinte já é
o início de `video_init`, incluído em `0x7C1A`. Portanto, um módulo novo que
execute `RET` fará a execução cair novamente em código de inicialização de vídeo
com uma pilha inadequada. O contrato atual exige que `init_module` mantenha seu
próprio laço terminal ou transfira o controle para outro código sem retornar.

#### Comportamento do módulo RTC

O RTC é lido pela função `AH=02h` de `INT 1Ah`:

| Registrador de retorno | Conteúdo |
|---|---|
| `CH` | Hora em BCD compactado |
| `CL` | Minuto em BCD compactado |
| `DH` | Segundo em BCD compactado |
| `CF` | 1 quando a leitura não pôde ser concluída |

BCD compactado representa dois dígitos decimais em um byte. O valor `0x26`,
por exemplo, representa o número decimal 26. A função `video_print_bcd` separa
o nibble alto com `SHR AL,4` e o baixo com `AND AL,0Fh`, somando o código ASCII
de `0` a cada um.

O módulo guarda o último segundo exibido. Se `DH` não mudou, ele não redesenha
a tela. Ao mudar, copia hora, minuto e segundo para variáveis, posiciona o
cursor na linha 3 e imprime `RTC HH:MM:SS`.

### 7.12 Espera eficiente com interrupções

```asm
.wait:
    sti
    hlt
    jmp .read
```

`STI` mantém as interrupções mascaráveis habilitadas. `HLT` suspende a CPU sem
consumir um laço ativo. A interrupção periódica do timer acorda a CPU, o handler
do BIOS é executado e o fluxo retorna à instrução após `HLT`, que salta para
uma nova leitura do RTC.

Isso é deliberadamente diferente do antigo laço `CLI; HLT`: com `IF=0`, uma
IRQ comum não acordaria a CPU; com `IF=1`, o timer permite atualizar o relógio.

### 7.13 Módulo alternativo Snake

O arquivo [`modules/snake.asm`](modules/snake.asm) substitui o RTC quando
`MODULE_FILE` aponta para ele. Apenas um módulo é incluído no setor, pois RTC e
Snake simultaneamente ultrapassariam os 446 bytes disponíveis.

O jogo divide parte da tela em uma grade lógica de 40 × 16 células. Cada célula
mede 8 × 8 pixels; as quatro primeiras linhas de caracteres são reservadas para
o título. A conversão de uma célula `(x,y)` para o framebuffer é:

```text
pixel_x = x × 8
pixel_y = (y + 4) × 8
offset  = pixel_y × 320 + pixel_x
```

`snake_cell` configura `ES=0xA000`, calcula esse offset em `DI` e desenha oito
linhas de oito pixels por `REP STOSB`. A cobra usa o índice de cor `0x0A` e o
alimento usa `0x0C`.

O teclado é consultado por `INT 16h`:

| Chamada | Função |
|---|---|
| `AH=01h` | Verifica se existe uma tecla; `ZF=1` significa buffer vazio |
| `AH=00h` | Retira a tecla; o scan code é retornado em `AH` |

Os scan codes usados são `48h` (cima), `50h` (baixo), `4Bh` (esquerda) e `4Dh`
(direita). A temporização usa `INT 1Ah`, função `AH=00h`, que retorna em
`CX:DX` o contador de ticks do BIOS. O movimento ocorre a cada três ticks,
aproximadamente seis vezes por segundo.

No eixo horizontal, o código trata explicitamente `x=40` como `x=0` e o
underflow `x=255` como `x=39`, utilizando todos os 320 pixels. No eixo vertical,
`AND DH,15` implementa o retorno porque 16 é uma potência de dois.
A posição de cada segmento fica nos vetores `snake_x` e `snake_y`; a cada passo,
o último segmento é apagado, os elementos são deslocados e a nova cabeça ocupa
o índice zero. Ao alcançar o alimento, o comprimento cresce até 12 segmentos e
o alimento muda de posição.

Para respeitar o MBR, esta versão compacta não detecta colisão da cabeça com o
próprio corpo. Atravessar as bordas é permitido. Com a mensagem atual contendo
`modules/snake.asm`, a variante Snake ocupa 444 dos 446 bytes anteriores à
tabela de partições, deixando dois bytes livres.

### 7.14 Módulo padrão Halt

O módulo [`modules/halt.asm`](modules/halt.asm) é selecionado quando `MODULE`
não é informado ao Makefile:

```asm
init_module:
    cli

.halt:
    hlt
    jmp .halt
```

`CLI` desabilita interrupções mascaráveis. `HLT` suspende a CPU, e o salto
garante que qualquer retorno excepcional de `HLT` resulte em nova suspensão.
Esse módulo representa a parada definitiva original do boot stub.

## 8. Labels e escopo local

Os nomes `start`, `video_init`, `video_print_string`, `video_print_char`,
`video_set_cursor`, `video_print_bcd`, `init_module` e `message` são labels não
locais. Labels iniciadas por ponto, como `.finished`, `.next`, `.read` e
`.wait`, são locais ao último label não local.

Labels não ocupam espaço no binário. Elas associam nomes a posições e permitem
que o NASM calcule endereços e deslocamentos de saltos.

## 9. Instruções e bytes efetivamente gerados

A desmontagem do `boot.bin` atual começa assim:

| Endereço | Bytes | Instrução |
|---:|---|---|
| `0x7C00` | `FA` | `cli` |
| `0x7C01` | `31 C0` | `xor ax,ax` |
| `0x7C03` | `8E D8` | `mov ds,ax` |
| `0x7C05` | `8E C0` | `mov es,ax` |
| `0x7C07` | `8E D0` | `mov ss,ax` |
| `0x7C09` | `BC 00 7C` | `mov sp,0x7c00` |
| `0x7C0C` | `FB` | `sti` |
| `0x7C0D` | `FC` | `cld` |
| `0x7C0E` | `E8 09 00` | `call video_init` (`0x7C1A`) |
| `0x7C11` | variante | `mov si,message` |
| `0x7C14` | `E8 09 00` | `call video_print_string` (`0x7C20`) |
| `0x7C17` | `E8 1A 00` | `call init_module` (`0x7C34`) |

Em `0x7C11`, o imediato varia com o módulo:

| Variante | Bytes | Instrução resultante |
|---|---|---|
| `halt` | `BE 38 7C` | `mov si,0x7c38` |
| `rtc` | `BE A7 7C` | `mov si,0x7ca7` |
| `snake` | `BE 9D 7D` | `mov si,0x7d9d` |

O módulo comum de vídeo começa em `0x7C1A`, e qualquer módulo selecionado começa
em `0x7C34`. O início de `message` varia porque cada módulo possui tamanho
diferente. Um disassembler sem informações de símbolos tentará interpretar
strings, variáveis e preenchimento como instruções, embora esses bytes sejam
dados.

## 10. O Makefile e a montagem cruzada

O comando principal é:

```sh
make
```

O Makefile consulta a arquitetura da máquina com:

```make
HOST_ARCH := $(shell uname -m)
```

Em um Mac Apple Silicon, `uname -m` normalmente retorna `arm64`. Em uma máquina
x86-64, costuma retornar `x86_64` ou `amd64`.

Essa detecção é informativa e valida o ambiente, mas não muda a codificação do
bootloader. NASM é um montador capaz de produzir código x86 mesmo quando o
executável do NASM está rodando nativamente em ARM64.

A montagem efetiva é:

```sh
nasm -f bin -Wall -Werror -w-reloc-abs-word \
  -DMODULE_FILE='"modules/halt.asm"' \
  -o boot.bin boot.asm
```

As opções significam:

| Opção | Função |
|---|---|
| `-f bin` | Produz um binário plano, sem cabeçalho Mach-O, ELF ou PE |
| `-Wall` | Habilita os avisos gerais do NASM |
| `-Werror` | Transforma avisos em erros de construção |
| `-w-reloc-abs-word` | Desabilita o aviso específico sobre o endereço absoluto de 16 bits intencional usado com `org 0x7c00` |
| `-DMODULE_FILE='"..."'` | Define para o NASM o arquivo que será incluído e impresso |
| `-o boot.bin` | Define o arquivo de saída |
| `boot.asm` | Define o arquivo de entrada |

Não existe linker nesta versão. O NASM já produz diretamente os 512 bytes que
o BIOS carregará. Também não existe biblioteca padrão, runtime C ou formato de
executável: `boot.bin` é apenas uma sequência de bytes.

O Makefile verifica se o resultado tem 512 bytes. `make clean` remove o binário
e `make run` inicia o QEMU.

O módulo é selecionado em tempo de montagem:

```sh
make MODULE=halt
make MODULE=rtc
make MODULE=snake
```

`MODULE=halt` é o padrão. O Makefile transforma o nome em
`modules/$(MODULE).asm` e passa esse caminho ao NASM como `MODULE_FILE`.
`boot.asm` inclui o arquivo sem conhecer nomes específicos de módulos. O
resultado continua sendo um único `boot.bin`.

Qualquer novo `modules/xyz.asm` pode ser selecionado com `make MODULE=xyz`,
desde que defina o label comum `init_module`, não retorne e caiba no limite do
MBR. O Makefile também verifica se o arquivo solicitado existe.

## 11. Execução no QEMU

```sh
make run
```

O alvo executa:

```sh
qemu-system-x86_64 -drive format=raw,file=boot.bin \
  -display cocoa,zoom-to-fit=on
```

`qemu-system-x86_64` emula uma máquina x86-64 completa, inclusive em um Mac
ARM64. `format=raw` informa que `boot.bin` não possui metadados de imagem de
disco. O QEMU apresenta esse arquivo ao BIOS emulado como uma unidade bruta.

A emulação da CPU x86 em um host ARM é diferente da montagem cruzada:

- NASM traduz texto Assembly em bytes x86;
- QEMU interpreta ou traduz esses bytes durante a execução.

## 12. Inspeção do binário

Para confirmar o tamanho:

```sh
wc -c boot.bin
```

Para observar os bytes finais:

```sh
xxd -g 1 -s 496 boot.bin
```

Os últimos dois bytes devem ser `55 aa`.

Para desmontar o prefixo comum do bootloader:

```sh
ndisasm -b 16 -o 0x7c00 boot.bin | sed -n '1,20p'
```

- `-b 16` seleciona instruções de 16 bits;
- `-o 0x7c00` mostra endereços considerando a origem de carga;
- o limite de 20 linhas cobre o núcleo e o início do módulo comum de vídeo sem
  depender do tamanho do módulo selecionado.

Para gerar uma listagem com símbolos e offsets de uma variante específica:

```sh
nasm -f bin -w-reloc-abs-word \
  -DMODULE_FILE='"modules/rtc.asm"' \
  -l boot.lst -o boot.bin boot.asm
```

A listagem do NASM é mais confiável que continuar a desmontagem além do código,
pois ela distingue instruções, strings, variáveis e preenchimento.

Para examinar a área de partições:

```sh
xxd -g 1 -s 446 -l 64 boot.bin
```

Ela deve estar completamente zerada neste projeto.

## 13. Acesso direto ao framebuffer

O programa atual usa o BIOS para desenhar a mensagem. No modo 13h, o acesso
direto a pixels é simples porque cada endereço corresponde a um pixel. O
segmento `ES` pode apontar para `0xA000`:

```asm
mov ax, 0xa000
mov es, ax

; Exemplo: pixel (100, 50)
; DI = 50 * 320 + 100 = 16100
mov di, 16100
mov al, 0x0f        ; índice de cor
mov [es:di], al
```

Nesse exemplo, o endereço físico escrito é `0xA0000 + 16100`. O valor `0x0F`
é um índice da paleta VGA, não uma cor RGB armazenada diretamente.

Para desenhar texto sem usar `INT 10h`, seria necessário:

1. armazenar uma fonte bitmap no binário;
2. localizar o bitmap de cada caractere;
3. percorrer linhas e colunas do glifo;
4. calcular `y × 320 + x` para cada pixel;
5. escrever o índice de cor em `ES:DI`.

Isso é possível dentro do MBR para uma fonte muito pequena ou um conjunto
limitado de caracteres, mas aumenta significativamente o código didático.

## 14. Por que Assembly é apropriado aqui

Um boot sector pode conter código originado de C, mas não é um programa C
convencional. Seriam necessários:

- compilador capaz de gerar código x86 de 16 bits ou configuração equivalente;
- modo *freestanding*, sem biblioteca padrão;
- linker script para posicionar o código em `0x7C00`;
- código Assembly inicial para segmentos, pilha e entrada;
- Assembly inline ou wrappers para interrupções do BIOS;
- controle rigoroso do tamanho e das dependências geradas pelo compilador.

Para este stub, C ocultaria justamente os aspectos que se deseja estudar:
registradores, segmentos, pilha, flags, interrupções e layout binário. C passa a
ser mais interessante em um segundo estágio maior, depois que um pequeno trecho
Assembly estabelece um ambiente de execução bem definido.

## 15. Limitações intencionais

Este programa:

- depende de BIOS legado e não é um aplicativo UEFI;
- usa VGA modo 13h, não VBE nem um framebuffer moderno de alta resolução;
- não habilita A20;
- não cria GDT;
- não entra em modo protegido ou long mode;
- não detecta memória;
- não lê setores adicionais;
- não interpreta partições ou sistemas de arquivos;
- não carrega kernel ou segundo estágio;
- não restaura o modo de vídeo;
- não possui tratamento abrangente de erros do BIOS; o módulo RTC trata `CF=1`
  repetindo a leitura.

Essas ausências fazem parte do objetivo: isolar e tornar observável o menor
fluxo útil de inicialização gráfica por BIOS.
