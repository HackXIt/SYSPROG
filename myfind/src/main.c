#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <errno.h>
#include <stdbool.h> // For readability

/* Directory Entries => https://www.gnu.org/software/libc/manual/html_node/Directory-Entries.html
unknown_type
regular_file
directory
named_pipe (FIFO)
socket
char_device
block_device
symbolic_link
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
	enum output;	  // formats the output accordingly
} params_t;

void print_help();
params_t *check_params(int counter, char const **unsafe_params);
int do_entry(const char *entry_name, const params_t *const params); // 0 = success, 1 = fail
int do_dir(const char *dir_name, const params_t *const params);		// 0 = success, 1 = fail

int main(int argc, char const *argv[])
{
	params_t params;
	if (argc == 1)
	{
		print_help();
		exit(EXIT_SUCCESS);
	}
	else if (argc > 1)
	{
		params = check_params(argc, argv);
		if (params.output == help)
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
	if (do_entry(params.start, params))
	{
		fprintf(stderr, "%s - Error with entry: %s\n", argv[0], params.start);
		exit(EXIT_FAILURE)
	}
	else
	{
		exit(EXIT_SUCCESS)
	}
}

params_t *check_params(int counter, char const **unsafe_params)
{
	params_t *n_params = calloc(sizeof(params_t), 1); // TODO Null-Check
	char *valid_params[] = {"-user", "-name", "-type", "-print", "-ls"};
	char *valid_types = "bcdpfls";
	// Super inefficient at the moment
	for (int i = 1; i < counter; i++)
	{
		if (strcmp(unsafe_params[i], valid_params[0]) == 0) // User given
		{
			n_params.user = calloc(sizeof(char), strlen(unsafe_params[i + 1])); // TODO NULL-Check
			strcpy(n_params.user, unsafe_params[i + 1]);
		}
		if (strcmp(unsafe_params[i], valid_params[1]) == 0) // Name given
		{
			n_params.file = calloc(sizeof(char), strlen(unsafe_params[i + 1])); // TODO NULL-Check
			strcpy(n_params.file, unsafe_params[i + 1]);
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
			token = strtok(unsafe_params[i + 1], delimiter);
			while (token != NULL)
			{
				if (strlen(token) == 1)
				{
					// Compare token - Duplicated tokens will be ignored
					switch (token)
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
			}
			n_params.type_flags = calloc(sizeof(char), strlen(valid_characters)); // TODO Null-Check
			strcpy(n_params.type_flags, valid_characters);
		}
		// FIXME If both output flags are given, the latter will be used, as the first one gets overwritten
		if (strcmp(unsafe_params[i], valid_params[3]) == 0) // Print flag given
		{
			n_params.output = print;
		}
		if (strcmp(unsafe_params[i], valid_params[4]) == 0) // LS flag given
		{
			n_params.output = ls;
		}
	}
}

int do_entry(const char *entry_name, const params_t *const params)
{
	return EXIT_SUCCESS;
}