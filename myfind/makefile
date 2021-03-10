CC=gcc
INC=-iquote/home/rini-debian/git-stash/SYSPROG/myfind/inc
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
$(BUILD)%.o: %.c %.h
	$(CC) $(CFLAGS) $(INC) -c $< -o $@

# Here are my targets

all: myfind

# Production-Version
# myfind: main.c myfind.o mygetopt.o
# 	$(CC) $(CFLAGS) $^ -o $(BUILD)$@

# Development-Version
myfind: main.c
 	$(CC) $(CFLAGS) $^ -o $(BUILD)$@

clean:
	$(BUILD)*.o $(BUILD)myfind

# TODO Doxygen Target
