HOST_ARCH := $(shell uname -m)

ifneq ($(filter arm64 aarch64,$(HOST_ARCH)),)
HOST_TYPE := ARM64
else ifneq ($(filter x86_64 amd64,$(HOST_ARCH)),)
HOST_TYPE := AMD64
else
$(error Arquitetura não suportada: $(HOST_ARCH))
endif

NASM ?= nasm
MODULE ?= halt
SOURCE := boot.asm
OUTPUT := boot.bin
MODULE_FILE := modules/$(MODULE).asm

ifeq ($(wildcard $(MODULE_FILE)),)
$(error Módulo não encontrado: $(MODULE_FILE))
endif

# O valor chega ao NASM como uma string válida para `%include`.
MODULE_DEFINE := -DMODULE_FILE='"$(MODULE_FILE)"'

.PHONY: all run clean FORCE

all: $(OUTPUT)

$(OUTPUT): $(SOURCE) include/video.asm $(MODULE_FILE) FORCE
	@echo "Host $(HOST_TYPE) ($(HOST_ARCH)) -> alvo x86 de 16 bits"
	@echo "Módulo selecionado: $(MODULE)"
	@command -v $(NASM) >/dev/null || { echo "NASM não encontrado"; exit 1; }
	$(NASM) -f bin -Wall -Werror -w-reloc-abs-word $(MODULE_DEFINE) -o $@ $<
	@test "$$(wc -c < $@ | tr -d ' ')" = 512
	@echo "Gerado: $@ (512 bytes)"

run: $(OUTPUT)
	qemu-system-x86_64 -drive format=raw,file=$(OUTPUT) \
		-display cocoa,zoom-to-fit=on

clean:
	rm -f $(OUTPUT)

FORCE:
