
CFLAGS += -Wall -Werror -std=gnu99 -pedantic -DDATADIR=\"/www\"
OBJ = ws-mirror-server.o
OBJ_CMD = ws-mirror-server-cmd.o
OBJ_UBUS = ws-ubus-server.o
LIB = -lwebsockets -lz -lubus

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

compile: $(OBJ) $(OBJ_CMD) $(OBJ_UBUS)
	$(CC) -o ws-mirror-server $(LDFLAGS) $(LIB) $(OBJ)
	$(CC) -o ws-mirror-server-cmd $(LDFLAGS) $(LIB) $(OBJ_CMD)
	$(CC) -o ws-ubus-server $(LDFLAGS) $(LIB) $(OBJ_UBUS)

clean:
	rm -f *.o *.so ws-mirror-server ws-mirror-server-cmd ws-ubus-server

