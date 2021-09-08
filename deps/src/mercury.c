#include "mercury.h"
#include "unistd.h"

void MicroSleep(int us) {
    usleep(us);
}