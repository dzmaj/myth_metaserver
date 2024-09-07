module bagrada_socket;

import vibe.d;
import vibe.utils.array;
import login_server;
import log;
import vibe.data.json;
import vibe.core.concurrency;

struct BagradaMessage {
    BagradaMessageType type;
    string data; //the data is a json string that is specific to the type
    int room_id;
    int target_id;
    int sender_id;
}

enum BagradaMessageType {
    KEEP_ALIVE,
    BLUE_BAR,
    GAME_STARTED,
    GAME_ENDED,
    CHAT_MESSAGE,
    

    NUMBER_OF_TYPES
}

class BagradaSocket {

    private WebSocket socket;
    
    private LoginServer loginServer;

    private string m_bagrada_ws_url;
    private string m_bagrada_api_key;

    private Task m_main_task;
    private Task m_listen_task;

    private immutable reconnect_timer = 1.minutes;
    
    public this(LoginServer loginServer) {
        this.loginServer = loginServer;
        this.m_bagrada_ws_url = loginServer.config.rank_server_ws_url;
        this.m_bagrada_api_key = loginServer.config.api_key;
        this.m_main_task = Task.getThis();
        runTask(&stayConnected);
    }

    //process to connect to the bagrada server if it is not already connected, should check every minute
    
    @safe nothrow private void connect() {
        //connect to the bagrada server
        try {
            auto modifier = delegate(scope HTTPClientRequest req) {
                req.method = HTTPMethod.GET;
                req.headers["bagrada-api-key"] = m_bagrada_api_key;
            };
            socket = connectWebSocketEx(URL(m_bagrada_ws_url), modifier);
            m_listen_task = runTask({
                listen(socket);
            });
        }
        catch (Exception e) {
            log_error_message("Error connecting to bagrada server: %s", e.msg);
        }
    }

    @safe nothrow public void send(BagradaMessage message) {

        try {
            //serialize the message to a json string
            string messageString = serializeToJsonString(message);
            log_debug_message("Sending message to bagrada server: %s", messageString);
            socket.send(messageString);
        }
        catch (Exception e) {
            log_error_message("Error sending message to bagrada server: %s", e.msg);
        }
    }

    @safe nothrow public void handleBagradaMessage(BagradaMessage message) {
        try {
            switch (message.type) {
                case BagradaMessageType.BLUE_BAR:
                    //handle blue bar
                    break;
                case BagradaMessageType.GAME_STARTED:
                    //handle game started
                    break;
                case BagradaMessageType.GAME_ENDED:
                    //handle game ended
                    break;
                case BagradaMessageType.CHAT_MESSAGE:
                    //handle chat message
                    break;
                default:
                    log_error_message("Unknown message type: %s", message.type);
                    break;
            }
        } catch (Exception e) {
            log_error_message("Error handling message: %s", e.msg);
        }
    }

    @safe nothrow private void listen(WebSocket socket) {

        try {
            while (socket.waitForData()) {
                auto messageString = socket.receiveText();
                log_debug_message("Bagrada server message: %s", messageString);
                auto message = deserializeJson!BagradaMessage(messageString);
                runTask({
                    handleBagradaMessage(message);
                });
            }

            scope(exit) {
                socket.close();
            }

        }
        catch (Exception e) {
            log_error_message("Error listening to bagrada server: %s", e.msg);
        }

    }

    @safe public void stayConnected() nothrow 
    {
        
        try {
            scope(exit) log_message("Login: ERROR, bagrada socket task exited!");

            for (;;)
            {
                if (socket is null || !socket.connected) {
                    connect();
                } else {
                    send(BagradaMessage(BagradaMessageType.KEEP_ALIVE, "ping", 0, 0, 0));
                }
                sleep(reconnect_timer);
                

                //log_message("Login: Finished cleanup (%s clients total)...", m_clients.length);
            }
        } catch (Exception e) {
            try {
                log_message("Error: ", e.msg);
            } catch (Exception e) {
                //logging exception, not sure what else to do here, but it has to be caught for this to be nothrow
            }
        }
        
    }



}

