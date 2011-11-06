
#CFLAGS += -Wall --std=gnu99
CFLAGS := -Wall -Werror -std=gnu99 -pedantic -DDATADIR=\"/www\" -I/usr/local/include
OBJ = ws-mirror-server.o
LIB = -lwebsockets
LDFLAGS+= -L/usr/local/lib

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

compile: $(OBJ)
	$(CC) -o ws-mirror-server $(LDFLAGS) $(LIB) $(OBJ)

clean:
	rm -f *.o *.so ws-mirror-server

