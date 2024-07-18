#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

int main() {
  int fd = open("/myfs/foo", O_RDONLY);
  char buf[1024];
  while(1) {
    memset(buf, 0, 1024);
    lseek(fd, 0, SEEK_SET);
    read(fd, buf, 1024);
    puts(buf);
    sleep(1);
  }
}
