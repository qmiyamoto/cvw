#include <stdio.h>
 
int main(void) {
    int a = 3;
    int b = 4;
    int c;

    // write inline assembly here to compute c = a + 2*b
    
    // asm volatile("slli %0, %1, 1" : "=r" (c) : "r" (b));             // c = b << 1
    // asm volatile("add %0, %1, %2" : "=r" (c) : "r" (a), "r" (c));    // c = a + c

    asm volatile("add %0, %1, %2;" : "=r"(c) : "r"(b), "r"(b));         // b = b + b (= 2b)
    asm volatile("add %0, %1, %2;" : "=r"(c) : "r"(a), "r"(c));         // c = a + c
    
    printf ("c = %d\n", c);
}