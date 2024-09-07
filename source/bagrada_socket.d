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
    BLUE_BAR,
    GAME_STARTED,
    GAME_ENDED,
    CHAT_MESSAGE,

    NUMBER_OF_TYPES
}

class BagradaClient {

    private WebSocket[] sockets;
    
    private LoginServer loginServer;

    private string m_bagrada_ws_url;

    private Task m_main_task;
    private Task m_listen_task;
    
    public this(LoginServer loginServer) {
        this.loginServer = loginServer;
        this.sockets = [];
        this.m_bagrada_ws_url = loginServer.config.rank_server_ws_url;
        this.m_main_task = Task.getThis();
    }

    //process to connect to the bagrada server if it is not already connected, should check every minute
    
    public void connect() {
        //connect to the bagrada server
        try {
            auto ws = connectWebSocket(URL(m_bagrada_ws_url));
            sockets ~= ws;
            m_listen_task = runTask({
                listen(ws);
            });
        }
        catch (Exception e) {
            log_error_message("Error connecting to bagrada server: %s", e.msg);
        }
    }

    public void send(BagradaMessage message) {
        foreach (ws; sockets) {
            //serialize the message to a json string
            string messageString = serializeToJsonString(message);
            log_debug_message("Sending message to bagrada server: %s", messageString);
            ws.send(messageString);
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



}

