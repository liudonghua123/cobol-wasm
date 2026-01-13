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

// char *getlogin() { return "wasm-user"; }

/* 使用宏将 getlogin 替换为 NULL */
/* 这样 common.c 中的 if (s = getlogin()) 将变为 if (s = NULL) */
#define getlogin() (NULL)

/* 如果之后遇到 getpwuid 或 getuid 报错，也可以加在这里 */
#define getuid() 0
#define getpwuid(uid) (NULL)

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
