module rank_client;

import log;

import vibe.http.client;
import core.time;
import vibe.core.log;
import std.format;
import vibe.data.json;
import metaserver_config;

struct RankCacheEntry {
    int[] ranks;
    MonoTime expiryTime;
    ScoreInfo[string] scoreInfo;
    int rankCount;
}

struct ScoreInfo {
    int points;
    int wins;
    int damageGiven;
    int damageTaken;
    int rank;
    int games;
    int topDamageGiven;
    int topDamageTaken;
    int topWins;
    int topPoints;
    string topRanked;
}

struct RankRespDto {
    int[] ranks;
    ScoreInfo[string] scoreInfo;
    int rankCount;
}

class RankClient {
    private HTTPClient client;
    private Duration cacheTimeout;
    private RankCacheEntry[int] cache;
    private RankCacheEntry blank;
    private int rankedPlayerCount;
    private string baseUrl;
    private string apiUser;
    private string apiKey;
    private string rankClientUri;

    public this(const(MetaserverConfig) config) {
        client = new HTTPClient();
        baseUrl = config.rank_server_base_url;
        apiUser = config.api_user;
        apiKey = config.api_key;
        cacheTimeout = dur!"minutes"(1);
        blank = RankCacheEntry([-1, -1, -1], MonoTime.currTime(), new ScoreInfo[string], 0);
        blank.scoreInfo["0"] = ScoreInfo(0,0,0,0,0,0,0,0,0,0,"");
        cache[-1] = blank;
        rankedPlayerCount = 0;
        rankClientUri = config.rank_client_uri;

    }

    @property public pure nothrow int getRankedPlayerCount() {return rankedPlayerCount;}

    // Method to make a GET request to the rank API endpoint
    int[] getUserRank(int userId) @trusted {
        // Check cache for existing rank
        auto p = userId in cache;
        if (p !is null) {
            auto cachedRank = cache[userId];
            if (cachedRank.ranks !is null) {
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
        auto url = format(baseUrl ~ rankClientUri ~ "/%d", userId);
        int[] requestRank;

        auto requester = delegate(scope HTTPClientRequest req) {
            req.method = HTTPMethod.GET;
            req.headers["bagrada-api-key"] = apiKey;
        };
        auto responder = delegate(scope HTTPClientResponse res) {
            if (res.statusCode == 200) {
                auto json = res.readJson();
                // Parse the response body to extract the rank array
                auto playerData = deserializeJson!RankRespDto(json);
                auto ranks = playerData.ranks;
                auto scoreInfo = playerData.scoreInfo;

                // Update cache with new rank and expiry time
                RankCacheEntry entry;
                entry.ranks = ranks;
                entry.scoreInfo = scoreInfo;
                entry.rankCount = playerData.rankCount;
                requestRank = ranks;
                entry.expiryTime = MonoTime.currTime() + cacheTimeout;
                cache[userId] = entry;
            } else {
                RankCacheEntry entry;
                entry.ranks = blank.ranks;
                entry.expiryTime = MonoTime.currTime() + cacheTimeout;
                cache[userId] = entry;
                requestRank = blank.ranks;
            }
        };

        try {
            requestHTTP(url, requester, responder);
            return requestRank;
        } catch (Exception e) {
            log_error_message("Exception getting rank: %s".format(e.msg));
        }
        return blank.ranks;
    }

    int getRankCount(int userId) @trusted {
        auto p = userId in cache;
        if (p !is null) {
            auto cachedRank = cache[userId];
            return cachedRank.rankCount;
        }
        return blank.rankCount;
    }

    // Function to get ScoreInfo
    ScoreInfo[string] getUserScoreInfo(int userId) @trusted {
        auto p = userId in cache;
        if (p !is null) {
            auto cachedRank = cache[userId];
            if (cachedRank.scoreInfo !is null) {
                auto scoreInfo = cachedRank.scoreInfo;
                auto expiry_time = cachedRank.expiryTime;
                if (expiry_time > MonoTime.currTime()) {
                    // Cache entry is valid, return cached scoreInfo
                    return scoreInfo;
                } else {
                    // Cache entry expired, remove it
                    cache.remove(userId);
                }
            }
        }

        // Rank not found in cache, make the HTTP request
        // auto url = format("http://localhost:8080/rank-server/rest/caste/%d", userId);
        auto url = format(baseUrl ~ rankClientUri ~ "/%d", userId);
        
        ScoreInfo[string] requestScoreInfo;

        auto requester = delegate(scope HTTPClientRequest req) {
            req.method = HTTPMethod.GET;
            req.headers["bagrada-api-key"] = apiKey;
        };
        auto responder = delegate(scope HTTPClientResponse res) {
            if (res.statusCode == 200) {
                auto json = res.readJson();
                // Parse the response body to extract the rank array
                auto playerData = deserializeJson!RankRespDto(json);
                auto ranks = playerData.ranks;
                auto scoreInfo = playerData.scoreInfo;
                log_debug_message("Got scoreInfo");

                // Update cache with new scoreInfo and expiry time
                RankCacheEntry entry;
                entry.ranks = ranks;
                entry.scoreInfo = scoreInfo;
                entry.rankCount = playerData.rankCount;
                requestScoreInfo = scoreInfo;
                entry.expiryTime = MonoTime.currTime() + cacheTimeout;
                cache[userId] = entry;
            } else {
                RankCacheEntry entry;
                entry.ranks = blank.ranks;
                entry.expiryTime = MonoTime.currTime() + cacheTimeout;
                cache[userId] = entry;
                requestScoreInfo = blank.scoreInfo;
            }
        };

        try {
            requestHTTP(url, requester, responder);
            return requestScoreInfo;
        } catch (Exception e) {
            log_error_message("Exception getting scoreInfo: %s".format(e.msg));
        }
        return blank.scoreInfo;
    }
}
