
CFLAGS += -Wall -std=gnu99 -pedantic -DDATADIR=\"/www\"
OBJ = ws-mirror-server.o
OBJ_CMD = ws-mirror-server-cmd.o
LIB = -lwebsockets -lz -lubus -lubox -lblobmsg_json -ljson

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

compile: $(OBJ) $(OBJ_CMD)
	$(CC) -o ws-mirror-server $(LDFLAGS) $(LIB) $(OBJ)
	$(CC) -o ws-mirror-server-cmd $(LDFLAGS) $(LIB) $(OBJ_CMD)


clean:
	rm -f *.o *.so ws-mirror-server ws-mirror-server-cmd

