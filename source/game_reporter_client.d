module game_reporter_client;

import vibe.http.client;
import core.time;
import vibe.core.log;
import std.format;
import vibe.data.json;

struct GameResult {
  int id;
  this(int id) {
    this.id = id;
  }
}

class GameReporterClient {
  private HTTPClient client;

  public this() {
    client = new HTTPClient();
  }

  // Method to make a GET request to the rank API endpoint
  public void reportGame(int gameId) {
    // Check cache for existing rank 

    // Rank not found in cache, make the HTTP request
    auto url = "http://localhost:8080/rank-server/rest/games";

    auto requester = delegate(scope HTTPClientRequest req) {
        req.method = HTTPMethod.POST;
        req.writeJsonBody(new GameResult(gameId));
    };
    auto responder = delegate(scope HTTPClientResponse res) {
        logInfo("Got Response");
        if (res.statusCode == 200) {
        } else {
            
        }
    };

    try {
      requestHTTP(url, requester, responder); 

      return;
    } catch (Exception e) {
      
    }
  }

}
