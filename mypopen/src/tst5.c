#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char**argv) {
		int fd[2];
		pipe(fd);

		pid_t p=fork();
		if (p==0) {
			close(fd[0]);
			dup2(fd[1],1);
			close(fd[1]);
			execlp("ls","ls", "-la", NULL);
			exit(5);
		} else {
			close(fd[1]);
			FILE *f=fdopen(fd[0],"r");
			char buf[512];
			while (fgets(buf,sizeof(buf),f)) {
				printf("RECEIVED: %s\n", buf);
			}
			fclose(f);
		}
}
