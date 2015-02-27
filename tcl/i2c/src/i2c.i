%module i2c
%{
/* Includes the header in the wrapper code */
#include "i2c.c"
%}

/* Parse the header file to generate wrappers */
%include "i2c.c"
