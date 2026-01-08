#ifndef WASI_FIX_H
#define WASI_FIX_H

#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>

// Stubs for missing WASI functions
static inline int kill(pid_t pid, int sig) { return 0; }
static inline pid_t fork(void) { return -1; }
static inline pid_t vfork(void) { return -1; }
static inline int sigaction(int sig, const void *act, void *oact) { return 0; }

// Redirect system() to a stub to avoid clashing with stdlib.h declaration
#define system(x) wasi_system_stub(x)
static inline int wasi_system_stub(const char *command) { return -1; }

#ifndef F_RDLCK
#define F_RDLCK 0
#endif
#ifndef F_WRLCK
#define F_WRLCK 1
#endif
#ifndef F_UNLCK
#define F_UNLCK 2
#endif
#ifndef F_SETLK
#define F_SETLK 6
#endif

#endif
