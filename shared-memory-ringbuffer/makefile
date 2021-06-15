PROJECT=shared_memory_ringbuffer
CC=gcc
IQUOTE=-iquote/home/rini-debian/git-stash/SYSPROG/shared-memory-ringbufer/inc
INC=-Iinc
CFLAGS=${INC} -Wall -Wextra -pedantic -g -Wno-unused-parameter
LIBS=-lpthread -lrt
# CFLAGS=-g -Wno-unused-parameter
BUILD=./build/
# VPATH:=src:build
vpath %.o ./build
vpath %.c ./src
vpath %.h ./inc

# Automatic variable for object files
# Wouldn't be necessary if using -Iinc
${BUILD}%.o: %.c %.h
	$(CC) $(CFLAGS) $(INC) -c $< -o $@

# Automatic variable for object files without headers
# MUST be after the automatic variable above
${BUILD}%.o: %.c
	$(CC) $(CFLAGS) $(INC) -c $< -o $@

# Here are my targets

all: pipetest

# SHared Memory RingBuffer => SHMRB
shmrb: ipc.c ipc.h
	$(CC) $(CFLAGS) $< -o $(BUILD)$@

sender: sender.c ipc.o
	$(CC) $(CFLAGS) $^ -o $(BUILD)$@

receiver: receiver.c ipc.o
	$(CC) $(CFLAGS) $^ -o $(BUILD)$@

example1: example_shm.c
	${CC} ${CFLAGS} $^ -o ${BUILD}$@

example2: example_semaphore.c
	${CC} ${CFLAGS} $^ -o ${BUILD}$@

clean:
	rm $(BUILD)*.o $(BUILD)shmrb $(BUILD)sender $(BUILD)receiver $(BUILD)example1 $(BUILD)example2

# TODO make target for test-file
# test:


instlib:
	sudo cp ./inc/*.a /usr/local/lib

.PHONY: clean instlib