/*
 * libwebsockets-test-client - libwebsockets test implementation
 *
 * Copyright (C) 2011 Andy Green <andy@warmcat.com>
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation:
 *  version 2.1 of the License.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *  MA  02110-1301  USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>

#include <libubox/blobmsg_json.h>
#include <libubox/uloop.h>
#include "libubus.h"
#include "libwebsockets.h"

static unsigned int opts;
static int was_closed;
static int deny_deflate;
static int deny_mux;
static struct libwebsocket *wsi_mirror;
const char *message;
struct libwebsocket_context *context;

const char *address;
int port = 7681;
int use_ssl = 0;
int ietf_version = -1; /* latest */
struct lws_context_creation_info info;


//static int mirror_lifetime = 0;
static int force_exit = 0;

char ubus_event[128] = "";
const char * ubusevent = NULL;

/*
 * This demo shows how to connect multiple websockets simultaneously to a
 * websocket server (there is no restriction on their having to be the same
 * server just it simplifies the demo).
 *
 *  dumb-increment-protocol:  we connect to the server and print the number
 *				we are given
 *
 *  lws-mirror-protocol: draws random circles, which are mirrored on to every
 *				client (see them being drawn in every browser
 *				session also using the test server)
 */

enum demo_protocols {

//	PROTOCOL_DUMB_INCREMENT,
	PROTOCOL_LWS_MIRROR,

	/* always last */
	DEMO_PROTOCOL_COUNT
};



/* lws-mirror_protocol */


static int
callback_lws_mirror(struct libwebsocket_context * this,
			struct libwebsocket *wsi,
			enum libwebsocket_callback_reasons reason,
					       void *user, void *in, size_t len)
{
	unsigned char buf[LWS_SEND_BUFFER_PRE_PADDING + 4096 +
						  LWS_SEND_BUFFER_POST_PADDING];
	int l = 0;
	int n;

	switch (reason) {

	case LWS_CALLBACK_CLOSED:
		fprintf(stderr, "mirror: LWS_CALLBACK_CLOSED\n");
		wsi_mirror = NULL;
		fprintf(stderr, "mirror: LWS_CALLBACK_CLOSED %s\n",message);
		break;

	case LWS_CALLBACK_CLIENT_ESTABLISHED:
		fprintf(stderr, "mirror: LWS_CALLBACK_CLIENT_ESTABLISHED\n");
		fprintf(stderr, "mirror: LWS_CALLBACK_CLIENT_ESTABLISHED %s\n",message);

		/*
		 * start the ball rolling,
		 * LWS_CALLBACK_CLIENT_WRITEABLE will come next service
		 */

		libwebsocket_callback_on_writable(this, wsi);
		break;

	case LWS_CALLBACK_CLIENT_RECEIVE:
		fprintf(stderr, "rx %d '%s'\n", (int)len, (char *)in);
		break;

	case LWS_CALLBACK_CLIENT_WRITEABLE:
		fprintf(stderr, "LWS_CALLBACK_CLIENT_WRITEABLE\n");
		fprintf(stderr, "LWS_CALLBACK_CLIENT_WRITEABLE %s\n",message);
//		l = sprintf((char *)&buf[LWS_SEND_BUFFER_PRE_PADDING],
//					"Random 90: %d;",
//					(int)random() % 90);
		l = sprintf((char *)&buf[LWS_SEND_BUFFER_PRE_PADDING],
//					"console: %s",
					message);

		n = libwebsocket_write(wsi,
		   &buf[LWS_SEND_BUFFER_PRE_PADDING], l, opts | LWS_WRITE_TEXT);
		/* get notified as soon as we can write again */
		if (n < 0)
			fprintf(stderr, "Write LWS_CALLBACK_CLIENT_WRITEABLE %i < 0\n",n);
			return -1;
		if (n < l) {
			fprintf(stderr, "Partial write LWS_CALLBACK_CLIENT_WRITEABLE %i < %i \n",n,l);
			return -1;
		}
		fprintf(stderr, "mirror: LWS_CALLBACK_CLIENT_WRITEABLE %s\n",message);

		//libwebsocket_callback_on_writable(this, wsi);
		fprintf(stderr, "LWS_CALLBACK_CLIENT_WRITEABLE CA %i\n",n);

		/*
		 * without at least this delay, we choke the browser
		 * and the connection stalls, despite we now take care about
		 * flow control
		 */

		//usleep(1000000);
		break;

	default:
		break;
	}

	return 0;
}

/* list of supported protocols and callbacks */

static struct libwebsocket_protocols protocols[] = {
	{
		"lws-mirror-protocol",
		callback_lws_mirror,
		0,
		128,
	},
	{ NULL, NULL, 0, 0 }
};



//#if 0
static void receive_event(struct ubus_context *ctx, struct ubus_event_handler *ev,
			  const char *type, struct blob_attr *msg)
{
	//int wlen = 0;
	int n;
	//unsigned char tbuf[LWS_SEND_BUFFER_PRE_PADDING + 4096 +
	//					  LWS_SEND_BUFFER_POST_PADDING];
	char *str;
	//char *umessage;
	str = blobmsg_format_json(msg, true);
	message = str;
	//wlen = strlen(umessage);
	fprintf(stderr, "receive_event %s\n",message);
	//memcpy(&message, umessage, wlen);
	
	//if (context == NULL) {
		fprintf(stderr, "Creating libwebsocket context failed context == NULL\n");
		context = libwebsocket_create_context(&info);
	//}
    wsi_mirror = libwebsocket_client_connect(context, address, port,
     use_ssl,  "/", address, address,
             protocols[PROTOCOL_LWS_MIRROR].name, ietf_version);
	n = 0;
	int mirror_lifetime = 2;
	while (n >= 0 && !was_closed ) {
		n = libwebsocket_service(context, 10);
		if (n < 0)
			continue;
		fprintf(stderr, "while context 2 %i\n",n);
        if (wsi_mirror == NULL) {
			fprintf(stderr, "libwebsocket "
					      "dumb connect failed\n");
			wsi_mirror = libwebsocket_client_connect(context, address, port,
			    use_ssl,  "/", address, address,
			    protocols[PROTOCOL_LWS_MIRROR].name, ietf_version);
			n = libwebsocket_service(context, 0);
		}
		mirror_lifetime--;
		if (!mirror_lifetime) n = -1;
		
	}
    fprintf(stderr, "while context 4 %i\n",n);
   	context == NULL;
	free(str);
}

void sighandler(int sig)
{
	force_exit = 1;
}

static struct option options[] = {
	{ "help",	no_argument,		NULL, 'h' },
	{ "port",	required_argument,	NULL, 'p' },
	{ "ssl",	no_argument,		NULL, 's' },
	{ "killmask",	no_argument,		NULL, 'k' },
	{ "version",	required_argument,	NULL, 'v' },
	{ "undeflated",	no_argument,		NULL, 'u' },
	{ "nomux",	no_argument,		NULL, 'n' },
	{ "ubusevent",  required_argument,		NULL, 'r' },
	{ NULL, 0, 0, 0 }
};


int main(int argc, char **argv)
{
	int n = 0;
//	int port = 7681;
//	int use_ssl = 0;
//	struct libwebsocket_context *context;
//	const char *address;
	//struct libwebsocket *wsi_dumb;
//	int ietf_version = -1; /* latest */
//	int mirror_lifetime = 0;
//	struct lws_context_creation_info info;
	memset(&info, 0, sizeof info);
    const char *ubus_socket = NULL;
	struct ubus_context *ctx;
	struct ubus_event_handler listener;
	int ret;

	if (argc < 2)
		goto usage;

	while (n >= 0) {
		n = getopt_long(argc, argv, "nuv:khsp:r:", options, NULL);
		if (n < 0)
			continue;
		switch (n) {
		case 's':
			use_ssl = 2; /* 2 = allow selfsigned */
			break;
		case 'p':
			port = atoi(optarg);
			break;
		case 'k':
			opts = LWS_WRITE_CLIENT_IGNORE_XOR_MASK;
			break;
		case 'v':
			ietf_version = atoi(optarg);
			break;
		case 'u':
			deny_deflate = 1;
			break;
		case 'n':
			deny_mux = 1;
			break;
		case 'r':
			strncpy(ubus_event, optarg, sizeof ubus_event);
			ubus_event[(sizeof ubus_event) - 1] = '\0';
			ubusevent = ubus_event;
			break;
		case 'h':
			goto usage;
		}
	}

	if (optind >= argc)
		goto usage;

	address = argv[optind];
	
	info.port = CONTEXT_PORT_NO_LISTEN;
	info.protocols = protocols;
	info.gid = -1;
	info.uid = -1;

	/*
	 * create the websockets context.  This tracks open connections and
	 * knows how to route any traffic and which protocol version to use,
	 * and if each connection is client or server side.
	 *
	 * For this client-only demo, we tell it to not listen on any port.
	 */

	ctx = ubus_connect(ubus_socket);
	if (!ctx) {
		lwsl_err("Failed to connect to ubus\n");
		return -1;
	} else {
		lwsl_err("Connect to ubus\n");
	}
	memset(&listener, 0, sizeof(listener));
	listener.cb = receive_event;

	ret = ubus_register_event_handler(ctx, &listener, ubusevent);
	if (ret) {
		fprintf(stderr, "Error while registering for event '%s': %s\n",
				ubusevent, ubus_strerror(ret));
		return -1;
	}
	uloop_init();
	ubus_add_uloop(ctx);

	//context = libwebsocket_create_context(&info);
	//if (context == NULL) {
	//	fprintf(stderr, "Creating libwebsocket context failed\n");
	//	return 1;
	//}

	uloop_run();
	uloop_done();
	fprintf(stderr, "Exiting\n");
	ubus_free(ctx);
	//libwebsocket_context_destroy(context);

	return 0;

usage:
	fprintf(stderr, "Usage: libwebsockets-test-client "
					     "-m <Message> <server address> [--port=<p>] "
					     "[--ssl] [-k] [-v <ver>]\n");
	return 1;
}
