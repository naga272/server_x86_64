#!/bin/bash

nasm -f elf64 -g server.asm -o server.o
ld server.o -o server
fuser -k 9000/tcp
#./server
