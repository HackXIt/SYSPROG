#ifndef MYPOPEN_H
#define MYPOPEN_H
FILE *mypopen(const char *command, const char *type);
int mypclose(FILE *stream);
#endif