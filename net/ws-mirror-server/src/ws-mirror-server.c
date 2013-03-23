/*
 * libwebsockets-test-server - libwebsockets test implementation
 *
 * Copyright (C) 2010-2011 Andy Green <andy@warmcat.com>
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
#include <sys/time.h>

#include <libubox/blobmsg_json.h>
#include <libubox/uloop.h>
#include "libubus.h"
#include "libwebsockets.h"

int force_exit = 0;

static int close_testing;
char ubus_event[128] = "";
const char * ubusevent = NULL;
char ubus_xevent[128] = "";
const char * ubusxevent = NULL;

/*
 * This demo server shows how to use libwebsockets for one or more
 * websocket protocols in the same server
 *
 * It defines the following websocket protocols:
 *
 *  dumb-increment-protocol:  once the socket is opened, an incrementing
 *				ascii string is sent down it every 50ms.
 *				If you send "reset\n" on the websocket, then
 *				the incrementing number is reset to 0.
 *
 *  lws-mirror-protocol: copies any received packet to every connection also
 *				using this protocol, including the sender
 */

enum demo_protocols {
	/* always first */
	PROTOCOL_HTTP = 0,

	//PROTOCOL_DUMB_INCREMENT,
	PROTOCOL_LWS_MIRROR,

	/* always last */
	DEMO_PROTOCOL_COUNT
};


#define LOCAL_RESOURCE_PATH DATADIR
#define LOCAL_CONFIG_PATH CONFIGDIR

/*
 * We take a strict whitelist approach to stop ../ attacks
 */

struct serveable {
	const char *urlpath;
	const char *mimetype;
}; 

static const struct serveable whitelist[] = {
	{ "/favicon.ico", "image/x-icon" },
	{ "/libwebsockets.org-logo.png", "image/png" },

	/* last one is the default served if no match */
	{ "/ws-server.html", "text/html" },
};

struct per_session_data__http {
	int fd;
};

/* this protocol server (always the first one) just knows how to do HTTP */

static int callback_http(struct libwebsocket_context * context,
		struct libwebsocket *wsi,
		enum libwebsocket_callback_reasons reason, void *user,
							   void *in, size_t len)
{
#if 0
	char client_name[128];
	char client_ip[128];
#endif
    char buf[256];
	int n;
#ifdef EXTERNAL_POLL
	int fd = (int)(long)in;
#endif

	switch (reason) {
	case LWS_CALLBACK_HTTP:
		fprintf(stderr, "serving HTTP URI %s\n", (char *)in);

		for (n = 0; n < (sizeof(whitelist) / sizeof(whitelist[0]) - 1); n++)
			if (in && strcmp((const char *)in, whitelist[n].urlpath) == 0)
				break;

		sprintf(buf, LOCAL_RESOURCE_PATH"%s", whitelist[n].urlpath);

		if (libwebsockets_serve_http_file(context, wsi, buf, whitelist[n].mimetype))
			return -1; /* through completion or error, close the socket */

		/*
		 * notice that the sending of the file completes asynchronously,
		 * we'll get a LWS_CALLBACK_HTTP_FILE_COMPLETION callback when
		 * it's done
		 */

		break;
	/*
	 * callback for confirming to continue with client IP appear in
	 * protocol 0 callback since no websocket protocol has been agreed
	 * yet.  You can just ignore this if you won't filter on client IP
	 * since the default uhandled callback return is 0 meaning let the
	 * connection continue.
	 */

	case LWS_CALLBACK_FILTER_NETWORK_CONNECTION:
#if 0
		libwebsockets_get_peer_addresses((int)(long)user, client_name,
			     sizeof(client_name), client_ip, sizeof(client_ip));

		fprintf(stderr, "Received network connect from %s (%s)\n",
							client_name, client_ip);
#endif
		/* if we returned non-zero from here, we kill the connection */
		break;

	default:
		break;
	}

	return 0;
}


/*
 * this is just an example of parsing handshake headers, you don't need this
 * in your code unless you will filter allowing connections by the header
 * content
 */

static void
dump_handshake_info(struct libwebsocket *wsi)
{
	int n;
	static const char *token_names[WSI_TOKEN_COUNT] = {
		/*[WSI_TOKEN_GET_URI]		=*/ "GET URI",
		/*[WSI_TOKEN_HOST]		=*/ "Host",
		/*[WSI_TOKEN_CONNECTION]	=*/ "Connection",
		/*[WSI_TOKEN_KEY1]		=*/ "key 1",
		/*[WSI_TOKEN_KEY2]		=*/ "key 2",
		/*[WSI_TOKEN_PROTOCOL]		=*/ "Protocol",
		/*[WSI_TOKEN_UPGRADE]		=*/ "Upgrade",
		/*[WSI_TOKEN_ORIGIN]		=*/ "Origin",
		/*[WSI_TOKEN_DRAFT]		=*/ "Draft",
		/*[WSI_TOKEN_CHALLENGE]		=*/ "Challenge",

		/* new for 04 */
		/*[WSI_TOKEN_KEY]		=*/ "Key",
		/*[WSI_TOKEN_VERSION]		=*/ "Version",
		/*[WSI_TOKEN_SWORIGIN]		=*/ "Sworigin",

		/* new for 05 */
		/*[WSI_TOKEN_EXTENSIONS]	=*/ "Extensions",

		/* client receives these */
		/*[WSI_TOKEN_ACCEPT]		=*/ "Accept",
		/*[WSI_TOKEN_NONCE]		=*/ "Nonce",
		/*[WSI_TOKEN_HTTP]		=*/ "Http",
		/*[WSI_TOKEN_MUXURL]	=*/ "MuxURL",
	};
	char buf[256];

	for (n = 0; n < WSI_TOKEN_COUNT; n++) {
		if (!lws_hdr_total_length(wsi, n))
			continue;

		lws_hdr_copy(wsi, buf, sizeof buf, n);

		fprintf(stderr, "    %s = %s\n", token_names[n], buf);
	}
}


/* lws-mirror_protocol */

#define MAX_MESSAGE_QUEUE 64

struct per_session_data__lws_mirror {
	struct libwebsocket *wsi;
	int ringbuffer_tail;
};

struct a_message {
	void *payload;
	size_t len;
};

static struct a_message ringbuffer[MAX_MESSAGE_QUEUE];
static int ringbuffer_head;

static int
callback_lws_mirror(struct libwebsocket_context * context,
			struct libwebsocket *wsi,
			enum libwebsocket_callback_reasons reason,
					       void *user, void *in, size_t len)
{
	int n;
	//struct per_session_data__lws_mirror *pss = user;
	
	unsigned char buf[LWS_SEND_BUFFER_PRE_PADDING + 512 +
						  LWS_SEND_BUFFER_POST_PADDING];
	//unsigned char *p = &buf[LWS_SEND_BUFFER_PRE_PADDING];
	struct per_session_data__lws_mirror *pss = (struct per_session_data__lws_mirror *)user;

	switch (reason) {

	case LWS_CALLBACK_ESTABLISHED:
	    lwsl_info("callback_lws_mirror: LWS_CALLBACK_ESTABLISHED\n");
		pss->ringbuffer_tail = ringbuffer_head;
		pss->wsi = wsi;
		//libwebsocket_callback_on_writable(context, wsi);
		break;

	case LWS_CALLBACK_PROTOCOL_DESTROY:
	    lwsl_notice("mirror protocol cleaning up\n");
        for (n = 0; n < sizeof ringbuffer / sizeof ringbuffer[0]; n++)
			if (ringbuffer[n].payload)
				free(ringbuffer[n].payload);
		break;

	case LWS_CALLBACK_SERVER_WRITEABLE:
		if (close_testing)
			break;
		while (pss->ringbuffer_tail != ringbuffer_head) {

			n = libwebsocket_write(wsi, (unsigned char *)
				   ringbuffer[pss->ringbuffer_tail].payload +
				   LWS_SEND_BUFFER_PRE_PADDING,
				   ringbuffer[pss->ringbuffer_tail].len,
								LWS_WRITE_TEXT);
			if (n < 0) {
				lwsl_err("ERROR %d writing to mirror socket\n", n);
				return -1;
			}
			if (n < ringbuffer[pss->ringbuffer_tail].len)
				lwsl_err("mirror partial write %d vs %d\n",
				       n, ringbuffer[pss->ringbuffer_tail].len);

			if (pss->ringbuffer_tail == (MAX_MESSAGE_QUEUE - 1))
				pss->ringbuffer_tail = 0;
			else
				pss->ringbuffer_tail++;

			if (((ringbuffer_head - pss->ringbuffer_tail) &
				  (MAX_MESSAGE_QUEUE - 1)) == (MAX_MESSAGE_QUEUE - 15))
				libwebsocket_rx_flow_allow_all_protocol(
					       libwebsockets_get_protocol(wsi));

			// lwsl_debug("tx fifo %d\n", (ringbuffer_head - pss->ringbuffer_tail) & (MAX_MESSAGE_QUEUE - 1));

			if (lws_send_pipe_choked(wsi)) {
				libwebsocket_callback_on_writable(context, wsi);
				break;
			}
			/*
			 * for tests with chrome on same machine as client and
			 * server, this is needed to stop chrome choking
			 */
			usleep(1);
		}
		break;

	case LWS_CALLBACK_RECEIVE:

		if (((ringbuffer_head - pss->ringbuffer_tail) &
				  (MAX_MESSAGE_QUEUE - 1)) == (MAX_MESSAGE_QUEUE - 1)) {
			lwsl_err("dropping!\n");
			goto choke;
		}

		if (ringbuffer[ringbuffer_head].payload)
			free(ringbuffer[ringbuffer_head].payload);

		ringbuffer[ringbuffer_head].payload =
				malloc(LWS_SEND_BUFFER_PRE_PADDING + len +
						  LWS_SEND_BUFFER_POST_PADDING);
		ringbuffer[ringbuffer_head].len = len;
		memcpy((char *)ringbuffer[ringbuffer_head].payload +
					  LWS_SEND_BUFFER_PRE_PADDING, in, len);
		if (ringbuffer_head == (MAX_MESSAGE_QUEUE - 1))
			ringbuffer_head = 0;
		else
			ringbuffer_head++;

		if (((ringbuffer_head - pss->ringbuffer_tail) &
				  (MAX_MESSAGE_QUEUE - 1)) != (MAX_MESSAGE_QUEUE - 2))
			goto done;

choke:
		lwsl_debug("LWS_CALLBACK_RECEIVE: throttling %p\n", wsi);
		libwebsocket_rx_flow_control(wsi, 0);

//		lwsl_debug("rx fifo %d\n", (ringbuffer_head - pss->ringbuffer_tail) & (MAX_MESSAGE_QUEUE - 1));
done:
		libwebsocket_callback_on_writable_all_protocol(
					       libwebsockets_get_protocol(wsi));

		const char *ubus_socket = NULL;
		struct ubus_context *ctx;
		static struct blob_buf b;
		ctx = ubus_connect(ubus_socket);
		if (!ctx) {
			fprintf(stderr, "Failed to connect to ubus\n");
			return -1;
		}		
		blob_buf_init(&b, 0);
		blobmsg_add_json_from_string(&b, (char *)in);
		ubus_send_event(ctx, ubusxevent, b.head);
		ubus_free(ctx);

		break;
	/*
	 * this just demonstrates how to use the protocol filter. If you won't
	 * study and reject connections based on header content, you don't need
	 * to handle this callback
	 */

	case LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION:
		dump_handshake_info(wsi);
		/* you could return non-zero here and kill the connection */
		break;

	default:
		break;
	}

	return 0;
}


/* list of supported protocols and callbacks */

static struct libwebsocket_protocols protocols[] = {
	/* first protocol must always be HTTP handler */

	{
		"http-only",		/* name */
		callback_http,		/* callback */
		0			/* per_session_data_size */
	},
	{
		"lws-mirror-protocol",
		callback_lws_mirror,
		sizeof(struct per_session_data__lws_mirror),
		128,
	},
	{
		NULL, NULL, 0		/* terminator */
	}
};

static void receive_event(struct ubus_context *ctx, struct ubus_event_handler *ev,
			  const char *type, struct blob_attr *msg)
{
	int wlen = 0;
	unsigned char tbuf[LWS_SEND_BUFFER_PRE_PADDING + 4096 +
						  LWS_SEND_BUFFER_POST_PADDING];
	char *str;
	char *message;
	str = blobmsg_format_json(msg, true);
	message = str;
	wlen = strlen(message);
	memcpy(&tbuf[LWS_SEND_BUFFER_PRE_PADDING], message, wlen);
	
//	libwebsockets_broadcast_foreign(&protocols[PROTOCOL_LWS_MIRROR],
//					&tbuf[LWS_SEND_BUFFER_PRE_PADDING], wlen);
	libwebsocket_callback_on_writable_all_protocol(&protocols[PROTOCOL_LWS_MIRROR]);

	free(str);
}



static int ubus_cli_listen(struct ubus_context *ctx, struct libwebsocket_context *context,char *event)
{
	static struct ubus_event_handler listener;
	int ret;

	memset(&listener, 0, sizeof(listener));
	listener.cb = receive_event;

	ret = ubus_register_event_handler(ctx, &listener, event);
	if (ret) {
		fprintf(stderr, "Error while registering for event '%s': %s\n",
				event, ubus_strerror(ret));
		return -1;
	}
	uloop_init();
	ubus_add_uloop(ctx);
	uloop_run();
	uloop_done();
	return 0;
}

void sighandler(int sig)
{
	force_exit = 1;
}

static struct option options[] = {
	{ "help",	no_argument,		NULL, 'h' },
	{ "port",	required_argument,	NULL, 'p' },
	{ "ssl",	no_argument,		NULL, 's' },
	{ "interface",  required_argument, 	NULL, 'i' },
	{ "closetest",  no_argument,		NULL, 'c' },
	{ "ubusevent",  required_argument,		NULL, 'r' },
	{ "ubusxevent",  required_argument,		NULL, 'x' },
	{ NULL, 0, 0, 0 }
};

int main(int argc, char **argv)
{
	int n = 0;
	int use_ssl = 0;
	unsigned int oldus = 0;
	struct libwebsocket_context *context;
	int opts = 0;
	char interface_name[128] = "";
	const char *iface = NULL;
	struct lws_context_creation_info info;
	int debug_level = 7;
	
	memset(&info, 0, sizeof info);
	info.port = 7681;

	unsigned char buf[LWS_SEND_BUFFER_PRE_PADDING + 4096 +
	    LWS_SEND_BUFFER_POST_PADDING];
    const char *ubus_socket = NULL;
	struct ubus_context *ctx;
	
	while (n >= 0) {
		n = getopt_long(argc, argv, "r:x:i:u:khsp:", options, NULL);
		if (n < 0)
			continue;
		switch (n) {
		case 'd':
			debug_level = atoi(optarg);
			break;
		case 's':
			use_ssl = 1;
			break;
		case 'p':
			info.port = atoi(optarg);
			break;
		case 'i':
			strncpy(interface_name, optarg, sizeof interface_name);
			interface_name[(sizeof interface_name) - 1] = '\0';
			iface = interface_name;
			break;
		case 'c':
			close_testing = 1;
			fprintf(stderr, " Close testing mode -- closes on "
					   "client after 50 dumb increments"
					   "and suppresses lws_mirror spam\n");
			break;
		case 'r':
			strncpy(ubus_event, optarg, sizeof ubus_event);
			ubus_event[(sizeof ubus_event) - 1] = '\0';
			ubusevent = ubus_event;
			break;
		case 'x':
			strncpy(ubus_xevent, optarg, sizeof ubus_xevent);
			ubus_xevent[(sizeof ubus_xevent) - 1] = '\0';
			ubusxevent = ubus_xevent;
			break;
		case 'h':
			fprintf(stderr, "Usage: ws-mirror-server "
					     "-r <r> -x <x> -[--port=<p>] [--ssl]\n"
					     "-r <r> ubus receive path to forward ws e.g. \"*\" or \"chat\"\n"
					     "-x <x> ubus send path from ws e.g. \"linknxws\" or \"ws\"\n");
			exit(1);
		}
	}
	
	signal(SIGINT, sighandler);
	//lws_set_log_level(debug_level, lwsl_emit_syslog);
	info.iface = iface;
	info.protocols = protocols;

	if (!use_ssl) {
		info.ssl_cert_filepath = NULL;
		info.ssl_private_key_filepath = NULL;
	} else {
		info.ssl_cert_filepath = LOCAL_CONFIG_PATH"/ws-server.pem";
		info.ssl_private_key_filepath = LOCAL_CONFIG_PATH"/ws-server.key.pem";
	}	
	info.gid = -1;
	info.uid = -1;
	info.options = opts;

	ctx = ubus_connect(ubus_socket);
	if (!ctx) {
		lwsl_err("Failed to connect to ubus\n");
		return -1;
	} else {
		lwsl_err("Connect to ubus\n");
	}

	context = libwebsocket_create_context(&info);
	if (context == NULL) {
		lwsl_err("libwebsocket init failed\n");
		return -1;
	}

	buf[LWS_SEND_BUFFER_PRE_PADDING] = 'x';
	n = 0;
	while (n >= 0 && !force_exit) {
		struct timeval tv;
		gettimeofday(&tv, NULL);
		//if (((unsigned int)tv.tv_usec - oldus) > 50000) {
		//	libwebsocket_callback_on_writable_all_protocol(&protocols[PROTOCOL_LWS_MIRROR]);
		//	oldus = tv.tv_usec;
		//}
		n = libwebsocket_service(context, 50);
		if (n < 0) {
		    lwsl_err("Unable to fork service loop %d\n", n);
		    return -1;
//		} else {
//		    lwsl_err("fork service loop %d\n", n);
		}
	}
//	libwebsockets_broadcast(&protocols[PROTOCOL_LWS_MIRROR],
//				&buf[LWS_SEND_BUFFER_PRE_PADDING], 1);
//	libwebsocket_callback_on_writable_all_protocol(&protocols[PROTOCOL_LWS_MIRROR]);
//	libwebsocket_callback_on_writable(context, wsi);
//	libwebsocket_callback_on_writable(context, &protocols[PROTOCOL_LWS_MIRROR]);

	//int ret = -1;
	//ret = ubus_cli_listen(ctx,context,ubusevent);
	//if (ret > 0)
	//	lwsl_err("Command failed: %s\n", ubus_strerror(ret));

	//ubus_free(ctx);
	libwebsocket_context_destroy(context);

	return 0;
}
