// #define _DEFAULT_SOURCE
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
	char line1[BUFSIZ];
	char line2[BUFSIZ];

	char *command = "ls -l";
	char *mode = "r";

	fp = popen(command, mode);
	printf("Original:\n");
	while (fgets(line1, sizeof(line1), fp))
	{
		printf("line: %s", line1);
	}
	printf("Exit: %d\n", pclose(fp));

	fp = mypopen(command, mode);
	printf("My version:\n");
	while (fgets(line2, sizeof(line2), fp))
	{
		printf("line: %s", line2);
	}
	printf("Exit: %d\n", mypclose(fp));

	exit(0);
}