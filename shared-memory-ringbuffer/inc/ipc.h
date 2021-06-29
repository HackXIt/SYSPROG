#ifndef IPC_H
#define IPC_H
#define IPC_ERROR (-1)
#define IPC_SUCCESS (1)
#define SHARED_MEMORY "/shared_mem"
#define SHARED_SEM_R "/shared_sem_r"
#define SHARED_SEM_W "/shared_sem_w"

#include <semaphore.h> // For sem_t

typedef struct ringbuffer
{
	unsigned int size;
	char *sem_r_name;
	char *sem_w_name;
	sem_t *sem_read;
	sem_t *sem_write;
	char *memory_name;
	char *memory;
} ringbuffer_t;

/************************************************
 * @brief Parses CLI-arguments and returns the ringbuffer size
 * 
 * @note It's up to the calling process to cancel on value 0
 * @param argc Argument Counter from main()
 * @param argv Argument Vector from main()
 * @return unsigned int - returns the size of the ringbuffer or 0 on failure (check errno)
 ***********************************************/
unsigned int parse_args(int argc, char *const argv[]);

/************************************************
 * @brief Wrapper function around sem_wait() to handle errors & signals
 * 
 * @note This is necessary to handle SIGNAL interrupts properly.
 * @param semaphore The semaphore that is used for sem_wait()
 * @return int - returns IPC_SUCCESS or IPC_ERROR on failure
 ***********************************************/
int enter_critical_section(sem_t *semaphore);

/************************************************
 * @brief Wrapper function around sem_post() to handle errors & signals
 * 
 * @param semaphore The semaphore that is used for sem_post()
 * @return int - returns IPC_SUCCESS or IPC_ERROR on failure
 ***********************************************/
int exit_critical_section(sem_t *semaphore);

/************************************************
 * @brief Simplified wrapper function around sem_post()
 * 
 * @note This function just calls sem_post() and returns it's return value
 * @note This function is deprecated and not used anymore.
 * @param semaphore 
 * @return int - the return value of sem_post()
 ***********************************************/
// int post_to_semaphore(sem_t *semaphore);

/************************************************
 * @brief Function to initialize the ringbuffer structure
 * 
 * @param rb Pointer to the struct that shall be initialized
 * @param elements Size of the ringbuffer
 ***********************************************/
void initialize_ringbuffer(ringbuffer_t *rb, unsigned int elements);

// SHARED_MEMORY ------------------------------
/************************************************
 * @brief Create a shared memory object with Read/Write permissions
 * 
 * @note If the object already exists, this function will fail.
 * @param filename The name of the shared memory object (use SHARED_MEMORY)
 * @param size The size of the shared memory object
 * @return int - returns the file-descriptor of the object or IPC_ERROR on failure
 ***********************************************/
int create_shared_memory(char *filename, int size);

/************************************************
 * @brief Attaches a shared memory object into the process with Read/Write permissions
 * 
 * @param shared_fd The file-descriptor of the shared memory object
 * @param length The size of the shared memory object
 * @return char* - returns the address of shared-memory or NULL on failure
 ***********************************************/
char *attach_shared_memory(int shared_fd, size_t length);

/************************************************
 * @brief Detaches a shared memory object from the process
 * 
 * @param shared_mem The address of the shared memory
 * @param length The size of the shared memory object
 * @return int - returns IPC_SUCCESS or IPC_ERROR on failure
 ***********************************************/
int detach_shared_memory(char *shared_mem, size_t length);

/************************************************
 * @brief Destroys (unlinks) a shared memory object
 * 
 * @note The shared memory will effectively be destroyed once all processes using it have closed.
 * @param filename The name of the shared memory object (use SHARED_MEMORY)
 * @return int - returns IPC_SUCCESS or IPC_ERROR on failuree
 ***********************************************/
int destroy_shared_memory(char *filename);

// SHARED_SEMAPHORE ------------------------------
/************************************************
 * @brief Get the shared semaphore object
 * 
 * @note This function will NOT create the semaphore if it doesn't exist yet.
 * @note This function is deprecated and not used anymore.
 * @param filename The name of the shared semaphore (use SHARED_SEMAPHORE)
 * @return sem_t* - returns the semaphore object or NULL on failure
 ***********************************************/
// sem_t *get_shared_semaphore(char *filename);

/************************************************
 * @brief Create a shared semaphore object
 * 
 * @note This function will fail if the semaphore already exists
 * @param filename The name of the shared semaphore (use SHARED_SEMAPHORE)
 * @param initial The initial value, which the semaphore should have (be cautious about overflows)
 * @return sem_t* - returns the created semaphore object or NULL on failure
 ***********************************************/
sem_t *create_shared_semaphore(char *filename, unsigned int initial);

/************************************************
 * @brief Destroys (unlinks & closes) a shared semaphore object
 * 
 * @param filename The name of the shared semaphore (use SHARED_SEMAPHORE)
 * @param shared_sem The semaphore to be closed
 * @return int - returns IPC_SUCCESS or IPC_ERROR on failure
 ***********************************************/
int destroy_shared_semaphore(char *filename, sem_t *shared_sem);

#endif