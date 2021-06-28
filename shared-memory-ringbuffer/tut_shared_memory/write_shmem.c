// Source: https://www.youtube.com/watch?v=WgVSq-sgHOc

#include <string.h>
#include <stdio.h>

#include "shared_memory.h"

int main(int argc, char const *argv[])
{
	if (argc != 2)
	{
		printf("usage - %s [stuff to write]", argv[0]);
		return -1;
	}

	// grab the shared memory block
	char *block = attach_memory_block(FILENAME, BLOCK_SIZE);
	if (block == NULL)
	{
		printf("ERROR: couldn't get block\n");
		return -1;
	}

	printf("Writing: \"%s\"\n", argv[1]);
	strncpy(block, argv[1], BLOCK_SIZE);

	detach_memory_block(block);

	return 0;
}
