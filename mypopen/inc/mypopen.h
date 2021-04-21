#ifndef MYPOPEN_H
#define MYPOPEN_H
#define BUFFER 130
// extern is implicit in functions, so not used below
FILE *mypopen(const char *command, const char *type);
int mypclose(FILE *stream);
#endif