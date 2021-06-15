// Source: https://openbook.rheinwerk-verlag.de/linux_unix_programmierung/Kap09-006.htm#RxxKap09006040002D91F028181

#include <stdio.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/shm.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#define SHMDATASIZE 1024
#define BUFFERSIZE (SHMDATASIZE - sizeof(int))
#define SN_EMPTY 0
#define SN_FULL 1
/* ---------- Bei BSD-UNIXen auskommentieren ------------ */
#if defined(__GNU_LIBRARY__) && !defined(_SEM_SEMUN_UNDEFINED)
/* union semun is defined by including <sys/sem.h> */
#else
/* according to X/OPEN we have to define it ourselves */
union semun
{
	int val;			   /* Werte für  SETVAL        */
	struct semid_ds *buf;  /* Puffer IPC_STAT, IPC_SET */
	unsigned short *array; /* Array für GETALL, SETALL */
						   /* Linux specific part:     */
	struct seminfo *__buf; /* Puffer für IPC_INFO      */
};
#endif
/* -------------------------------------------------------- */
static void locksem(int semid, int semnum);
static void unlocksem(int semid, int semnum);
static void waitzero(int semid, int semnum);
static int safesemget(key_t key, int nsems, int semflg);
static int safesemctl(int semid, int semnum,
					  int cmd, union semun arg);
static int safesemop(int semid, struct sembuf *sops,
					 unsigned nsops);
static int DeleteSemid = 0;
static int DeleteShmid = 0;
static void locksem(int semid, int semnum)
{
	struct sembuf sb;
	sb.sem_num = semnum;
	sb.sem_op = -1;
	sb.sem_flg = SEM_UNDO;
	safesemop(semid, &sb, 1);
	return;
}
static void unlocksem(int semid, int semnum)
{
	struct sembuf sb;
	sb.sem_num = semnum;
	sb.sem_op = 1;
	sb.sem_flg = SEM_UNDO;
	safesemop(semid, &sb, 1);
}
static void waitzero(int semid, int semnum)
{
	struct sembuf sb;
	sb.sem_num = semnum;
	sb.sem_op = 0;
	sb.sem_flg = 0;
	safesemop(semid, &sb, 1);
	return;
}
static int safesemget(key_t key, int nsems, int semflg)
{
	int retval;
	retval = semget(key, nsems, semflg);
	if (retval == -1)
		printf("Semaphor-Schlüssel %d, nsems %d konnte"
			   " nicht erstellt werden",
			   key, nsems);
	return retval;
}
static int
safesemctl(int semid, int semnum, int cmd, union semun arg)
{
	int retval;
	retval = semctl(semid, semnum, cmd, arg);
	if (retval == -1)
		printf("Fehler: Semaphor mit ID %d, semnum %d, "
			   "Kommando %d\n",
			   semid, semnum, cmd);
	return retval;
}
static int
safesemop(int semid, struct sembuf *sops, unsigned nsops)
{
	int retval;
	retval = semop(semid, sops, nsops);
	if (retval == -1)
		printf("Fehler: Semaphor mit ID %d (%d Operation)\n",
			   semid, nsops);
	return retval;
}
typedef void (*sighandler_t)(int);
static sighandler_t
my_signal(int sig_nr, sighandler_t signalhandler)
{
	struct sigaction neu_sig, alt_sig;
	neu_sig.sa_handler = signalhandler;
	sigemptyset(&neu_sig.sa_mask);
	neu_sig.sa_flags = SA_RESTART;
	if (sigaction(sig_nr, &neu_sig, &alt_sig) < 0)
		return SIG_ERR;
	return alt_sig.sa_handler;
}