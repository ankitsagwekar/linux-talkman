/* regpoke: read/write 32-bit MMIO registers through /dev/mem (bring-up aid)
 *   regpoke r ADDR          -> prints value
 *   regpoke w ADDR VALUE    -> writes, prints readback
 *   regpoke s ADDR MASK     -> set bits,   prints old -> new
 *   regpoke c ADDR MASK     -> clear bits, prints old -> new
 */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	if (argc < 3) {
		fprintf(stderr, "usage: regpoke r|w|s|c ADDR [VALUE]\n");
		return 2;
	}
	char op = argv[1][0];
	uint64_t addr = strtoull(argv[2], NULL, 0);
	uint32_t arg = argc > 3 ? (uint32_t)strtoull(argv[3], NULL, 0) : 0;
	long ps = sysconf(_SC_PAGESIZE);
	uint64_t base = addr & ~((uint64_t)ps - 1);

	if (op != 'r' && argc < 4) {
		fprintf(stderr, "missing VALUE\n");
		return 2;
	}
	int fd = open("/dev/mem", (op == 'r' ? O_RDONLY : O_RDWR) | O_SYNC);
	if (fd < 0) { perror("open /dev/mem"); return 1; }
	void *m = mmap(NULL, ps, op == 'r' ? PROT_READ : PROT_READ | PROT_WRITE,
		       MAP_SHARED, fd, (off_t)base);
	if (m == MAP_FAILED) { perror("mmap"); return 1; }
	volatile uint32_t *reg = (volatile uint32_t *)((char *)m + (addr - base));
	uint32_t old = *reg, val;

	switch (op) {
	case 'r': printf("0x%08x\n", old); return 0;
	case 'w': val = arg; break;
	case 's': val = old | arg; break;
	case 'c': val = old & ~arg; break;
	default: fprintf(stderr, "bad op\n"); return 2;
	}
	*reg = val;
	printf("0x%08x -> 0x%08x\n", old, *reg);
	return 0;
}
