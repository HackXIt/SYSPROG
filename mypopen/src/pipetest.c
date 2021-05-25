/* PIPETEST.c
 *   by Nikolaus Rieder
 *
 * Created:
 *   5/25/2021, 2:05:57 AM
 * Last edited:
 *   5/25/2021, 2:31:01 AM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Testfile for mypopen exercise
**/

/*--- COMMON LIBRARIES ---*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
/*--- CUSTOM LIBRARIES ---*/
#include "../inc/mypopen.h"
/*--- MACROS ---*/
#define MAX_STRINGS 5

/* NOTE MANPAGES to check out
pipe()
fork()

dup2() -> stdin, stdout

exec(), execl(), execv()

sh()

fdopen()

waitpid()
*/

int main(int argc, char *argv[])
{
	FILE *fp;
	char line1[BUFSIZ];
	char line2[BUFSIZ];
	if (argc == 1)
	{
		// Test 1 - Read mode: ls -l
		char *command = "ls -l";
		char *mode = "r";

		printf("\n---- Test 1 ----\n");
		fp = popen(command, mode);
		printf("- Original: -\n");
		while (fgets(line1, sizeof(line1), fp))
		{
			printf("line: %s", line1);
		}
		printf("- Exit: %d -\n\n", pclose(fp));

		fp = mypopen(command, mode);
		printf("- My version: -\n");
		while (fgets(line2, sizeof(line2), fp))
		{
			printf("line: %s", line2);
		}
		printf("- Exit: %d -\n", mypclose(fp));

		// Test 2 - Write mode: sort
		command = "sort";
		mode = "w";
		char *strings[MAX_STRINGS] = {"echo", "bravo", "alpha",
									  "charlie", "delta"};

		printf("\n---- Test 2 ----\n");
		fp = popen(command, mode);
		printf("- Original: -\n");
		for (int i = 0; i < MAX_STRINGS; i++)
		{
			fputs(strings[i], fp);
			fputc('\n', fp);
		}
		printf("- Exit: %d -\n\n", pclose(fp));

		fp = mypopen(command, mode);
		printf("- My version: -\n");
		for (int i = 0; i < MAX_STRINGS; i++)
		{
			fputs(strings[i], fp);
			fputc('\n', fp);
		}
		printf("- Exit: %d -\n", mypclose(fp));

		exit(EXIT_SUCCESS);
	}
	else
	{
		char option;
		char *command = NULL;
		char *type = NULL;
		char *valid_options = "c:t:";
		while ((option = getopt(argc, argv, valid_options)) != -1)
		{
			printf("%s - %c\n", optarg, optopt);
			switch (option)
			{
			case 'c':
				if (strcmp(optarg, "") == 0)
				{
					fprintf(stderr, "No command provided!\n");
					exit(EXIT_FAILURE);
				}
				command = calloc(strlen(optarg) + 1, sizeof(char));
				printf("command: %s\n", command);
				if (command == NULL)
				{
					fprintf(stderr, "Out of memory!\n");
					exit(EXIT_FAILURE);
				}
				strcpy(command, optarg);
				break;
			case 't':
				if (strcmp(optarg, "") == 0)
				{
					fprintf(stderr, "No type provided!\n");
					exit(EXIT_FAILURE);
				}
				type = calloc(strlen(optarg) + 1, sizeof(char));
				printf("type: %s\n", type);
				if (type == NULL)
				{
					fprintf(stderr, "Out of memory!\n");
					exit(EXIT_FAILURE);
				}
				strcpy(type, optarg);
				break;
			}
		}
		if (command == NULL || type == NULL)
		{
			printf("Command: %s\n", command);
			printf("Type: %s\n", type);
			fprintf(stderr, "Both options are required!\n");
			exit(EXIT_FAILURE);
		}
		if (strcmp(type, "r") == 0)
		{
			int exit_status;
			fp = popen(command, type);
			if (fp == NULL)
			{
				fprintf(stderr, "Null was returned, process creation failed!\n");
				exit(EXIT_FAILURE);
			}
			printf("- Original: -\n");
			while (fgets(line1, sizeof(line1), fp))
			{
				printf("line: %s", line1);
			}
			exit_status = pclose(fp);
			printf("- Exit: %d -\n\n", exit_status);
			fp = mypopen(command, type);
			if (fp == NULL)
			{
				fprintf(stderr, "Null was returned, process creation failed!\n");
				exit(EXIT_FAILURE);
			}
			printf("- My version: -\n");
			while (fgets(line2, sizeof(line2), fp))
			{
				printf("line: %s", line2);
			}
			exit_status = mypclose(fp);
			printf("- Exit: %d -\n", exit_status);
			if (exit_status == -1)
			{
				perror("Closing process failed: ");
				exit(EXIT_FAILURE);
			}
		}
		if (strcmp(type, "w") == 0)
		{
			fprintf(stderr, "Option 'w' not implemented in custom command mode.");
			exit(EXIT_SUCCESS);
		}
	}
}