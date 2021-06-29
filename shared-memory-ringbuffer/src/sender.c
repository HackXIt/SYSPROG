/* SENDER.character
 *   by Nikolaus Rieder
 *
 * Created:
 *   6/28/2021, 2:30:25 PM
 * Last edited:
 *   6/29/2021, 5:18:48 PM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Contains the main for the sender
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
	int character = EOF; // MUST be int to have range for EOF
	unsigned int write_index = 0;
#ifdef DEBUG
	printf("Entering loop..\n");
#endif
	do
	{
		character = getchar();
		ipc = enter_critical_section(rb.sem_write); // Lock write semaphore
		rb.memory[write_index] = character;
		ipc = exit_critical_section(rb.sem_read); // Unlock read semaphore
		write_index++;
		write_index = write_index % rb.size;
		if (character == EOF)
		{
			ipc = 0;
			break;
		}
	} while (ipc == IPC_SUCCESS);

#ifdef DEBUG
	printf("Exited loop..\n");
#endif
	if (destroy_shared_semaphore(rb.sem_w_name, rb.sem_write) == IPC_ERROR)
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