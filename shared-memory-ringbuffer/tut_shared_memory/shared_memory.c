// Source: https://www.youtube.com/watch?v=WgVSq-sgHOc

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#include "shared_memory.h"

#define IPC_RESULT_ERROR (-1)

static int get_shared_block(char *filename, int size)
{
	key_t key;

	// Request a key
	// The key is linked to a filename, so that other programs can access it.
	key = ftok(filename, 0); // Give me key '0' associated with file -- There could be multiple associated with a single file.
	if (key == IPC_RESULT_ERROR)
	{
		return IPC_RESULT_ERROR;
	}

	// get shared block --- create it if it doesn't exist

	return shmget(key, size, 0644 | IPC_CREAT); // 0644 | IPC_CREAT is a Bitwise OR-Operation
}

char *attach_memory_block(char *filename, int size)
{
	int shared_block_id = get_shared_block(filename, size);
	char *result;

	if (shared_block_id == IPC_RESULT_ERROR)
	{
		return NULL;
	}

	// map the shared block into this process's memory
	// and give me a pointer to it
	result = shmat(shared_block_id, NULL, 0); // NULL == "put it anywhere" / 0 == Flags or options, but not specified so default
	if (result == (char *)IPC_RESULT_ERROR)
	{
		return NULL;
	}

	return result;
}

// Wrapper around shmdt -- Take the shared memory away (detach)
bool detach_memory_block(char *block)
{
	return (shmdt(block) != IPC_RESULT_ERROR);
}

bool destroy_memory_block(char *filename)
{
	int shared_block_id = get_shared_block(filename, 0);

	if (shared_block_id == IPC_RESULT_ERROR)
	{
		return NULL;
	}

	// IPC_RMID == "Remove this shared memory based on it's ID"
	// Third argument is for information about the destroyed block / NULL means we don't care
	return (shmctl(shared_block_id, IPC_RMID, NULL) != IPC_RESULT_ERROR);
}
