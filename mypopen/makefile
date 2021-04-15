CC=gcc
INC=-iquote/home/rini-debian/git-stash/SYSPROG/mypopen/inc
CFLAGS=-std=c99 -Wall -Wextra -pedantic -g -Wno-unused-parameter
BUILD=./build/
# VPATH:=src:build
vpath %.o ./build
vpath %.c ./src
vpath %.h ./inc

# This is required for source-files without header-files
#$(BUILD)hashcount.o: hashcount.c
#	$(CC) $(CFLAGS) $(INC) -c $< -o $@

# Automatic variable for object files
${BUILD}%.o: %.c %.h
	$(CC) $(CFLAGS) $(INC) -c $< -o $@

# Here are my targets

all: pipetest

pipetest: pipetest.c $(BUILD)mypopen.o
	$(CC) $(CFLAGS) $^ -o $(BUILD)$@

clean:
	rm $(BUILD)*.o $(BUILD)pipetest

# TODO Doxygen Target
