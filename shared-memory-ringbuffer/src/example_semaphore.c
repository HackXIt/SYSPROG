// Source: https://www.geeksforgeeks.org/use-posix-semaphores-c/
// C program to demonstrate working of Semaphores
#include <stdio.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>

sem_t mutex;

void *thread(void *arg)
{
	//wait
	sem_wait(&mutex);
	printf("\nEntered..\n");

	//critical section
	sleep(4);

	//signal
	printf("\nJust Exiting...\n");
	sem_post(&mutex);
	return NULL;
}

/* NOTE Explanation to example
2 threads are being created, one 2 seconds after the first one.
But the first thread will sleep for 4 seconds after acquiring the lock.
Thus the second thread will not enter immediately after it is called, it will enter 4 – 2 = 2 secs after it is called.
*/

int main()
{
	sem_init(&mutex, 0, 1);
	pthread_t t1, t2;
	pthread_create(&t1, NULL, thread, NULL);
	sleep(2);
	pthread_create(&t2, NULL, thread, NULL);
	pthread_join(t1, NULL);
	pthread_join(t2, NULL);
	sem_destroy(&mutex);
	return 0;
}