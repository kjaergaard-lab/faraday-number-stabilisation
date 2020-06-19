//These are libraries which contain useful functions
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#define MAP_SIZE 262144UL
#define MEM_LOC 0x42000000
 
int main(int argc, char **argv)
{
  int fd;		//File identifier
  int numSamples;	//Number of samples to collect
  void *cfg;		//A pointer to a memory location.  The * indicates that it is a pointer - it points to a location in memory
  char *name = "/dev/mem";	//Name of the memory resource

  uint32_t i = 0;
  const int MAX_NUM_SAMPLES = 16384;
  uint32_t data[MAX_NUM_SAMPLES-1];

  clock_t start, stop;

  for (i = 0;i<MAX_NUM_SAMPLES;i++) {
    data[i] = 0;
  }

/*The following if-else statement parses the input arguments.
argc is the number of arguments.  argv is a 2D array of characters.
argv[0] is the function name, and argv[n] is the n'th input argument*/
  if (argc == 2) {
    numSamples = atoi(argv[1]);	//atof converts the character array argv[1] to a floating point number
  } else  {
    printf("You must supply at least one argument!\n");
    return 0;
  }

  //This returns a file identifier corresponding to the memory, and allows for reading and writing.  O_RDWR is just a constant
  if((fd = open(name, O_RDWR)) < 0) {
    perror("open");
    return 1;
  }
  /*mmap maps the memory location 0x40000000 to the pointer cfg, which "points" to that location in memory.*/
  cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,MEM_LOC);

  start = clock();
  for (i = 0;i<numSamples;i++) {
    data[i] = *((uint32_t *)(cfg + (i << 2)));
  }
  stop = clock();
  printf("Execution time in milliseconds: %f\n",(double)(stop - start)/CLOCKS_PER_SEC*1e3);

  FILE *ptr;

  ptr = fopen("SavedProcessedData.bin","wb");
  fwrite(data,4,(size_t)numSamples,ptr);
  fclose(ptr);

  //Unmap cfg from pointing to the previous location in memory
  munmap(cfg, MAP_SIZE);
  return 0;	//C functions should have a return value - 0 is the usual "no error" return value
}
