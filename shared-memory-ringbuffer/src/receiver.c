/* RECEIVER.character
 *   by Nikolaus Rieder
 *
 * Created:
 *   6/28/2021, 2:30:06 PM
 * Last edited:
 *   6/29/2021, 5:18:41 PM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Contains the main for the receiver
**/

/*--- COMMON LIBRARIES ---*/
#include <stdio.h>	// For I/O functions
#include <stdlib.h> // For exit() and exit status codes

/*--- CUSTOM LIBRARIES ---*/
#include "ipc.h"

/*--- MACROS ---*/
// #define DEBUG

int main(int argc, char *const argv[])
{
	unsigned int elements = parse_args(argc, argv);

#ifdef DEBUG
	printf("Ring: %u\n", elements);
#endif
	ringbuffer_t rb = {0};
	initialize_ringbuffer(&rb, elements);
	int ipc = 0;
	int character = EOF;
	unsigned int read_index = 0;
	// Post to semaphore to signal that the receiver is ready.
	// post_to_semaphore(rb.sem_write);
#ifdef DEBUG
	printf("Entering loop..\n");
#endif
	do
	{
		ipc = enter_critical_section(rb.sem_read); // Lock read semaphore
		character = rb.memory[read_index];
		ipc = exit_critical_section(rb.sem_write); // Unlock write semaphore
		read_index++;
		read_index = read_index % rb.size;
		if (character == EOF)
		{
			ipc = 0;
			break;
		}
		putchar(character);
	} while (ipc == IPC_SUCCESS);

#ifdef DEBUG
	printf("Exited loop..\n");
#endif
	if (destroy_shared_semaphore(rb.sem_r_name, rb.sem_read) == IPC_ERROR)
	{
		exit(EXIT_FAILURE);
	}
	if (detach_shared_memory(rb.memory, sizeof(char) * rb.size) == IPC_ERROR)
	{
		exit(EXIT_FAILURE);
	}
	if (destroy_shared_memory(rb.memory_name) == IPC_ERROR)
	{
		exit(EXIT_FAILURE);
	}
	exit(EXIT_SUCCESS);
}
