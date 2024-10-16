module metaserver_config;

import private_api;

import vibe.vibe;

public struct MetaserverConfig
{
    @optional string server_address = "127.0.0.1";    // NOTE: Should be set properly for any public server
    @optional string status_bind_address = "127.0.0.1";
    @optional string database_connection_string = "host=127.0.0.1;user=metaserver;db=metaserver_db;port=3306;pwd=metaserver"; // Empty = test mode!
    @optional string api_key = "test";
    @optional string api_user = "metaserver";
    @optional string game_reporter_completed_uri = "/report/games";
    @optional string game_reporter_started_uri = "/report/gameStart";
    @optional string rank_client_uri = "/rest/caste";
    @optional string rank_server_base_url = "http://localhost:8080/rank-server";
    @optional string rank_server_ws_url = "ws://localhost:8080/rank-server/ws/metaserver";

    @optional int http_server_port = 8080;
    @optional string http_server_log_file = "";

    @optional bool allow_guests = true;               // Guests log in with empty passwords
    @optional bool nick_name_is_user_name = false;    // If true, forces nick names to be the same as user names (where possible)

    @optional int login_port = 6321;

    // NOTE: For full functionality, requires 428+ due to host proxy support and related fixes
    @optional int minimum_client_build = 427;

    struct RoomConfig
    {
        @optional int room_id = -1;    // Controls which banner is used; -1 = last room ID +1
        @optional string name = "";    // Mainly for log file; "" = some default name based on ID
        @optional RoomType type = RoomType.unranked;
        @optional bool requires_films = false;
    };

    // Rooms
    @optional int[] active_room_ids = [];

    @optional int room_start_port = 6323; // NOTE: Could let the user customize this per room...
    @optional int maximum_users_per_room = 999;

    @optional string recordings_path = "recordings/";
    @optional string recordings_prefix = "bagrada";
    @optional string recordings_ext = ".m2rec";

    // Host proxy
    @optional int host_proxy_pool_start = 61000;
    @optional int host_proxy_pool_count = 10;
};
