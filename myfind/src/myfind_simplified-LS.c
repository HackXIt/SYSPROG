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

void do_dir(const char *dir_name);

int main(int argc, char const *argv[])
{
	if (argc > 1)
	{
		do_dir(argv[1]);
	}
	return 0;
}

void do_dir(const char *dir_name)
{
	DIR *cwd = opendir(dir_name);
	struct dirent *entity;

	while ((entity = readdir(cwd)))
	{
		if ((entity->d_type == 4) && ((strcmp(entity->d_name, ".") != 0) && (strcmp(entity->d_name, "..") != 0)))
		{
			printf("Entering directory \"%s\":\n", entity->d_name);
			do_dir(entity->d_name);
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