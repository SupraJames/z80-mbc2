# z80-mbc2
Misc stuff for Z80-MBC2

memtest.asm / memtest.hex:

This program tests the memory of the Z80-MBC2. It loads itself into the top half of RAM at address $8000 so that we can use bank switching to test all three 'bottom' banks.

Because the memory is overwritten during the test, we avoid the first 0x300 bytes of the top half of RAM, and the last 0xFF bytes to avoid killing the stack.

If we encounter an error, the program will HALT and tell you which address and bit pattern caused the issue.

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

Credits:

Memory test method lifted from http://www.ballyalley.com/ml/ml_source/RAM%20Test%20[From%20Z80%20Assembly%20Language%20Subroutines].pdf

monitor.asm / monitor.hex

This is a simple Z80 Monitor program. I've taken it from https://github.com/fiskabollen/z80Monitor and adapted it for Z80-MBC2 I/O and added a command to switch banks.
