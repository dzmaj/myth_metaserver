module game_reporter_client;

import metaserver_config;

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
  private string completedUri;
  private string startedUri;
  private string apiKey;

  public this(const(MetaserverConfig) config) {
    client = new HTTPClient();
    completedUri = config.rank_server_base_url ~ config.game_reporter_completed_uri;
    startedUri = config.rank_server_base_url ~ config.game_reporter_started_uri;
    apiKey = config.api_key;
  }

  // Method to make a GET request to report which game was played
  public void reportGame(int gameId) {

    auto requester = delegate(scope HTTPClientRequest req) {
        req.method = HTTPMethod.POST;
        req.headers["bagrada-api-key"] = apiKey;
        req.writeJsonBody(new GameResult(gameId));
    };
    auto responder = delegate(scope HTTPClientResponse res) {
        
        if (res.statusCode == 200) {
            logInfo("Got success response for game complete");
        } else {
            logInfo("Got failure response for game complete");
        }
    };

    try {
      requestHTTP(completedUri, requester, responder); 

      return;
    } catch (Exception e) {
        logInfo(e.message);
        logInfo("Got exception while reporting game to " ~ completedUri);
    }
  }

  public void reportGameRecordingStart(const(ubyte[]) data) {

      auto requester = delegate(scope HTTPClientRequest req) {
          req.method = HTTPMethod.POST;
          req.headers["bagrada-api-key"] = apiKey;
          req.writeBody(data);
      };

      auto responder = delegate(scope HTTPClientResponse res) {

          if (res.statusCode == 200) {
              logInfo("Got success response for game start");
          } else {
              logInfo("Got failure response for game start");
          }
      };

      try {
          requestHTTP(startedUri, requester, responder);
          return;
      } catch (Exception e) {
          logInfo(e.message);
          logInfo("Got exception while reporting game start to " ~ startedUri);
      }
  }

}
