/*
 * This test program repeatedly tries to read from a file. It's useful
 * for testing live migration semantics of virtiofs.
 *
 * Build: gcc -o virtiofs-test test.c
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

int main() {
  const char filename[] = "/myfs/foo";
  printf("Opening: %s\n", filename);

  int fd = open(filename, O_RDONLY);

  if (fd < 0) {
    perror("open");
    return EXIT_FAILURE;
  }

  char buf[1024];
  int rc;

  while (1) {
    sleep(1);

    memset(buf, 0, 1024);
    lseek(fd, 0, SEEK_SET);

    /* Ensure trailing NUL byte. */
    rc = read(fd, buf, 1024 - 1);

    if (rc <= 0) {
      /*
       * Ideally, we never end up here. The file descriptor should
       * remain readable regardless of what happens.
       */
      perror("read");
      continue;
    }

    puts(buf);
  }
}
