// Source: https://www.youtube.com/watch?v=WgVSq-sgHOc

#include <string.h>

#include "shared_memory.h"

int main(int argc, char const *argv[])
{
	if (argc != 1)
	{
		printf("usage - %s //no args\n", argv[0]);
		return -1;
	}

	// grab the shared memory block
	char *block = attach_memory_block(FILENAME, BLOCK_SEMAPHORE);
	if (block == NULL)
	{
		printf("ERROR: Could not get block\n");
		return -1;
	}
	return 0;
}
