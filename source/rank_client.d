module rank_client;

import vibe.http.client;
import core.time;
import vibe.core.log;
import std.format;
import vibe.data.json;

struct RankCacheEntry {
  int[] ranks;
  MonoTime expiryTime;
}

struct RankResponseBody {
    int[] ranks;
}

class RankClient {
  private HTTPClient client;
  private Duration cacheTimeout;
  private RankCacheEntry[int] cache;
  private RankCacheEntry blank;

  public this() {
    client = new HTTPClient();
    cacheTimeout = dur!"minutes"(1);
    blank.ranks = [-1,-1,-1];
    blank.expiryTime = MonoTime.currTime();
    cache[-1] = blank;
  }

  // Method to make a GET request to the rank API endpoint
  int[] getUserRank(int userId) {
    // Check cache for existing rank
    auto p = userId in cache;
    if (p !is null) {
        auto cachedRank = cache[userId];
        if (cachedRank.ranks != null) {
        auto rank = cachedRank.ranks;
        auto expiry_time = cachedRank.expiryTime;
        if (expiry_time > MonoTime.currTime()) {
            // Cache entry is valid, return cached rank
            return rank;
        } else {
            // Cache entry expired, remove it
            cache.remove(userId);
        }
        }
    }
    

    // Rank not found in cache, make the HTTP request
    auto url = format("http://localhost:8080/rest/rank/%d", userId);
    int[] requestRank;

    auto requester = delegate(scope HTTPClientRequest req) {
        req.method = HTTPMethod.GET;
    };
    auto responder = delegate(scope HTTPClientResponse res) {
        logInfo("Got Response");
        if (res.statusCode == 200) {
            auto json = res.readJson();
            // Parse the response body to extract the rank array (implementation depends on API format)
            auto ranks = deserializeJson!RankResponseBody(json).ranks;

            // Update cache with new rank and expiry time
            RankCacheEntry entry;
            entry.ranks = ranks;
            requestRank = ranks;
            entry.expiryTime = MonoTime.currTime() + cacheTimeout;
            cache[userId] = entry;
        } else {
            
        }
    };

    try {
      requestHTTP(url, requester, responder); 

      return requestRank;
    } catch (Exception e) {
      
    }
    return blank.ranks;
  }

  // Function to parse the rank array from the response body (replace with your actual parsing logic)
  private pure int[] parseIntArrayFromBody(string bodyString) {
    // Replace this with code to parse the integer array from the response body based on your API format
    return [-1, 1, -1]; // Example array
  }
}
