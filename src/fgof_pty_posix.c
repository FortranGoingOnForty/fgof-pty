#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

enum {
    FGOF_PTY_OK = 0,
    FGOF_PTY_ERR_OPEN = 1,
    FGOF_PTY_ERR_PIPE = 2,
    FGOF_PTY_ERR_FORK = 3,
    FGOF_PTY_ERR_EXEC = 4,
    FGOF_PTY_ERR_FCNTL = 5
};

static void fgof_pty_disable_echo(int fd) {
    struct termios tio;

    if (tcgetattr(fd, &tio) != 0) {
        return;
    }

    tio.c_lflag &= (tcflag_t) ~(ECHO | ECHONL);
    tcsetattr(fd, TCSANOW, &tio);
}

static void fgof_pty_build_argv(const char *program,
                                const char *argv_blob,
                                int argc,
                                int arg_stride,
                                char **argv) {
    int i;

    argv[0] = (char *) program;
    for (i = 0; i < argc; ++i) {
        argv[i + 1] = (char *) (argv_blob + (i * arg_stride));
    }
    argv[argc + 1] = NULL;
}

int fgof_pty_spawn(const char *program,
                   const char *argv_blob,
                   int argc,
                   int arg_stride,
                   int rows,
                   int cols,
                   int *master_fd,
                   int *child_pid,
                   int *sys_errno) {
    int exec_pipe[2];
    int flags;
    int master;
    int pid;
    int child_errno;
    ssize_t read_count;
    char *slave_name;

    *master_fd = -1;
    *child_pid = -1;
    *sys_errno = 0;

    master = posix_openpt(O_RDWR | O_NOCTTY);
    if (master < 0) {
        *sys_errno = errno;
        return FGOF_PTY_ERR_OPEN;
    }

    if (grantpt(master) != 0 || unlockpt(master) != 0) {
        *sys_errno = errno;
        close(master);
        return FGOF_PTY_ERR_OPEN;
    }

    slave_name = ptsname(master);
    if (slave_name == NULL) {
        *sys_errno = errno;
        close(master);
        return FGOF_PTY_ERR_OPEN;
    }

    if (pipe(exec_pipe) != 0) {
        *sys_errno = errno;
        close(master);
        return FGOF_PTY_ERR_PIPE;
    }

    flags = fcntl(exec_pipe[1], F_GETFD);
    if (flags < 0 || fcntl(exec_pipe[1], F_SETFD, flags | FD_CLOEXEC) != 0) {
        *sys_errno = errno;
        close(exec_pipe[0]);
        close(exec_pipe[1]);
        close(master);
        return FGOF_PTY_ERR_FCNTL;
    }

    pid = fork();
    if (pid < 0) {
        *sys_errno = errno;
        close(exec_pipe[0]);
        close(exec_pipe[1]);
        close(master);
        return FGOF_PTY_ERR_FORK;
    }

    if (pid == 0) {
        int slave_fd;
        struct winsize ws;
        char **argv;

        close(exec_pipe[0]);

        if (setsid() < 0) {
            child_errno = errno;
            write(exec_pipe[1], &child_errno, sizeof(child_errno));
            _exit(127);
        }

        slave_fd = open(slave_name, O_RDWR);
        if (slave_fd < 0) {
            child_errno = errno;
            write(exec_pipe[1], &child_errno, sizeof(child_errno));
            _exit(127);
        }

        (void) ioctl(slave_fd, TIOCSCTTY, 0);

        ws.ws_row = (unsigned short) rows;
        ws.ws_col = (unsigned short) cols;
        ws.ws_xpixel = 0;
        ws.ws_ypixel = 0;
        (void) ioctl(slave_fd, TIOCSWINSZ, &ws);

        fgof_pty_disable_echo(slave_fd);

        if (dup2(slave_fd, STDIN_FILENO) < 0 ||
            dup2(slave_fd, STDOUT_FILENO) < 0 ||
            dup2(slave_fd, STDERR_FILENO) < 0) {
            child_errno = errno;
            write(exec_pipe[1], &child_errno, sizeof(child_errno));
            _exit(127);
        }

        if (slave_fd > STDERR_FILENO) {
            close(slave_fd);
        }

        argv = (char **) calloc((size_t) argc + 2U, sizeof(char *));
        if (argv == NULL) {
            child_errno = ENOMEM;
            write(exec_pipe[1], &child_errno, sizeof(child_errno));
            _exit(127);
        }

        fgof_pty_build_argv(program, argv_blob, argc, arg_stride, argv);
        execvp(program, argv);

        child_errno = errno;
        write(exec_pipe[1], &child_errno, sizeof(child_errno));
        _exit(127);
    }

    close(exec_pipe[1]);
    child_errno = 0;
    read_count = read(exec_pipe[0], &child_errno, sizeof(child_errno));
    if (read_count > 0) {
        *sys_errno = child_errno;
        close(exec_pipe[0]);
        close(master);
        waitpid(pid, NULL, 0);
        return FGOF_PTY_ERR_EXEC;
    }
    if (read_count < 0) {
        *sys_errno = errno;
        close(exec_pipe[0]);
        close(master);
        kill(pid, SIGKILL);
        waitpid(pid, NULL, 0);
        return FGOF_PTY_ERR_PIPE;
    }
    close(exec_pipe[0]);

    flags = fcntl(master, F_GETFL);
    if (flags < 0 || fcntl(master, F_SETFL, flags | O_NONBLOCK) != 0) {
        *sys_errno = errno;
        close(master);
        kill(pid, SIGKILL);
        waitpid(pid, NULL, 0);
        return FGOF_PTY_ERR_FCNTL;
    }

    *master_fd = master;
    *child_pid = pid;
    return FGOF_PTY_OK;
}

int fgof_pty_read_some(int fd, char *buffer, size_t buffer_len, int *sys_errno) {
    ssize_t rc;

    *sys_errno = 0;
    rc = read(fd, buffer, buffer_len);
    if (rc < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
            return 0;
        }
        *sys_errno = errno;
        return -1;
    }

    return (int) rc;
}

int fgof_pty_write_all(int fd, const char *buffer, size_t buffer_len, int *sys_errno) {
    size_t written;

    *sys_errno = 0;
    written = 0;
    while (written < buffer_len) {
        ssize_t rc;

        rc = write(fd, buffer + written, buffer_len - written);
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                usleep(1000);
                continue;
            }
            *sys_errno = errno;
            return -1;
        }
        written += (size_t) rc;
    }

    return 0;
}

int fgof_pty_resize(int fd, int rows, int cols, int *sys_errno) {
    struct winsize ws;

    *sys_errno = 0;
    ws.ws_row = (unsigned short) rows;
    ws.ws_col = (unsigned short) cols;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;

    if (ioctl(fd, TIOCSWINSZ, &ws) != 0) {
        *sys_errno = errno;
        return -1;
    }

    return 0;
}

int fgof_pty_close_session(int master_fd, int child_pid, int *sys_errno) {
    int attempt;
    int status;

    *sys_errno = 0;

    if (master_fd >= 0 && close(master_fd) != 0) {
        *sys_errno = errno;
        return -1;
    }

    if (child_pid <= 0) {
        return 0;
    }

    (void) kill(child_pid, SIGHUP);

    for (attempt = 0; attempt < 50; ++attempt) {
        pid_t rc;

        rc = waitpid(child_pid, &status, WNOHANG);
        if (rc == child_pid) {
            return 0;
        }
        if (rc < 0) {
            if (errno == ECHILD) {
                return 0;
            }
            *sys_errno = errno;
            return -1;
        }

        if (attempt == 15) {
            (void) kill(child_pid, SIGTERM);
        } else if (attempt == 30) {
            (void) kill(child_pid, SIGKILL);
        }

        usleep(10000);
    }

    if (waitpid(child_pid, &status, 0) < 0 && errno != ECHILD) {
        *sys_errno = errno;
        return -1;
    }

    return 0;
}
