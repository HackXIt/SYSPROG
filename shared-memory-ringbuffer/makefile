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

all: sender receiver

# This source/executable is for learning purposes of Interprocess-Communication
# It follows the instructions of the Tutorials I watched
tutorial: tutorial.c tutorial.h
	$(CC) $(CFLAGS) $< -o $(BUILD)$@

# SHared Memory RingBuffer => SHMRB
# Custom library for project, if there's any functions that are used in sender & receiver
shmrb: ipc.c ipc.h
	$(CC) $(CFLAGS) $< -o $(BUILD)$@

# Required project target
sender: sender.c ipc.o
	$(CC) $(CFLAGS) $^ -o $(BUILD)$@

# Required project target
receiver: receiver.c ipc.o
	$(CC) $(CFLAGS) $^ -o $(BUILD)$@

# Example source showcasing usage for shared memory - based on Manpages
example1: example_shm.c
	${CC} ${CFLAGS} $^ -o ${BUILD}$@

# Example source showcasing usage for semaphores - based on Manpages
example2: example_semaphore.c
	${CC} ${CFLAGS} ${LIBS} $^ -o ${BUILD}$@

clean:
	rm $(BUILD)*.o $(BUILD)shmrb $(BUILD)sender $(BUILD)receiver $(BUILD)example1 $(BUILD)example2

# TODO make target for test-file
# test:

instlib:
	sudo cp ./inc/*.a /usr/local/lib

.PHONY: clean instlib client-server-example