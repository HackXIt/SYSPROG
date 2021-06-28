// Source: https://www.youtube.com/watch?v=WgVSq-sgHOc

#ifndef SHARED_MEMORY_H
#define SHARED_MEMORY_H

#include <stdbool.h>

//attach a shared memory block
//associate with filename
//create it if it doesn't exist
char *attach_memory_block(char *filename, int size);
bool detach_memory_block(char *block);
bool destroy_memory_block(char *filename);

//all of the programs will share these values
#define BLOCK_SIZE 4096
#define FILENAME "shared_memory.c"

#endif