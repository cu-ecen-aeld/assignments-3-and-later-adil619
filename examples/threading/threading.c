#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <pthread.h>

#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

/**
 * Thread function
 * Sleeps, attempts to obtain mutex, sleeps again, releases.
 */
void* threadfunc(void* thread_param)
{
    struct thread_data* td = (struct thread_data*)thread_param;

    if (td == NULL) {
        ERROR_LOG("thread_param is NULL");
        return NULL;
    }

    // Sleep before obtaining mutex
    usleep(td->wait_to_obtain_ms * 1000);

    // Obtain the mutex
    if (pthread_mutex_lock(td->mutex) != 0) {
        ERROR_LOG("Failed to lock mutex");
        td->thread_complete_success = false;
        return td;
    }

    // Hold mutex for required time
    usleep(td->wait_to_release_ms * 1000);

    // Release mutex
    if (pthread_mutex_unlock(td->mutex) != 0) {
        ERROR_LOG("Failed to unlock mutex");
        td->thread_complete_success = false;
        return td;
    }

    td->thread_complete_success = true;
    return td;
}


/**
 * Starts a thread that:
 *  1. waits wait_to_obtain_ms
 *  2. locks mutex
 *  3. waits wait_to_release_ms
 *  4. unlocks mutex
 */
bool start_thread_obtaining_mutex(
        pthread_t *thread,
        pthread_mutex_t *mutex,
        int wait_to_obtain_ms,
        int wait_to_release_ms)
{
    if (thread == NULL || mutex == NULL) {
        ERROR_LOG("Invalid parameters");
        return false;
    }

    // Allocate thread data
    struct thread_data *td = malloc(sizeof(struct thread_data));
    if (td == NULL) {
        ERROR_LOG("malloc failed for thread_data");
        return false;
    }

    // Fill structure
    td->mutex = mutex;
    td->wait_to_obtain_ms = wait_to_obtain_ms;
    td->wait_to_release_ms = wait_to_release_ms;
    td->thread_complete_success = false;

    // Create thread
    int rc = pthread_create(thread, NULL, threadfunc, td);
    if (rc != 0) {
        ERROR_LOG("pthread_create failed");
        free(td);
        return false;
    }

    return true;
}
