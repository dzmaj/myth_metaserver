module room_server;

import log;
import room;
import room_connection;
import login_server;
import myth_socket;
import private_api;
import exceptions;
import host_proxy;
import metaserver_config;
import rank_client;
import game_reporter_client;

import std.stdio;
import std.ascii;
import std.random;
import std.file; // mkdirRecurse
import core.time;
import core.memory;
import std.typecons;

import vibe.vibe;

import std.algorithm; // Add this import

// This often it will set the dirty bit above and force an update
private immutable client_keep_alive_period = 3.minutes;
//private immutable client_keep_alive_period = 2.seconds;

private string generate_random_url_string()
{
    auto str = new char[](24);
    foreach(ref char c; str)
        c = letters[uniform(0, $)];
    return cast(string)str;
}


//-------------------------------------------------------------------------------------------------
// Build 409 - ATL - Room flags, set by the metaserver
enum RoomFlags
{
    _supports_recording_stream_flag = 1 << 0,
    _requires_recording_stream_flag = 1 << 1,
    _user_not_allowed_in_room       = 1 << 2,
};

struct room_info // Myth client structure, hence different style naming
{
    short room_id;
    short player_count;
    uint host; // IPV6 PROBLEM
    ushort port;
    short game_count;
    RoomType room_type;
    short room_flags;
    short[4] unused;
}


bool is_client_allowed_in_room(const(Client) client, const(room_info) room)
{
    // For now the only rule is guests can only go in unranked rooms
    return (!client.guest || room.room_type == RoomType.unranked);
}

// There may be a better place for this ultimately, but for now it fits nicely here since we need
// it both on the login server during the initial handshake, and later on the room servers for updates
room_info[] specialize_room_list_for_client(const(Client) client, const(room_info)[] rooms)
{
    auto result = rooms.dup;

    // For now we just add the "can't go in this room" flag as appropriate
    foreach (ref room; result)
    {
        if (is_client_allowed_in_room(client, room))
            room.room_flags &= (~RoomFlags._user_not_allowed_in_room);
        else
            room.room_flags |= RoomFlags._user_not_allowed_in_room;
    }

    return result;
}


//-------------------------------------------------------------------------------------------------
public class RoomServer
{
    public this(LoginServer login_server, ref const(MetaserverConfig) config)
    {
        m_login_server = login_server;
        m_address_ipv4 = resolve_address_to_ipv4(config.server_address, true, m_address_string_ipv4);
        
        // Set up host proxy
        m_host_proxy = new HostProxy(this,
                                     cast(ushort)config.host_proxy_pool_start,
                                     cast(ushort)config.host_proxy_pool_count);

        // Fetch room info from the database
        auto room_infos = m_login_server.data_store.get_room_infos(config.active_room_ids);

        foreach (ri; room_infos)
        {
            log_message("Room ID: %d, Name: %s, Room Type: %d, Requires Films: %s, Max Users: %d, Welcome Message: %s", ri.id, ri.name, ri.room_type, ri.requires_films, ri.max_users, ri.welcome_message);
            room_info info;
            info.room_id = cast(short)ri.id;
            info.room_type = cast(RoomType)ri.room_type;
            info.host = 0;  // 0 means same as metaserver address
            info.port = cast(ushort)(config.room_start_port + m_rooms.length);
            info.player_count = 0;
            info.game_count = 0;
            info.room_flags = RoomFlags._supports_recording_stream_flag |
                (ri.requires_films ? RoomFlags._requires_recording_stream_flag : 0);

            m_rooms ~= new Room(m_login_server, this, ri.name, info, ri.max_users, ri.welcome_message);
        }

        m_room_info = new room_info[m_rooms.length];
        set_room_data_dirty();

        runTask(&send_client_keep_alive);
    }

    private void send_client_keep_alive() nothrow
    {
        try {
            for (;;)
            {
            send_packet_to_all_clients(packet_type._keepalive_packet, []);
            sleep(client_keep_alive_period);
        }
        } catch (Exception e) {
            try {
                log_message("Error: ", e.msg);
            } catch (Exception e) {
                //logging exception, not sure what else to do here, but it has to be caught for this to be nothrow
            }
        }
        
    }

    private void send_packet_to_all_clients(packet_type type, immutable(ubyte)[] payload)
    {
        foreach (r; m_rooms)
            r.send_packet_to_all_clients(type, payload);
    }

    public void set_room_data_dirty()
    {
        foreach (i, r; m_rooms)
            m_room_info[i] = r.get_room_info();

        foreach (r; m_rooms)
            r.send_room_list_to_all_clients(m_room_info);
    }

    public pure nothrow Nullable!RoomConnection find_client_in_room(int user_id)
    {
        foreach (room; m_rooms)
        {
            auto connection = room.find_client_in_room(user_id);
            if (!connection.isNull()) return connection;
        }
        return Nullable!RoomConnection();
    }

    // Check if any given clients are in any of the rooms on this server, and optionally kick if so
    public bool[] check_clients_connected(int[] user_ids, bool kickAsDuplicate)
    {
        bool[] connected = new bool[user_ids.length];
        foreach (ref c; connected) c = false; // This may be implicit init, not sure

        foreach (i, user_id; user_ids)
        {
            // If we haven't yet marked this user as connected, check in each room
            if (!connected[i])
            {
                auto connection = find_client_in_room(user_id);
                if (!connection.isNull())
                {
                    connected[i] = true;
                    if (kickAsDuplicate)
                        connection.get().throw_exception_in_task(new DuplicateClientException(connection.get().client.user_id));
                }
            }
        }
        return connected;
    }

    public PublicRoomStatus[] get_public_status() const
    {
        PublicRoomStatus[] result;
        foreach (room; m_rooms)
            result ~= room.query_public_status();
        return result;
    }

    private void error_page(HTTPServerRequest req,
                            HTTPServerResponse res,
                            HTTPServerErrorInfo error)
    {
        res.writeBody("Not found");
    }

    public pure nothrow const(room_info)[] get_room_info() const { return m_room_info; }

    @property public pure nothrow ref const(MetaserverConfig) config() const { return m_login_server.config(); }
    @property public pure nothrow HostProxy host_proxy() { return m_host_proxy; }

    @property public pure nothrow string address_string_ipv4() const { return m_address_string_ipv4; }
    @property public pure nothrow uint address_ipv4() const { return m_address_ipv4; }
    @property @safe public pure nothrow const(Room[]) rooms() const { return m_rooms; }
    
    private LoginServer m_login_server;

    private string m_address_string_ipv4;
    private uint m_address_ipv4;

    private HostProxy m_host_proxy;
    private Room[] m_rooms;
    private room_info[] m_room_info;
    
    public Room createRoom(string roomName, RoomType roomType, bool requiresFilms, int maxUsers, int roomId = -1, string welcomeMessage = "")
    {
        int newRoomId = roomId != -1 ? roomId : (m_rooms.length > 0 ? m_rooms[$-1].room_id + 1 : 0);
        room_info info;
        info.room_id = cast(short)newRoomId;
        info.room_type = roomType;
        info.host = 0; // 0 means same as metaserver address
        info.port = cast(ushort)(config.room_start_port + newRoomId);
        info.player_count = 0;
        info.game_count = 0;
        info.room_flags = RoomFlags._supports_recording_stream_flag |
            (requiresFilms ? RoomFlags._requires_recording_stream_flag : 0);

        auto room = new Room(m_login_server, this, roomName, info, maxUsers, welcomeMessage);
        log_message("Created room %d", room.room_id);
        m_rooms ~= room;
        m_room_info ~= info;
        set_room_data_dirty();
        return room;
    }

    public void shutdownRoom(int roomId)
    {
        auto roomIndex = m_rooms.countUntil!(r => r.room_id == roomId);
        if (roomIndex != -1)
        {
            m_rooms[roomIndex].shutdown();
            m_rooms = m_rooms.remove(roomIndex);
            m_room_info = m_room_info.remove(roomIndex);
            set_room_data_dirty();
        }
    }
}