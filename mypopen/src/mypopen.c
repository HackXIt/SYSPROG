/* MYPOPEN.c
 *   by Nikolaus Rieder
 *
 * Created:
 *   4/15/2021, 9:13:25 PM
 * Last edited:
 *   4/15/2021, 9:36:48 PM
 * Auto updated?
 *   Yes
 *
 * Description:
 *   Re-Implementation of popen, pclose for student assignment
**/

/*--- COMMON LIBRARIES ---*/
#include <stdio.h>

/*--- CUSTOM LIBRARIES ---*/
#include "../inc/mypopen.h"

/*--- MACROS ---*/

FILE *mypopen(const char *command, const char *type)
{
	printf("command: %s - mode: %s\n", command, type);
	return NULL;
}
int mypclose(FILE *stream)
{
	return 0;
}