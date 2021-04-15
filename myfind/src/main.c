/* MAIN.c
 *   by Nikolaus Rieder
 *
 * Created:
 *   4/15/2021, 7:40:04 PM
 * Last edited:
 *   4/15/2021, 8:25:01 PM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Program to find directory entries, simplified re-implementation of
 *   'find' in linux
**/

/*--- COMMON LIBRARIES ---*/

#include <stdio.h>	  // input & output
#include <string.h>	  // string manipulation
#include <dirent.h>	  // For directory structure
#include <errno.h>	  // For error-output
#include <stdbool.h>  // For readability
#include <stdlib.h>	  // For memory-allocation
#include <sys/stat.h> // For file-information

/*--- CUSTOM LIBRARIES ---*/

/*--- MACROS ---*/

/* Directory Entries => https://www.gnu.org/software/libc/manual/html_node/Directory-Entries.html
unknown_type	> DT_UNKNOWN
regular_file	> DT_REG 
directory		> DT_DIR
named_pipe		> DT_FIFO
socket			> DT_SOCK 
char_device		> DT_CHR 
block_device	> DT_BLK 
symbolic_link	> DT_LNK 
*/

// enum options
// {
// 	USER,
// 	NAME,
// 	TYPE,
// 	PRINT,
// 	LS
// };

enum output
{
	none,  // No output flag = 0
	print, // Print flag = 1
	ls,	   // ls flag = 2
	help   // help flag = 3
};

typedef struct params
{
	char *start;	  // Entry point of search
	char *user;		  // username or id to search with
	char *file;		  // filename pattern to search with
	char *type_flags; // Array of searched types, valid types are "bcdpfls"
	int output;		  // formats the output accordingly
} params_t;

void print_help();
params_t *check_params(int counter, char const **unsafe_params);
int do_entry(const char *entry_name, const params_t *const params); // 0 = success, 1 = fail
int do_dir(const char *dir_name, const params_t *const params);		// 0 = success, 1 = fail

int main(int argc, char const *argv[])
{
	params_t *params = NULL;
	if (argc == 1)
	{
		print_help();
		exit(EXIT_SUCCESS);
	}
	else if (argc > 1)
	{
		params = check_params(argc, argv); // TODO NULL-Check
		if (params->output == help)
		{
			print_help();
			exit(EXIT_SUCCESS);
		}
	}
	else
	{
		fprintf(stderr, "Invalid Execution: %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}
	if (do_entry(params->start, params))
	{
		fprintf(stderr, "%s - Error with entry: %s\n", argv[0], params->start);
		exit(EXIT_FAILURE);
	}
	else
	{
		exit(EXIT_SUCCESS);
	}
}

void print_help()
{ // TODO Help text output
	printf("Help-text-output not implemented yet\n");
}

params_t *check_params(int counter, char const **unsafe_params)
{
	params_t *n_params = calloc(1, sizeof(params_t)); // TODO Null-Check
	n_params->output = none;
	char *valid_params[] = {"-user", "-name", "-type", "-print", "-ls"};
	char *valid_types = "bcdpfls";
	// Super inefficient at the moment
	for (int i = 1; i < counter; i++)
	{
		if (strcmp(unsafe_params[i], valid_params[0]) == 0) // User given
		{
			n_params->user = calloc(strlen(unsafe_params[i + 1]) + 1, sizeof(char)); // TODO NULL-Check
			strcpy(n_params->user, unsafe_params[i + 1]);
		}
		if (strcmp(unsafe_params[i], valid_params[1]) == 0) // Name given
		{
			// FIXME SEGMENTATION FAULT because no argument is provided
			n_params->file = calloc(strlen(unsafe_params[i + 1]) + 1, sizeof(char)); // TODO NULL-Check
			strcpy(n_params->file, unsafe_params[i + 1]);
		}
		if (strcmp(unsafe_params[i], valid_params[2]) == 0) // Type given
		{
			bool bset = false;
			bool cset = false;
			bool dset = false;
			bool pset = false;
			bool fset = false;
			bool lset = false;
			bool sset = false;
			char *token;
			char valid_characters[8] = "";
			char delimiter[2] = ",";
			char *chars;
			strcpy(chars, unsafe_params[i + 1]);
			token = strtok(chars, delimiter);
			while (token != NULL) // FIXME Infinite loop
			{
				if (strlen(token) == 1)
				{
					// Compare token - Duplicated tokens will be ignored
					switch (*token)
					{
					case 'b':
						if (!bset)
						{
							bset = true;
							strcat(valid_characters, token);
						}
						break;
					case 'c':
						if (!cset)
						{
							cset = true;
							strcat(valid_characters, token);
						}
						break;
					case 'd':
						if (!dset)
						{
							dset = true;
							strcat(valid_characters, token);
						}
						break;
					case 'p':
						if (!pset)
						{
							pset = true;
							strcat(valid_characters, token);
						}
						break;
					case 'f':
						if (!fset)
						{
							fset = true;
							strcat(valid_characters, token);
						}
						break;
					case 'l':
						if (!lset)
						{
							lset = true;
							strcat(valid_characters, token);
						}
						break;
					case 's':
						if (!sset)
						{
							sset = true;
							strcat(valid_characters, token);
						}
						break;
					}
				}
				else
				{
					fprintf(stderr, "Invalid type set: %s", token);
					exit(EXIT_FAILURE);
				}
				strtok(NULL, delimiter);
			}
			n_params->type_flags = calloc(strlen(valid_characters) + 1, sizeof(char)); // TODO Null-Check
			strcpy(n_params->type_flags, valid_characters);
		}
		// FIXME If both output flags are given, the latter will be used, as the first one gets overwritten
		if (strcmp(unsafe_params[i], valid_params[3]) == 0) // Print flag given
		{
			n_params->output = print;
		}
		if (strcmp(unsafe_params[i], valid_params[4]) == 0) // LS flag given
		{
			n_params->output = ls;
		}
	}
	return n_params;
}

int do_entry(const char *entry_name, const params_t *const params)
{
	struct stat entry_properties;
	stat(entry_name, &entry_properties);
	return EXIT_SUCCESS;
}