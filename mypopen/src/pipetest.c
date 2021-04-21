#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>

#include "../inc/mypopen.h"

/* MANPAGES to check out
pipe()
fork()

dup2() -> stdin, stdout

exec(), execl(), execv()

sh()

fdopen()

waitpid()
*/

int main()
{
	FILE *fp;
	char line[BUFFER];

	char *command = "ls -l";
	char *mode = "r";

	fp = popen(command, mode);
	printf("Original:\n");
	while (fgets(line, sizeof(line), fp))
	{
		printf("line: %s", line);
	}
	printf("Exit: %d\n", pclose(fp));

	fp = mypopen(command, mode);
	printf("My version:\n");
	while (fgets(line, sizeof(line), fp))
	{
		printf("line: %s", line);
	}
	printf("Exit: %d\n", mypclose(fp));

	exit(0);
}