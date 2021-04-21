/* MYPOPEN.c
 *   by Nikolaus Rieder
 *
 * Created:
 *   4/15/2021, 9:13:25 PM
 * Last edited:
 *   4/21/2021, 8:34:18 PM
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

/*--- CUSTOM LIBRARIES ---*/
#include "../inc/mypopen.h"

/*--- MACROS ---*/

extern pid_t mypid = -1;

FILE *mypopen(const char *command, const char *type)
{
	// TODO Currently not doing error-detection
	if (mypid != -1)
	{
		fprintf(stderr, "Only 1 open process is supported. Current process ID: %d\n", mypid);
		return NULL;
	}

	int pipefd[2];
	char buf[BUFFER];
	// NOTE the below isn't necessary anymore because my exec() usage was apparantly wrong - will be taken into notes
	// int mode;
	// char *command_dupl = strdup(command);
	// char *program = strsep(&command_dupl, " ");
	// char *arguments = strdup(command + strlen(program) + 1);
	pipe(pipefd); // create a pipe
	// TODO assuming correctness of pipe atm / should be checked
	// NOTE the below doesn't work because stdin & stdout are streams and dup expects a file-descriptor (int)
	// dup2(pipefd[0], stdin);	 // duplicate stdin into pipe-input
	// dup2(pipefd[1], stdout); // duplicate stdout into pipe-output
	// NOTE the below was a missunderstanding of pipes is still here because I want to write it into my notes
	// if (type == "r")
	// {
	// 	close(pipefd[1]);			   // Close write end of pipe
	// 	dup2(STDIN_FILENO, pipefd[0]); // duplicate file-descriptor of stdin to pipe input
	// 	mode = 0;					   // Used later to create file stream from
	// }
	// if (type == "w")
	// {
	// 	close(pipefd[0]);				// Close read end of pipe
	// 	dup2(STDOUT_FILENO, pipefd[1]); // duplicate file-descriptor of stdout to pipe output
	// 	mode = 1;
	// }
	printf("command: %s - mode: %s\n", command, type);
	dup2(STDIN_FILENO, pipefd[0]);	// duplicate stdin into pipe read
	dup2(STDOUT_FILENO, pipefd[1]); // duplicate stdout into pipe write
	mypid = fork();					// TODO Assuming correctness of fork atm / should be checked
	if (mypid == 0)
	{ // This is the child-process block.
		close(pipefd[0]);
		dup2(STDOUT_FILENO, pipefd[1]);
		// FIXME No output ?? I thought I can use 'ls' as a program in /bin/ but that doesn't work
		// execl(strcat("/bin/", program), arguments, (char *)NULL);
		// The below is presented in manpage of system(3)
		execl("/bin/sh", "sh", "-c", command, (char *)NULL); // Why is the extra 'sh' necessary?
		// execv(command, (char *) NULL); // alternativ
		close(pipefd[1]);
		return EXIT_SUCCESS;
	}
	else
	{ // This is the parent-process block.
		// Currently only reading output of child-process, because testing with 'ls'
		close(pipefd[1]);
		while (read(pipefd[0], &buf, 1) > 0)
		{
			write(STDOUT_FILENO, &buf, 1);
		}
		write(STDOUT_FILENO, "\n", 1);
		close(pipefd[0]);
	}
	// NOTE Some code to seperate the command with ' ' in case I need it
	// char **tokens;
	// char *token = strtok(command, " ");
	// tokens[0] = token;
	// int i = 1;
	// while(token != NULL) {
	// 	tokens[i] = token;
	// 	token = strtok(NULL, " ");
	// 	i++;
	// }
	// NOTE the below was used in a previous version of the code
	// switch (mode)
	// {
	// case 0:
	// 	close(pipefd[0]);
	// 	break;
	// case 1:
	// 	close(pipefd[1]);
	// 	break;
	// }
	return fdopen(pipefd[0], type);
}
int mypclose(FILE *stream)
{
	if (mypid == -1)
	{
		fprintf(stderr, "No process was opened!");
		return EXIT_FAILURE;
	}
	// FIXME Hanging on exit...
	waitpid(mypid, NULL, 0); // How does this work?? Needs more research
	// Don't understand stat_loc and options yet completely
	// TODO create list of stat_loc & options with meaning and examples
	return EXIT_SUCCESS;
}