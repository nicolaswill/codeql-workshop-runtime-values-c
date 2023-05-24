void *malloc(unsigned long);/* clang compatible */

unsigned long extern_get_size(void);

void test_const(void)
{
    char *buf = malloc(100);
    buf[0];   // COMPLIANT
    buf[99];  // COMPLIANT
    buf[100]; // NON_COMPLIANT
}

void test_const_var(void)
{
    unsigned long size = 100;
    char *buf = malloc(size);
    buf[0];        // COMPLIANT
    buf[99];       // COMPLIANT
    buf[size - 1]; // COMPLIANT
    buf[100];      // NON_COMPLIANT
    buf[size];     // NON_COMPLIANT
}

void test_const_branch(int mode, int random_condition)
{
    unsigned long size = (mode == 1 ? 100 : 200);

    char *buf = malloc(size);

    if (random_condition)
    {
        size = 300;
    }

    buf[0];        // COMPLIANT
    buf[99];       // COMPLIANT
    buf[size - 1]; // NON_COMPLIANT
    buf[100];      // NON_COMPLIANT[DONT REPORT]
    buf[size];     // NON_COMPLIANT

    if (size < 199)
    {
        buf[size];     // COMPLIANT
        buf[size + 1]; // COMPLIANT
        buf[size + 2]; // NON_COMPLIANT
    }
}

void test_const_branch2(int mode)
{
    unsigned long alloc_size = 0;

    if (mode == 1)
    {
        alloc_size = 200;
    }
    else
    {
        // unknown const size - don't report accesses
        alloc_size = extern_get_size();
    }

    char *buf = malloc(alloc_size);

    buf[0];              // COMPLIANT
    buf[100];            // COMPLIANT
    buf[200];            // NON_COMPLIANT
    buf[alloc_size - 1]; // COMPLIANT
    buf[alloc_size];     // NON_COMPLIANT

    if (alloc_size < 199)
    {
        buf[alloc_size];     // COMPLIANT
        buf[alloc_size + 1]; // COMPLIANT
        buf[alloc_size + 2]; // NON_COMPLIANT
    }
}

void test_gvn_var(unsigned long x, unsigned long y, unsigned long sz)
{
    char *buf = malloc(sz * x * y);
    buf[sz * x * y - 1]; // COMPLIANT
    buf[sz * x * y];     // NON_COMPLIANT
    buf[sz * x * y + 1]; // NON_COMPLIANT
}
