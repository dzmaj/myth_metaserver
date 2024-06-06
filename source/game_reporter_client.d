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

  // Method to make a GET request to report which game was played
  public void reportGame(int gameId) {

    auto url = "http://localhost:8080/rank-server/report/games";

    auto requester = delegate(scope HTTPClientRequest req) {
        req.method = HTTPMethod.POST;
        req.writeJsonBody(new GameResult(gameId));
        req.headers["bagrada-api-key"] = "test";
    };
    auto responder = delegate(scope HTTPClientResponse res) {
        
        if (res.statusCode == 200) {
            logInfo("Got success response for game report");
        } else {
            logInfo("Got failure response for game report");
        }
    };

    try {
      requestHTTP(url, requester, responder); 

      return;
    } catch (Exception e) {
        logInfo(e.message);
        logInfo("Got exception while reporting game to " ~ url);
    }
  }

}
