default: all

all: clean i2c install cleanup

i2c:
	swig -tcl -prefix i2c -namespace i2c.i
	gcc -Wall -fpic -c i2c-dev.h i2c.c i2c_wrap.c -I/usr/local/include -I/usr/include/tcl8.5
	gcc -shared i2c_wrap.o -o i2c.so -lm

clean:
	rm -f i2c i2c.o i2c.so i2c_wrap.c i2c_wrap.o i2c-dev.h.gch
	rm -f ../i2c.so

cleanup:
	rm -f i2c.o i2c_wrap.c i2c_wrap.o i2c-dev.h.gch

install:
	cp i2c.so ..

exe:
	gcc -Wall i2c-dev.h i2c.c -I/usr/local/include -o i2c
	
