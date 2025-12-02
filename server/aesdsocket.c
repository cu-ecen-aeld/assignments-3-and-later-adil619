#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <syslog.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>

#define PORT 9000
#define DATAFILE "/var/tmp/aesdsocketdata"

static int server_fd = -1;
static int client_fd = -1;

void cleanup_and_exit(int sig)
{
    syslog(LOG_INFO, "Caught signal, exiting");

    if (client_fd != -1) close(client_fd);
    if (server_fd != -1) close(server_fd);

    remove(DATAFILE);

    closelog();
    exit(EXIT_SUCCESS);
}

void install_signal_handlers(void)
{
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));

    sa.sa_handler = cleanup_and_exit;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
}

void daemonize_process(void)
{
    pid_t pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    if (setsid() < 0) exit(EXIT_FAILURE);

    pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    umask(0);
    chdir("/");

    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    open("/dev/null", O_RDONLY);
    open("/dev/null", O_WRONLY);
    open("/dev/null", O_WRONLY);
}

int main(int argc, char *argv[])
{
    bool daemon_mode = false;
    if (argc == 2 && strcmp(argv[1], "-d") == 0) {
        daemon_mode = true;
    }

    openlog("aesdsocket", LOG_PID, LOG_USER);

    install_signal_handlers();

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        syslog(LOG_ERR, "socket failed: %s", strerror(errno));
        exit(EXIT_FAILURE);
    }

    int enable = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable));

    struct sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    servaddr.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
        syslog(LOG_ERR, "bind failed: %s", strerror(errno));
        exit(EXIT_FAILURE);
    }

    if (daemon_mode) {
        daemonize_process();
    }

    if (listen(server_fd, 10) < 0) {
        syslog(LOG_ERR, "listen failed: %s", strerror(errno));
        exit(EXIT_FAILURE);
    }

    char recvbuf[1024];

    while (1) {
        struct sockaddr_in clientaddr;
        socklen_t addrlen = sizeof(clientaddr);

        client_fd = accept(server_fd, (struct sockaddr *)&clientaddr, &addrlen);
        if (client_fd < 0) continue;

        syslog(LOG_INFO, "Accepted connection from %s",
               inet_ntoa(clientaddr.sin_addr));

        FILE *fp = fopen(DATAFILE, "a+");
        if (!fp) {
            close(client_fd);
            continue;
        }

        ssize_t bytes;
        bool got_newline = false;

        while ((bytes = recv(client_fd, recvbuf, sizeof(recvbuf) - 1, 0)) > 0) {
            recvbuf[bytes] = '\0';
            fputs(recvbuf, fp);

            if (strchr(recvbuf, '\n') != NULL) {
                got_newline = true;
                break;
            }
        }

        fflush(fp);

        if (got_newline) {
            fseek(fp, 0, SEEK_SET);
            char sendbuf[1024];
            size_t r;

            while ((r = fread(sendbuf, 1, sizeof(sendbuf), fp)) > 0) {
                send(client_fd, sendbuf, r, 0);
            }
        }

        fclose(fp);

        syslog(LOG_INFO, "Closed connection from %s",
               inet_ntoa(clientaddr.sin_addr));

        close(client_fd);
        client_fd = -1;
    }

    return 0;
}
