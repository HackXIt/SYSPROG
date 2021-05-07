/* MYPOPEN.c
 *   by Nikolaus Rieder
 *
 * Created:
 *   4/15/2021, 9:13:25 PM
 * Last edited:
 *   5/6/2021, 8:22:26 PM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Re-Implementation of popen, pclose for student assignment
**/

/*--- COMMON LIBRARIES ---*/
#include <stdio.h>	  // -> fdopen
#include <unistd.h>	  // -> pipe(), fork(), dup2(), exec(), read()/write()
#include <stdlib.h>	  // -> system() -> sh
#include <sys/wait.h> // -> waitpid() & stat_loc
#include <string.h>	  // -> strsep()
#include <errno.h>

/*--- CUSTOM LIBRARIES ---*/
#include "../inc/mypopen.h"

/*--- MACROS ---*/
// #define _POSIX_C_SOURCE

/*--- Program-Notes ---*/

/* NOTE No output ?? I thought I can use 'ls' as a program in /bin/ but that doesn't work
		 execl(strcat("/bin/", program), arguments, (char *)NULL); => This didn't work!
		 because when using 'execl', every parameter given is seperated by a whitespace.
		*/
/* NOTE Why did I try 'sh' when using execl ?
		The usage of `execl("/bin/sh", "sh", "-c", ...)` was necessary, because execl doesn't include the program path.
		If I want to use 'execl()' I need to provide the absolute path to the program being called.
		By using 'execlp()' I can rely on the PATH variable to provide me with the correct path for said program.
		In security critical situations this shouldn't be done, because it can be abused to direct towards a malicious program.
		*/
/* NOTE Some code to seperate the command with ' ' in case I need it
	// char **tokens;
	// char *token = strtok(command, " ");
	// tokens[0] = token;
	// int i = 1;
	// while(token != NULL) {
	// 	tokens[i] = token;
	// 	token = strtok(NULL, " ");
	// 	i++;
	// }
	*/
/* NOTE the below was used in a previous version of the code
	// switch (mode)
	// {
	// case 0:
	// 	close(pipefd[0]);
	// 	break;
	// case 1:
	// 	close(pipefd[1]);
	// 	break;
	// }
	*/
// NOTE Hanging on exit: was caused by using /bin/sh in execl => use execlp instead
// waitpid(mypid, NULL, 0); // How does this work?? Needs more research

// Don't understand stat_loc and options yet completely
// TODO create list of stat_loc & options with meaning and examples

// FIXME Using external variable... Not best-practice
extern pid_t mypid = -1;

FILE *mypopen(const char *command, const char *type)
{
	// TODO Currently not doing error-detection
	if (mypid != -1)
	{
		fprintf(stderr, "Only 1 open process is supported. Current process ID: %d\n", mypid);
		return NULL;
	}
	FILE *pipe_stream;
	int pipefd[2];
	char buf[BUFFER];
	pipe(pipefd); // create a pipe
				  // TODO assuming correctness of pipe atm / should be checked

	printf("\n--- mypopen ---\ncommand: %s - mode: %s\n\n ---", command, type);
	// TODO MUST be done inside child-process, because works differently with pipe
	// dup2(STDIN_FILENO, pipefd[0]);	// duplicate stdin into pipe read
	// dup2(STDOUT_FILENO, pipefd[1]); // duplicate stdout into pipe write
	mypid = fork(); // TODO Assuming correctness of fork atm / should be checked
	// TODO Currently I've only implemented the behaviour of a child-process writing to stdout
	if (mypid == 0)
	{ // This is the child-process block.
		close(pipefd[0]);
		// in the child, the STDOUT is on the read end of the pipe
		dup2(pipefd[1], STDOUT_FILENO);
		close(pipefd[1]);
		// The below is explained in detail @ exec(3)
		// execl("/bin/sh", "sh", "-c", command, (char *)NULL);
		// execl("/bin/ls", "-lh", (char *)NULL);
		execlp("ls", "ls", "-l", "-h", (char *)NULL);
		// execlp("ls -lh", (char *)NULL);
		// execlp(command, command, (char *)NULL); // "ls -lh" = argv[0]

		// alternatively, this can be used to provide an argument-vector (argv) instead of an argument-list
		// execv(command, (char *) NULL);
		// write(pipefd[1], "\0", 1);
		_exit(EXIT_SUCCESS);
	}
	else
	{ // This is the parent-process block.
		// Currently only reading output of child-process, because testing with 'ls'
		close(pipefd[1]);
		pipe_stream = fdopen(pipefd[0], "r");
		if (pipe_stream == NULL)
		{
			perror("fdopen failed");
		}
		// dup2(STDIN_FILENO, pipefd[0]);
		// int ret = 0;
		// while ((ret = read(pipefd[0], &buf, 1)) > 0) // FIXME program hangs here
		// {
		// 	write(STDOUT_FILENO, &buf, 1);
		// }
		// printf("\nasdf\n");
		// if (ret == -1)
		// {
		// 	printf("%s", strerror(errno));
		// }
		// write(STDOUT_FILENO, "\n", 1);
		// write(STDOUT_FILENO, "\0", 1);
		// close(pipefd[0]);
	}
	// FILE *proc_stream = fdopen(pipefd[0], type); // "r"
	return pipe_stream;
}

int mypclose(FILE *stream)
{
	if (mypid == -1)
	{
		fprintf(stderr, "No process was opened!");
		return EXIT_FAILURE;
	}

	int child_exit_status = 0;
	pid_t child = -1;
	fclose(stream);
	// free(stream);
	// child = wait(&child_exit_status); // This waits for the next child process to exit
	child = waitpid(mypid, &child_exit_status, 0);
	printf("PID: %d - EXIT_CODE: %d", child, child_exit_status);

	return child_exit_status;
}