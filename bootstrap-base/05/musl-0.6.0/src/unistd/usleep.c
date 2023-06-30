#include <unistd.h>
#include <time.h>

int usleep(useconds_t useconds)
{
	struct timespec tv = {
		.tv_sec = useconds/1000000,
		.tv_nsec = (useconds%1000000)*1000
	};
	return nanosleep(&tv, &tv);
}
