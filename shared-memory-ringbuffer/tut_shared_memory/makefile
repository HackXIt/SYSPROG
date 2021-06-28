CC=gcc
CFLAGS=-g -Wall
OBJS=shared_memory.o
EXE=write_shmem.elf read_shmem.elf destroy_shmem.elf

%.elf: %.o $(OBJS)
	$(CC) $(CFLAGS) $< $(OBJS) -o $@

%.o: %.c %.h
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

all: $(EXE)

clean:
	rm -rf *.o $(EXE)