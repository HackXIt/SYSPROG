#include <stdio.h>
#include <unistd.h>

int main(int argc, char const *argv[])
{
	int pipefd[2];
	pipe(pipefd);
	close(pipefd[1]);
	FILE *stream = fdopen(pipefd[0]);
	fclose(stream);
	return 0;
}
