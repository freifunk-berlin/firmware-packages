NEIGHTBL_CFLAGS      = $(CFLAGS) -std=gnu99 -fstrict-aliasing -Iinclude
NEIGHTBL_LIB         = neightbl.so
NEIGHTBL_LIB_LDFLAGS = $(LDFLAGS) -shared -L.-llua
NEIGHTBL_LIB_OBJ     = neightbl.o

%.o: %.c
	$(CC) $(NEIGHTBL_CFLAGS) $(FPIC) -c -o $@ $<

compile: clean $(NEIGHTBL_LIB_OBJ)
	$(CC) $(NEIGHTBL_LIB_LDFLAGS) -o $(NEIGHTBL_LIB) $(NEIGHTBL_LIB_OBJ)

clean:
	rm -f *.o $(IWINFO_LIB) $(IWINFO_LUA) $(IWINFO_CLI)
