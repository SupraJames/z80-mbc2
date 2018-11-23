# z80-mbc2
Misc stuff for Z80-MBC2

memtest.asm / memtest.hex:

This program tests the memory of the Z80-MBC2. It loads itself into the top half of RAM at address $8000 so that we can use bank switching to test all three 'bottom' banks.

I have been testing it by simply pasting the .hex file into iLoad.

Sample output:

```
Memory test starting
[7C00] bytes starting from address [8300]
Read and write 00000000 : PASS
Read and write 11111111 : PASS
Read and write 10101010 : PASS
Read and write 01010101 : PASS
Walking bit test        : PASS

Switching to BANK 0
[7FFF] bytes starting from address [0000]
Read and write 00000000 : PASS
Read and write 11111111 : PASS
Read and write 10101010 : PASS
Read and write 01010101 : PASS
Walking bit test        : PASS

Switching to BANK 1
[7FFF] bytes starting from address [0000]
Read and write 00000000 : PASS
Read and write 11111111 : PASS
Read and write 10101010 : PASS
Read and write 01010101 : PASS
Walking bit test        : PASS

Switching to BANK 2
[7FFF] bytes starting from address [0000]
Read and write 00000000 : PASS
Read and write 11111111 : PASS
Read and write 10101010 : PASS
Read and write 01010101 : PASS
Walking bit test        : PASS

All tests PASSED - HALT
```

