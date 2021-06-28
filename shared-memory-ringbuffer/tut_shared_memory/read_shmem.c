// Source: https://www.youtube.com/watch?v=WgVSq-sgHOc

#include <string.h>
#include <stdio.h>

#include "shared_memory.h"

int main(int argc, char const *argv[])
{
	if (argc != 1)
	{
		printf("usage - %s //no args\n", argv[0]);
		return -1;
	}

	// grab the shared memory block
	char *block = attach_memory_block(FILENAME, BLOCK_SIZE);
	if (block == NULL)
	{
		printf("ERROR: Could not get block\n");
		return -1;
	}

	printf("Reading: \"%s\"\n", block);

	detach_memory_block(block);

	return 0;
}
