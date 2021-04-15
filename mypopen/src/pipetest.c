#include <stdio.h>
#include <stdlib.h>

#include "../inc/mypopen.h"

int main()
{
	FILE *fp;
	char line[130];

	char *command = "ls -l";
	char *mode = "r";

	fp = popen(command, mode);
	printf("Original:\n");
	while (fgets(line, sizeof(line), fp))
	{
		printf("line: %s", line);
	}
	pclose(fp);

	fp = mypopen(command, mode);
	printf("My version:\n");
	while (fgets(line, sizeof(line), fp))
	{
		printf("line: %s", line);
	}
	mypclose(fp);
	exit(0);
}