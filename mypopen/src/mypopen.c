/* MYPOPEN.c
 *   by Nikolaus Rieder
 *
 * Created:
 *   4/15/2021, 9:13:25 PM
 * Last edited:
 *   5/25/2021, 1:02:19 AM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Re-Implementation of popen, pclose for student assignment
**/

/*--- COMMON LIBRARIES ---*/
#include <stdio.h>	   // -> fdopen()
#include <unistd.h>	   // -> pipe(), fork(), dup2(), exec(), read()/write()
#include <stdlib.h>	   // -> system() -> sh
#include <sys/wait.h>  // -> waitpid() & stat_loc
#include <sys/stat.h>  // -> fstat()
#include <sys/types.h> // -> st_mode
#include <string.h>	   // -> strsep()
#include <errno.h>

/*--- CUSTOM LIBRARIES ---*/
#include "mypopen.h"

/*--- MACROS ---*/
/* NOTE DEBUG_CHILD is only useful with: (gdb) set follow-fork-mode child
It is used to debug the child process and still get the output of the process.
*/
// #define DEBUG_CHILD
// #define VERBOSE
/* NOTE This implements the solution using /bin/sh instead of directly calling the desired program
Using the shell is generally the preferred method, because it provides additional features that would be hard to implement
See here: https://stackoverflow.com/questions/48884454/why-does-popen-invoke-a-shell-to-execute-a-process
*/
#define ALTERNATIVE

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
pid_t mypid = -1;
int myfd = -1;

FILE *mypopen(const char *command, const char *type)
{
	if (mypid != -1)
	{
		errno = EAGAIN;
		return NULL;
	}
	if ((command == NULL) || (type == NULL))
	{
		errno = EINVAL;
		return NULL;
	}
	FILE *pipe_stream;
	int pipefd[2];
	if (pipe(pipefd) == -1) // create a pipe
	{
		perror("pipe creation failed!\n");
	}
#ifndef ALTERNATIVE
	char **arguments = tokenize_parameters(command);
	if (arguments == NULL)
	{
		fprintf(stderr, "Command couldn't be tokenized!\n");
		exit(EXIT_FAILURE);
	}
#endif
#ifdef DEBUG_CHILD
	char buf[BUFFER];																// Buffer for debug-output;
	printf("\n--- mypopen ---\n--- command: %s | mode: %s ---\n\n", command, type); // Seperator for readability
#endif
	/* NOTE dup2() MUST be done inside individual processes...
	because is intended to duplicate the pipe INTO STDIN or STDOUT of the individual process
			dup2(pipefd[0], STDIN_FILENO);	// duplicate stdin into pipe read
			dup2(pipefd[1], STDOUT_FILENO); // duplicate stdout into pipe write
	*/
	mypid = fork();
	if (mypid == -1)
	{
		perror("fork failed");
		exit(EXIT_FAILURE);
	}
	if (mypid == 0)
	{								// This is the child-process block.
		if (strcmp(type, "r") == 0) // read-block of child-process
		{

			close(pipefd[0]); // closing unused read-end
			// in the child, the STDOUT is on the read end of the pipe
			dup2(pipefd[1], STDOUT_FILENO);
			close(pipefd[1]); // closing write-end because duplication exists in STDOUT_FILENO
		}
		else if (strcmp(type, "w") == 0) // write-block of child-process
		{
			close(pipefd[1]); // closing unused write-end
			// in the child, the STDIN is on the write end of the pipe
			dup2(pipefd[0], STDIN_FILENO);
			close(pipefd[0]);
		}
		else // invalid type given
		{
			close(pipefd[0]);
			close(pipefd[1]);
			errno = EINVAL;
			return NULL;
		}
// The below is explained in detail @ exec(3) => man exec
/* NOTE learning exec(3) from my failures...
		execl("/bin/sh", "sh", "-c", command, (char *)NULL); // => SHOULDN'T BE used as it leaves a zombie shell and doesn't exit!
		execl("/bin/ls", "-lh", (char *)NULL); // Doesn't work because it is missing argv[0] => "ls", the 1st param can't be in argv[0]
		execlp("ls -lh", (char *)NULL); // Doesn't work because 1st parameter is only used for searching PATH
		execv(command, (char *) NULL); // alternatively, this can be used to provide an argument-vector (argv) instead of an argument-list
		execlp(command, command, (char *)NULL); // "ls -lh" = argv[0] | parameters must be tokenized to properly work
		execlp("ls", "ls", "-l", "-h", (char *)NULL); // works but is static
		*/
#ifndef ALTERNATIVE
		execvp(arguments[0], arguments);
#endif
#ifdef ALTERNATIVE
		execl("/bin/sh", "sh", "-c", command, NULL);
#endif
		sleep(5);
		_exit(127); // Exits and closes all file-descriptors
	}
	else
	{ // This is the parent-process block.
		// Currently only reading output of child-process, because testing with 'ls'
		if (strcmp(type, "r") == 0) // read-block of parent-process
		{
			close(pipefd[1]); // Closing unused write-end
			myfd = pipefd[0];
			pipe_stream = fdopen(pipefd[0], type);
#ifdef DEBUG_CHILD
			int ret = 0;
			while ((ret = read(pipefd[0], &buf, 1)) > 0)
			{
				write(fileno(stdout), &buf, 1);
			}
#endif
		}
		else if (strcmp(type, "w") == 0) // write-block of parent-process
		{
			close(pipefd[0]); // Closing unused read-end
			myfd = pipefd[1];
			pipe_stream = fdopen(pipefd[1], type);
#ifdef DEBUG_CHILD
			int ret = 0;
			while ((ret = write(pipefd[1], &buf, 1)) > 0)
			{
				read(fileno(stdin), &buf, 1);
			}
#endif
		}
		else
		{
			close(pipefd[0]);
			close(pipefd[1]);
			errno = EINVAL;
			return NULL;
		}
		if (pipe_stream == NULL)
		{
			perror("fdopen failed!\n");
			exit(EXIT_FAILURE);
		}
	}
#ifndef ALTERNATIVE
	free(arguments);
#endif
	return pipe_stream;
}

int mypclose(FILE *stream)
{
	if (mypid == -1)
	{
		errno = ECHILD;
		return -1;
	}
	if (stream == NULL)
	{
		errno = EINVAL;
		if (myfd > 0)
		{
			close(myfd);
		}
		return -1;
	}
	if (myfd != fileno(stream))
	{
		errno = EINVAL;
		if (myfd > 0)
		{
			close(myfd);
		}
		return -1;
	}
	int child_exit_status = 0;
	pid_t child = -1;
	fclose(stream);
	// child = wait(&child_exit_status); // This waits for the next child process to exit
	child = waitpid(mypid, &child_exit_status, 0);
	if (child != mypid)
	{
		fprintf(stderr, "Undefined behaviour!\n");
	}
#ifdef VERBOSE
	printf("PID: %d - EXIT_CODE: %d\n", child, child_exit_status);
#endif
	mypid = -1;
	myfd = -1;
	return child_exit_status;
}

#ifndef ALTERNATIVE
char **tokenize_parameters(const char *param_string)
{
	char *string = calloc(strlen(param_string) + 1, sizeof(char)); // +1 because of Nullbyte at end of String
	if (string == NULL)
	{
		fprintf(stderr, "Out of Memory!\n");
		return NULL;
	}
	// unsigned int size = strlen(param_string) + 1;
	// char string[size];
	strcpy(string, param_string);
	char **tokens = calloc(1, sizeof(char *));
	if (tokens == NULL)
	{
		free(string);
		fprintf(stderr, "Out of Memory!\n");
		return NULL;
	}
	char *delims = " ";
	char *token = strtok(string, delims);
	tokens[0] = token;
	unsigned int token_count = 1;
	while (token != NULL)
	{
		tokens = (char **)realloc(tokens, (token_count + 1) * sizeof(char *));
		if (tokens == NULL)
		{
			perror("Out of memory!\n");
			free(string);
			free(tokens);
			exit(EXIT_FAILURE);
		}
		else
		{
			token = strtok(NULL, delims);
			tokens[token_count] = token;
			token_count++;
		}
	}
	// free(string);
	return tokens;
}
#endif