module bagrada_socket;

import vibe.d;
import vibe.utils.array;
import login_server;

class BagradaClient {

    private WebSocket[] sockets;
    
    private LoginServer loginServer;
    
    public this(LoginServer loginServer) {
        this.loginServer = loginServer;
    }
}

