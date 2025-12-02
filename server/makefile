# Simple Makefile that supports cross-compilation via CROSS_COMPILE variable
# Usage:
# make -> builds aesdsocket with default compiler
# make CROSS_COMPILE=arm-linux-gnueabihf- -> builds with cross-compiler prefix

CROSS_COMPILE ?=
CC := $(CROSS_COMPILE)gcc
CFLAGS := -Wall -Wextra -g -std=gnu11
LDFLAGS :=
TARGET := aesdsocket
OUTDIR := .

.PHONY: all default clean

all: $(OUTDIR)/$(TARGET)

default: all

$(OUTDIR)/$(TARGET): aesdsocket.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(OUTDIR)/$(TARGET)
