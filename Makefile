ASM = nasm
LINK = ld

FILES = ./server.o
EXE = ./server


all: ./server.o $(EXE) run
.PHONY: all


./server.o: ./server.asm
	$(ASM) -f elf64 -g ./server.asm -o ./server.o


$(EXE): $(FILES)
	$(LINK) $(FILES) -o $(EXE)


run: $(EXE)
	$(EXE)


clean: $(FILES) $(EXE)
	rm $(FILES) $(EXE)


db: $(EXE)
	gdb $(EXE)
