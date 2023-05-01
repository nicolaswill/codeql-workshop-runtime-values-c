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