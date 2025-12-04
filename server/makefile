CC = $(CROSS_COMPILE)gcc
CFLAGS = -Wall -Wextra -Werror -g -std=gnu11
TARGET = aesdsocket
OBJS = aesdsocket.o

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS)

aesdsocket.o: aesdsocket.c
	$(CC) $(CFLAGS) -c aesdsocket.c

clean:
	rm -f $(TARGET) $(OBJS)
