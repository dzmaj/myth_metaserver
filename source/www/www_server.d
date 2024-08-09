import www_data_store;
import private_api : PublicServerStatus;
import log;
import rest_interface;
import user_info;

import std.stdio;
import std.uni;
import std.stdint;
import std.algorithm.comparison;

import vibe.d;
import vibe.stream.stdio;
import vibe.http.common;
import vibe.data.json;


public struct WWWConfig
{
    // Cannot do anything useful without a database here
    string database_connection_string;

    // Required for discord authentication - must match the base URL of the server. NO TRAILING SLASH.
    @optional string site_url = "http://localhost";

	// Required for live Metaserver status
	@optional string metaserver_status_url = "http://localhost:8080/";

    @optional string recordings_path = "./recordings/public/";

    @optional int http_server_port = 8081;
    @optional string http_server_log_file = "";
    @optional string server_address = "127.0.0.1";

	// User ID of the site super-admin (can create tournaments, etc)
	@optional int super_admin_user_id = 11;

    @optional string bagrada_login = "https://bagrada.net/rank-server/auth/status";
};

public class WWWServer
{
    public this(WWWConfig config)
    {
        m_config = config;

        //m_data_store = new WWWDataStoreNull();
        m_data_store = new WWWDataStoreMysql(m_config.database_connection_string);

        auto settings = new HTTPServerSettings;
        settings.errorPageHandler = toDelegate(&error_page);
        settings.port = cast(ushort)m_config.http_server_port;
        settings.sessionStore = new MemorySessionStore();
        settings.bindAddresses = [m_config.server_address];

        if (!m_config.http_server_log_file.empty)
            settings.accessLogFile = m_config.http_server_log_file;

	    auto router = new URLRouter;
    
        router.get("/www/", &index);
        router.get("/www/account/", &account);
        router.get("/www/account/logout/", &account_logout);
        router.get("/www/account/discord_login_return/", &account_discord_login_return);

        router.get("/www/games/", &games);
        router.get("/www/games/:game_id/", &game);
		router.get("/www/games/:game_id/download/", &game_download);

		router.get("/www/users/", &users);
        router.get("/www/users/:user_id/", &user);
		router.get("/www/users/:user_id", &user);		// Metaserver uses this one, so always include it

        router.get("/www/tournaments/", &tournaments);			
        router.get("/www/tournaments/:tournament_short_name/", &tournament);
        router.get("/www/tournaments/:tournament_short_name/rounds/:round_id/", &tournament_round);
        router.get("/www/tournaments/:tournament_short_name/rounds/:round_id/games/:game_id/", &tournament_round_game);
		router.get("/www/tournaments/:tournament_short_name/rounds/:round_id/games/:game_id/download/", &tournament_round_game_download);

		router.post("/www/tournaments/", &tournament_create);
		router.post("/www/tournaments/:tournament_short_name/", &tournament_round_create);
		router.post("/www/tournaments/:tournament_short_name/rounds/:round_id/", &tournament_round_game_create);

        auto file_server_settings = new HTTPFileServerSettings;
        file_server_settings.serverPathPrefix = "/www/recordings/";
        router.get("/www/recordings/*", serveStaticFiles(m_config.recordings_path, file_server_settings));

		router.get("/www/metaserver/", &metaserver);
			
        router.get("/www/faq/", &faq);

        router.registerRestInterface(new RestApiImpl(m_data_store));
	
        debug
        {
            // Show routes in debug for convenience
            foreach (route; router.getAllRoutes()) {
                writeln(route);
            }
        }
        else
        {
            // Add a redirect from each GET route without a trailing slash for robustness
            // Leave this disabled in debug/dev builds so we don't accidentally include non-canonical links
            foreach (route; router.getAllRoutes()) {
                if (route.method == HTTPMethod.GET && route.pattern.length > 1 && route.pattern.endsWith("/")) {
                    router.get(route.pattern[0..$-1], redirect_append_slash());
                }
            }

            foreach (route; router.getAllRoutes()) {
                writeln(route);
            }
        }

        router.get("/www/*", serveStaticFiles("./public/"));

    

	    listenHTTP(settings, router);
    }

	// Utility to query the metaserver for live status
	// Returns true on success, false on failure (metaserver down or similar)
	bool query_metaserver_status(out PublicServerStatus status)
	{
		// TODO: Better error handling of various forms here
		try 
		{
			string url = m_config.metaserver_status_url ~ "status.json";
			requestHTTP(url,
				(scope req) { req.method = HTTPMethod.GET; },
				(scope res) 
				{
					auto response = res.readJson();
					deserializeJson(status, response);
				});

			return true;
		}
		catch (Exception e)
		{
			log_message("ERROR querying metaserver status: %s", e.msg);
		}

		return false;
	}

    // Handy utility for adding some robustness to routes
    // NOTE: Be careful with this for paths that might contain query strings or other nastiness
    private HTTPServerRequestDelegate redirect_append_slash(HTTPStatus status = HTTPStatus.found)
    {
	    return (HTTPServerRequest req, HTTPServerResponse res) {
            // This is a bit awkward but seems to do the trick for the moment...
            auto url = req.fullURL();
            auto path = url.path;
            path.endsWithSlash = true;

            url.path = path;
            writefln("%s -> %s", req.fullURL(), url);
            res.redirect(url, status);
	    };
    }

	// Structure of common data passed to all page rendering (generally as "global")
	struct GlobalInfo
    {
        Tournament[] recent_tournaments;

        // Set if there is a logged-in user
        uint64_t logged_in_discord_id  =  0;   // 0 = invalid for discord ID
        int      logged_in_user_id     = -1;
        string   logged_in_nick_name   = "";
        bool     logged_in_super_admin = false; // Careful - if set logged in user gets lots of capabilities

        // Helpers
        bool is_logged_in_tournament_organizer(int organizer_user_id)
        {
            return logged_in_super_admin || (logged_in_user_id >= 0 && logged_in_user_id == organizer_user_id);
        }
    }


	private bool is_user_super_admin(int user_id)
	{
		return (m_config.super_admin_user_id >= 0 && user_id == m_config.super_admin_user_id);
	}

	private GlobalInfo get_global_info(HTTPServerRequest req)
	{
		GlobalInfo global;
		
		// Database info
		global.recent_tournaments = m_data_store.tournaments(true);

		// Session info
		if (req.session)
		{
			global.logged_in_discord_id  = req.session.get!uint64_t("logged_in_discord_id",   0);
			global.logged_in_user_id   = req.session.get!int     ("logged_in_user_id",   -1);
			global.logged_in_nick_name = req.session.get!string  ("logged_in_nick_name", "");
			global.logged_in_super_admin = is_user_super_admin(global.logged_in_user_id);
		}

		return global;
	}

	// *************************************** MISC PAGES ************************************************

    private void index(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto global = get_global_info(req);
        res.render!("index.dt", global);
    }

    private void faq(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto global = get_global_info(req);
        res.render!("faq.dt", global);
    }

    private void games(HTTPServerRequest req, HTTPServerResponse res)
    {
        try
        {
            // TODO: Limits, pagination, filters, sorting
            auto global = get_global_info(req);

            // Basic game list pagination
            immutable int games_per_page = 30;
            int games_current_page = max(1, req.query.get("page", "1").to!int());     // NB: 1-based
            int games_count = 0;
            auto games = m_data_store.games((games_current_page - 1) * games_per_page, games_per_page, games_count);
            int games_page_count = (games_count + games_per_page - 1) / games_per_page;

            res.render!("games.dt", global, games, games_current_page, games_page_count);
        }
        catch (Exception e)
        {
            res.redirect("/www/games/");
            log_message("Error rendering games page: %s", e.msg);
            throw e;
        }
    }

    private void game(HTTPServerRequest req, HTTPServerResponse res)
    {
        int game_id = req.params["game_id"].to!int();

        auto global = get_global_info(req);
        auto game = m_data_store.game(game_id);

        res.render!("game.dt", global, game);
    }

	private void game_download(HTTPServerRequest req, HTTPServerResponse res)
    {
		// This does an unnecessary amount of db work, but fine for now
        int game_id = req.params["game_id"].to!int();
        auto game = m_data_store.game(game_id);

        if (!game.recording_file_name.empty)
			res.redirect("/www/recordings/" ~ game.recording_file_name);
    }

	private void users(HTTPServerRequest req, HTTPServerResponse res)
    {
		// No "list of users" page currently, so just redirect home
        res.redirect("/www/");
    }

    private void user(HTTPServerRequest req, HTTPServerResponse res)
    {
        int user_id = req.params["user_id"].to!int();

        auto global = get_global_info(req);
        auto user = m_data_store.user(user_id);

		// Basic game list pagination
		// TODO: Centralize this logic somewhere
        immutable int games_per_page = 30;
        int games_current_page = max(1, req.query.get("page", "1").to!int());     // NB: 1-based
        int games_count = 0;
        auto games = m_data_store.games((games_current_page - 1) * games_per_page, games_per_page, games_count, user_id);
        int games_page_count = (games_count + games_per_page - 1) / games_per_page;

        res.render!("user.dt", global, user, games, games_current_page, games_page_count);
    }

	private void metaserver(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto global = get_global_info(req);

		// TODO: This is probably a good place to catch all sorts of fun exceptions and render a default page...
		PublicServerStatus status;
		bool online = query_metaserver_status(status);

        res.render!("metaserver.dt", global, online, status);
    }


	// *************************************** TOURNAMENT ************************************************
	
    private void tournaments(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto global = get_global_info(req);
        auto tournaments = m_data_store.tournaments(false);
        res.render!("tournaments.dt", global, tournaments);
    }
	
    private void tournament(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto global = get_global_info(req);
        auto tournament = m_data_store.tournament(req.params["tournament_short_name"]);
        auto rounds = m_data_store.tournament_rounds(tournament.tournament_id);

        // Default ordering
        // TODO: Custom ordering
        auto order = PlayerStatsColumn.WinTieLoss;
        auto player_stats = m_data_store.tournament_player_stats(tournament.tournament_id, -1, order, true);

        res.render!("tournament.dt", global, tournament, rounds, player_stats);
    }

	private void tournament_round_game(HTTPServerRequest req, HTTPServerResponse res)
    {
        string tournament_short_name = req.params["tournament_short_name"];
        int round_id = req.params["round_id"].to!int();
        int game_id = req.params["game_id"].to!int();

        auto global = get_global_info(req);
        auto tournament = m_data_store.tournament(tournament_short_name);
        auto round = m_data_store.tournament_round(round_id);
        auto game = m_data_store.game(game_id);

        res.render!("tournament_round_game.dt", global, tournament, round, game);
    }

	private void tournament_round_game_download(HTTPServerRequest req, HTTPServerResponse res)
    {
		// TODO: Rename file and other fanciness
        int game_id = req.params["game_id"].to!int();
        auto game = m_data_store.game(game_id);

        if (!game.recording_file_name.empty)
			res.redirect("/www/recordings/" ~ game.recording_file_name);
    }

    private void tournament_round(HTTPServerRequest req, HTTPServerResponse res)
    {
        string tournament_short_name = req.params["tournament_short_name"];
        int round_id = req.params["round_id"].to!int();
    
        // Qualify the lookup by both tournament and round to avoid confusing route names,
        // even though the round ID by itself is sufficient to uniquely identify a round
        auto global = get_global_info(req);
        auto tournament = m_data_store.tournament(tournament_short_name);
        auto round = m_data_store.tournament_round(round_id);
        auto games = m_data_store.tournament_round_games(round_id);

        // Default ordering
        // TODO: Custom ordering
        auto order = PlayerStatsColumn.WinTieLoss;
        auto player_stats = m_data_store.tournament_player_stats(tournament.tournament_id, round_id, order, true);

        res.render!("tournament_round.dt", global, tournament, round, games, player_stats);
    }

	// *********************************** TOURNAMENT CREATE/DELETE *******************************************

	private void tournament_create(HTTPServerRequest req, HTTPServerResponse res)
    {
		auto global = get_global_info(req);
		string create_tournament_error_msg = "";
		string create_tournament_success_msg = "";

        // Required parameters and permissions
        if (global.logged_in_super_admin &&
            ("create_tournament_name" in req.form) &&
			("create_tournament_short_name" in req.form))
        {
			string tournament_name = req.form["create_tournament_name"];
			string tournament_short_name  = req.form["create_tournament_short_name"];

			int tournament_id = m_data_store.create_tournament(tournament_name, tournament_short_name);
			if (tournament_id >= 0)
				create_tournament_success_msg = "Tournament created successfully.";
			else
				create_tournament_error_msg = "Failed to create tournament.";
        }

		res.redirect("/www/tournaments/");
    }

	private void tournament_round_create(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto global = get_global_info(req);
        auto tournament = m_data_store.tournament(req.params["tournament_short_name"]);

		// Required parameters and permissions
        if (global.is_logged_in_tournament_organizer(tournament.organizer_user_id) &&
            ("create_round_name" in req.form))
        {
			string round_name = req.form["create_round_name"];
			m_data_store.create_tournament_round(tournament.tournament_id, round_name);
		}

		// Redirect and re-render tournament page as usual
		res.redirect("/www/tournaments/" ~ req.params["tournament_short_name"] ~ "/");
    }

    private void tournament_round_game_create(HTTPServerRequest req, HTTPServerResponse res)
    {
        string tournament_short_name = req.params["tournament_short_name"];
        int round_id = req.params["round_id"].to!int();

		auto global = get_global_info(req);
        auto tournament = m_data_store.tournament(req.params["tournament_short_name"]);

		// Required parameters and permissions
        if (global.is_logged_in_tournament_organizer(tournament.organizer_user_id) &&
            ("add_game_id" in req.form))
        {
			int game_id = req.form["add_game_id"].to!int();
			m_data_store.create_tournament_round_game(round_id, game_id);
		}

        res.redirect("/www/tournaments/" ~ req.params["tournament_short_name"] ~ "/rounds/" ~ to!string(round_id) ~ "/");
    }



    // *************************************** ACCOUNT ************************************************
    private void account(HTTPServerRequest req, HTTPServerResponse res)
    {
        if (req.session && req.session.isKeySet("logged_in_discord_id"))
        {
            auto discord_id = req.session.get!uint64_t("logged_in_discord_id");

            // Look up login tokens via discord ID
            // If valid, render the page with the logged-in metaserver user
            auto login = m_data_store.user_login_tokens(discord_id);
            if (login.valid)
            {
                // Store user data in session for easy access
                req.session.set("logged_in_user_id", login.user_id);
                req.session.set("logged_in_nick_name", login.nick_name);

                auto global = get_global_info(req);
                res.render!("account_meta.dt", global, login);
            }
            else
            {
                // Redirect to the Spring Boot login page if the user is not found
                try
                {
                    res.redirect("/www/account/discord_login_return/");
                }
                catch (Exception e)
                {
                    log_message("Error while authenticating user: %s", e.msg);
                    res.redirect("/rank-server/login");
                }
            }
        }
        else
        {
            res.redirect("/www/account/discord_login_return/");
        }
    }



    private void account_discord_login_return(HTTPServerRequest req, HTTPServerResponse res)
    {
    try
    {
        string auth_response;
        requestHTTP(m_config.bagrada_login,
            (scope HTTPClientRequest login_req)
            {
                login_req.method = HTTPMethod.GET;
                // Add the 'Cookie' header if necessary
                if (req.headers["Cookie"].length > 0) {
                    login_req.headers["Cookie"] = req.headers["Cookie"];
                }
            },
            (scope HTTPClientResponse login_res)
            {
                auth_response = login_res.bodyReader.readAllUTF8();
                log_message("Got auth response %s", auth_response);
            });

        // Parse the JSON response to extract user information
        auto user_info = deserializeJson!UserInfo(auth_response);

        if (user_info.authenticated)
        {
            log_message("User is authenticated");
            if (!req.session)
                req.session = res.startSession();
            req.session.set("logged_in_discord_id", user_info.discordAttributes.discordId);
            req.session.set("logged_in_user_id", user_info.user.id);
            req.session.set("logged_in_nick_name", user_info.user.nickName);
            req.session.set("logged_in_super_admin", user_info.user.adminLevel >= 1);
        }
        else
        {
            log_message("Authentication failed for user.");
            // Handle the case where authentication fails
            res.redirect("/rank-server/login");
        }
    }
    catch (Exception e)
    {
        log_message("Error logging in user: %s", e.msg);
        throw e;
    }

    res.redirect("/www/account/");
}


    private void account_logout(HTTPServerRequest req, HTTPServerResponse res)
    {
        // Notify the Spring Boot application about the logout (optional)
        // auto url = bagrada_login ~ "/logout";
        // requestHTTP(url, (scope HTTPClientRequest logout_req)
        // {
        //     logout_req.method = HTTPMethod.POST;
        //     logout_req.headers["Cookie"] = req.headers["Cookie"];
        // });

        // Clear relevant session data for this user
        if (req.session)
            res.terminateSession();

        res.redirect("/www/account/");
    }



    // *************************************** ERROR ************************************************

    private void error_page(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error)
    {
        // To be extra safe, we avoid DB queries in the error page for now
        res.render!("error.dt", req, error);
    }



    // *************************************** STATE ************************************************

    // NOTE: Be a bit careful with state here. These functions can be parallel and re-entrant due to
    // triggering blocking calls and then having other requests submitted by separate fibers.
    private immutable WWWConfig m_config;
    private __gshared static WWWDataStoreInterface m_data_store;
}
