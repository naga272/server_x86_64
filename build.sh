#!/bin/bash
sudo lsof -i :9000
nasm -f elf64 -g server.asm -o server.o
ld server.o -o server

