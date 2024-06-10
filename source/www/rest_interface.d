import www_data_store;
import log;

import std.stdio;
import std.uni;
import std.stdint;
import std.algorithm.comparison;

import vibe.d;
import vibe.stream.stdio;
import vibe.http.common;


@path("/www/rest/")
interface RestApi {
    @path("/games/:id") @method(HTTPMethod.GET)
    Game getGame(int _id);
}

class RestApiImpl : RestApi {
    private {
        WWWDataStoreInterface m_data_store;
    }

    public this(WWWDataStoreInterface dataStore) {
        m_data_store = dataStore;
    }

    @safe Game getGame(int _id) {
        return getGameData(_id);
    }

    @trusted Game getGameData(int _id) {
        try {
            return m_data_store.game(_id);
        } catch (Exception e) {
            return Game();
        }
    }
    
}

