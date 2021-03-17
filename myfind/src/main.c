#include <stdio.h>
#include <string.h>
#include <syscall.h>
#include <stdlib.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <stdbool.h>

// enum options
// {
// 	USER;
// 	ID;
// 	TYPE;
// 	PRINT;
// 	LS;
// }

typedef struct parameters
{
	char *user_name;
	unsigned int user_id;
	char *type; // valid are 'bcdpfls'
	bool print;
	bool ls;
	char *target_dir;
} params_t;

params_t *check_params(int param_count, const char *const params);
void do_dir(const char *dir_name, const params_t *const params);
void do_entry(const char *entry_name, const params_t *const params);

int main(int argc, char const *argv[])
{
	params_t params = {
		.user_name = "asdf",
		.user_id = 1000,
		.type = NULL,
		.print = true,
		.ls = false,
		.target_dir = "."};
	// params = check_params(argc, argv);
	do_dir(params.target_dir, &params);
	return 0;
}

params_t *check_params(int param_count, const char *const params)
{
	if (param_count == 1)
	{
		return NULL;
	}
}

void do_dir(const char *dir_name, const params_t *const params)
{
	DIR *cwd = opendir(dir_name);
	struct dirent *entity;

	while (entity = readdir(cwd))
	{
		// do_entry(dirent->d_name, params);
		if ((entity->d_type == 4) && ((strcmp(entity->d_name, ".") != 0) && (strcmp(entity->d_name, "..") != 0)))
		{
			printf("Entering directory \"%s\":\n", entity->d_name);
			do_dir(entity->d_name, params);
		}
		else
		{
			struct stat file_stats;
			stat(entity->d_name, &file_stats);
			switch (file_stats.st_mode & __S_IFMT)
			{
			case __S_IFSOCK:
				putchar('s');
				break;
			case __S_IFLNK:
				putchar('l');
				break;
			case __S_IFBLK:
				putchar('b');
				break;
			case __S_IFDIR:
				putchar('d');
				break;
			case __S_IFCHR:
				putchar('c');
				break;
			case __S_IFIFO:
				putchar('p');
				break;
			case __S_IFREG:
				putchar('f');
				break;
			default:
				putchar('-');
				break;
			}
			printf(" %s - %ld of type %d\n", entity->d_name, file_stats.st_ino, entity->d_type);
		}
	}

	closedir(cwd);
}

// void do_entry(const char *entry_name, const params_t *const params)
// {
// }