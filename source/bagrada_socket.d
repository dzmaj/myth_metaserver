module bagrada_socket;

import vibe.d;
import vibe.utils.array;
import login_server;
import room;
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
    PLAYER_LOGIN,


    NUMBER_OF_TYPES
}

class BagradaSocket {

    private WebSocket socket;
    
    private LoginServer loginServer;

    private string m_bagrada_ws_url;
    private string m_bagrada_api_key;

    private Task m_listen_task;

    private immutable reconnect_timer = 1.minutes;
    
    public this(LoginServer loginServer) {
        this.loginServer = loginServer;
        this.m_bagrada_ws_url = loginServer.config.rank_server_ws_url;
        this.m_bagrada_api_key = loginServer.config.api_key;
    }

    //process to connect to the bagrada server if it is not already connected, should check every minute
    
    @system private void connect() nothrow {
    try {
        auto modifier = (scope HTTPClientRequest req) {
            req.method = HTTPMethod.GET;
            req.headers["bagrada-api-key"] = m_bagrada_api_key;
        };
        
        socket = connectWebSocketEx(URL(m_bagrada_ws_url), modifier);
        
        if (socket !is null && socket.connected) {
            log_message("Connected websocket to bagrada server");
            
        } else {
            log_error_message("Failed to connect to bagrada server");
        }
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
                    handleBlueBarMessage(message);
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

    @trusted nothrow private void handleBlueBarMessage(BagradaMessage message) {

        try {
            //handle blue bar message
            //send a message to all the rooms
            string senderName = "";
            if (message.sender_id > 0) {
                senderName = loginServer.data_store().get_nick_name(message.sender_id);
            } else {
                senderName = "Bagrada";
            }
            string messageString = senderName ~ " : " ~ message.data;
            log_message("Sending blue bar message to all rooms: %s", messageString);
            foreach (r; loginServer.m_room_server.rooms()) {
                try {
                    auto room = cast(Room)r;
                    room.send_blue_message(messageString);
                } catch (Exception e) {
                    log_error_message("Error sending blue bar message to room: %s", e.msg);
                }
            }
        } catch (Exception e) {
            log_error_message("Error handling blue bar message: %s", e.msg);
        }
    }

    @system private void listen(WebSocket socket) {
        try {
            while (true) {
                try {
                    if (!socket.connected) break;
                    auto messageString = socket.receiveText(false);
                    log_message("Bagrada server message: %s", messageString);
                    auto message = deserializeJson!BagradaMessage(messageString);
                    auto task = runTask({
                        handleBagradaMessage(message);
                    });
                    task.join();
                } catch (Exception e) {
                    log_error_message("Error in listen loop: %s", e.msg);
                    break;
                }
            }
        } catch (Exception e) {
            log_error_message("Error in listen method: %s", e.msg);
        }
    }

    @system public void stayConnected() {
        while (true) {
            try {
                if (socket is null || !socket.connected) {
                    connect();
                    if (socket !is null && socket.connected) {
                        listen(socket);
                    }
                } else {
                    send(BagradaMessage(BagradaMessageType.KEEP_ALIVE, "ping", 0, 0, 0));
                }
            } catch (Exception e) {
                log_error_message("Error in stayConnected: %s", e.msg);
            }
            try {
                sleep(reconnect_timer);
            } catch (Exception e) {
                log_error_message("Error in sleep: %s", e.msg);
            }
        }
    }



}

