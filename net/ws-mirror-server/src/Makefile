
CFLAGS += -Wall -Werror -std=gnu99 -pedantic -DDATADIR=\"/www\"
OBJ = ws-mirror-server.o
LIB = -lwebsockets -lz

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

compile: $(OBJ)
	$(CC) -o ws-mirror-server $(LDFLAGS) $(LIB) $(OBJ)

clean:
	rm -f *.o *.so ws-mirror-server

