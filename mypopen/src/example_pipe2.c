
#include <sys/types.h>
#include <sys/wait.h> // -> pid_t
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char *argv[])
{
	int pipefd[2]; // pipe file-descriptor, [0] is start of pipe = 'r', [1] is end of pipe = 'w'
	// Data written to the write end of the pipe is buffered by the kernel until it is read from the read end of the pipe.
	// What is a pipe? => pipe(7) => https://man7.org/linux/man-pages/man7/pipe.7.html
	pid_t cpid; // child process ID
	char buf[BUFSIZ];

	if (pipe(pipefd) == -1) // create pipe and check for error
	{
		perror("pipe");
		exit(EXIT_FAILURE);
	}

	cpid = fork(); // Duplicate process
	if (cpid == -1)
	{
		perror("fork");
		exit(EXIT_FAILURE);
	}

	if (cpid == 0)
	{ // Child writes program output to pipe
		// sleep(60);
		close(pipefd[0]); // Close unused read end
		dup2(pipefd[1], STDOUT_FILENO);
		write(STDOUT_FILENO, "--- Program output ---\n", sizeof("--- Program output ---\n"));
		char *cmd = "ls";
		// char *args = "-lh";
		// Working code
		// if (execl("/bin/sh", "sh", "-c", cmd, (char *)NULL) == -1)
		// {
		// 	perror("execlp");
		// }
		// Non-working code => CRASHES like the little shit piece that it is... fucking fuckity fuck shit fuck
		if (execlp(cmd, cmd, "-l", "-h", (char *)NULL) == -1)
		{
			perror("execlp");
		}
		write(STDOUT_FILENO, "--- Program end ---\n", sizeof("--- Program end ---\n"));
		write(STDOUT_FILENO, "\n", 1);
		// close(pipefd[1]);
		_exit(EXIT_SUCCESS);
	}
	else
	{					  // Parent reads output from pipe
		close(pipefd[1]); // Close unused write end
		while (read(pipefd[0], &buf, 1) > 0)
			write(STDOUT_FILENO, &buf, 1);
		close(pipefd[0]); // Closing pipe after write;
		wait(NULL);		  // Wait for child process
		exit(EXIT_SUCCESS);
	}
}