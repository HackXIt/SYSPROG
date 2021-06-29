/* IPC.c
 *   by Nikolaus Rieder
 *
 * Created:
 *   6/28/2021, 2:29:13 PM
 * Last edited:
 *   6/29/2021, 5:35:53 PM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Contains functions which are used in both sender & receiver
**/

/*--- COMMON LIBRARIES ---*/
#include <stdio.h>	   // perror()
#include <unistd.h>	   // getopt()
#include <stdlib.h>	   // atoi()
#include <sys/mman.h>  // POSIX shared memory library
#include <semaphore.h> // POSIX semaphore library
#include <sys/stat.h>  /* For mode constants */
#include <fcntl.h>	   /* For O_* constants */
#include <errno.h>	   // For errno obviously

/*--- CUSTOM LIBRARIES ---*/
#include "ipc.h"

/*--- MACROS ---*/
#define SHARED_SEM_MODE S_IRWXU
#define SHARED_MEM_MODE S_IRWXU

// #define DEBUG

static void print_help(char const *argzero)
{
	printf("%s [OPTIONS]... [ARGUMENTS]...\n", argzero);
	printf("Application to receive/send data from a different process.\n\n");
	printf("The application uses the POSIX library/implementation for Inter-Process-Communication.\n");
	printf("Data is read/written character-per-character.\n\n");
	printf("----OPTIONS:\n");
	printf("\t -h \t\t print this help text.\n");
	printf("\t -m size\t size of the used ringbuffer.\n");
}

unsigned int parse_args(int argc, char *const argv[])
{
	char option;
	int elements = -1; // Number of elements given by option
	char *valid_options = "hm:";
	if (argc == 1)
	{
		fprintf(stderr, "Usage: %s -m size\n", argv[0]);
		exit(EXIT_FAILURE);
	}
	while ((option = getopt(argc, argv, valid_options)) != -1)
	{
		switch (option)
		{
		case 'm':
			elements = atoi(optarg);
			break;
		case 'h':
			print_help(argv[0]);
			exit(EXIT_SUCCESS);
		case '?':
			fprintf(stderr, "Usage: %s -m size\n", argv[0]);
			exit(EXIT_FAILURE);
		default:
			fprintf(stderr, "Usage: %s -m size\n", argv[0]);
			exit(EXIT_FAILURE);
		}
	}
	if (elements < 0)
	{
		errno = EINVAL;
		perror("Given number was negative or 0");
		exit(EXIT_FAILURE);
	}
	return elements;
}

void initialize_ringbuffer(ringbuffer_t *rb, unsigned int elements)
{
	rb->size = elements;
	rb->sem_r_name = SHARED_SEM_R;
	rb->sem_w_name = SHARED_SEM_W;
	rb->memory_name = SHARED_MEMORY;

	rb->sem_read = create_shared_semaphore(rb->sem_r_name, 0);
	rb->sem_write = create_shared_semaphore(rb->sem_w_name, 1);
	if (rb->sem_read == NULL || rb->sem_write == NULL)
	{
		fprintf(stderr, "Couldn't create semaphores!\n");
		exit(EXIT_FAILURE);
	}
	int shared_fd = create_shared_memory(rb->memory_name, rb->size * sizeof(char *));
	if (shared_fd == IPC_ERROR)
	{
		destroy_shared_semaphore(rb->sem_r_name, rb->sem_read);
		destroy_shared_semaphore(rb->sem_w_name, rb->sem_write);
		exit(EXIT_FAILURE);
	}
	rb->memory = attach_shared_memory(shared_fd, rb->size * sizeof(char *));
	close(shared_fd);
	if (rb->memory == NULL)
	{
		destroy_shared_semaphore(rb->sem_r_name, rb->sem_read);
		destroy_shared_semaphore(rb->sem_w_name, rb->sem_write);
		exit(EXIT_FAILURE);
	}
}

int enter_critical_section(sem_t *semaphore)
{
	if (semaphore == NULL)
	{
		errno = EINVAL;
		return IPC_ERROR;
	}
#ifdef DEBUG
	printf("Now entering critical section.\n");
#endif
	while (1)
	{
		int const signal = sem_wait(semaphore);

		if (signal == -1)
		{
			if (errno == EINTR)
			{
				continue;
			}
			perror("ERROR in sem_wait()");
			return IPC_ERROR;
		}
		return IPC_SUCCESS;
	}
}

int exit_critical_section(sem_t *semaphore)
{
	if (semaphore == NULL)
	{
		errno = EINVAL;
		return IPC_ERROR;
	}
#ifdef DEBUG
	printf("Now exiting critical section.\n");
#endif
	int const signal = sem_post(semaphore);
	if (signal == -1)
	{
		perror("ERROR in sem_post()");
		return IPC_ERROR;
	}
	return IPC_SUCCESS;
}

/* --- DEPRECATED --- */
// int post_to_semaphore(sem_t *semaphore)
// {
// #ifdef DEBUG
// 	printf("Posted to semaphore.\n");
// #endif
// 	return sem_post(semaphore);
// }

// SHARED_MEMORY ------------------------------

static int open_shared_memory(char *filename, int oflag)
{
	if (filename == NULL)
	{
		errno = EINVAL;
		return IPC_ERROR;
	}
	int shared_fd;
	//  Get or create shared memory object
	shared_fd = shm_open(filename, oflag, S_IRWXU);
	if (shared_fd == -1)
	{
		perror("ERROR in shm_open() during open");
		return IPC_ERROR;
	}
	return shared_fd;
}

int create_shared_memory(char *filename, int size)
{
	// RDWR == Read-Write | O_CREAT == Create, if it doesn't exist | O_EXCL == Throw error, if it exists
	int shared_fd = open_shared_memory(filename, O_RDWR | O_CREAT);
	if (shared_fd == IPC_ERROR)
	{
		// Error already written
		return IPC_ERROR;
	}
	if (ftruncate(shared_fd, size) == -1)
	{
		perror("ERROR in ftruncate() during creation");
		return IPC_ERROR;
	}
	return shared_fd;
}

char *attach_shared_memory(int shared_fd, size_t length)
{
	char *shared_mem = mmap(NULL, length, PROT_READ | PROT_WRITE, MAP_SHARED, shared_fd, 0);
	if (shared_mem == MAP_FAILED)
	{
		perror("ERROR in mmap() during attach");
		shm_unlink(SHARED_MEMORY);
		return NULL;
	}
	close(shared_fd); // File-descriptor can be closed because memory is attached
	return shared_mem;
}
int detach_shared_memory(char *shared_mem, size_t length)
{
	if (shared_mem == NULL)
	{
		errno = EINVAL;
		return IPC_ERROR;
	}
	if (munmap(shared_mem, length) == -1)
	{
		perror("ERROR in munmap() during detach");
		return IPC_ERROR;
	}
	return IPC_SUCCESS;
}
int destroy_shared_memory(char *filename)
{
	if (filename == NULL)
	{
		errno = EINVAL;
		return IPC_ERROR;
	}
	if (shm_unlink(filename) == -1)
	{
		if (errno == ENOENT)
		{
			return IPC_SUCCESS;
		}
		perror("ERROR in shm_unlink() during destroy");
		return IPC_ERROR;
	}
	return IPC_SUCCESS;
}

// SHARED_SEMAPHORE ------------------------------

static sem_t *open_shared_semaphore(char *filename, int oflag, unsigned int initial)
{
	// filename was already checkout in outer-function
	sem_t *shared_sem;
	shared_sem = sem_open(filename, oflag, SHARED_SEM_MODE, initial);
	if (shared_sem == SEM_FAILED)
	{
		perror("ERROR in sem_open() during creation");
		return NULL;
	}
	return shared_sem;
}

/* --- DEPRECATED --- */
// sem_t *get_shared_semaphore(char *filename)
// {
// 	if (filename == NULL)
// 	{
// 		errno = EINVAL;
// 		return NULL;
// 	}
// 	sem_t *shared_sem;
// 	shared_sem = sem_open(filename, 0);
// 	if (shared_sem == SEM_FAILED)
// 	{
// 		perror("ERROR in sem_open() during fetch");
// 		return NULL;
// 	}
// 	return shared_sem;
// }

sem_t *create_shared_semaphore(char *filename, unsigned int initial)
{
	if (filename == NULL)
	{
		errno = EINVAL;
		return NULL;
	}
	sem_t *shared_sem;
	shared_sem = open_shared_semaphore(filename, O_CREAT, initial);
	if (shared_sem == NULL)
	{
		// Error already written
		return NULL;
	}
	return shared_sem;
}

int detach_shared_semaphore(char *filename)
{
	if (filename == NULL)
	{
		errno = EINVAL;
		return IPC_ERROR;
	}
	if (sem_unlink(filename) == -1)
	{
		perror("ERROR in sem_unlink() during detach");
		return IPC_ERROR;
	}
	return IPC_SUCCESS;
}

int destroy_shared_semaphore(char *filename, sem_t *shared_sem)
{
	if (filename == NULL)
	{
		errno = EINVAL;
		return IPC_ERROR;
	}
	if (sem_close(shared_sem) == -1)
	{
		perror("ERROR in sem_close() during destroy");
		return IPC_ERROR;
	}
	if (sem_unlink(filename) == -1)
	{
		perror("ERROR in sem_unlink() during destroy");
		return IPC_ERROR;
	}
	return IPC_SUCCESS;
}