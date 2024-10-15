module orders;

import private_api;
import mac_roman;
import endian;
import room_client;

import std.string;
import std.array;
import std.conv;
import std.bitmanip;

// import myth_socket;

class OrderMember {
    public PlayerData player_data;
    public bool online;
    private int[RoomType.num] m_caste_bitmap_indices;
    this(PlayerData player_data, bool online) {
        this.player_data = player_data;
        this.online = online;
        this.m_caste_bitmap_indices = [-1,-1,-1];
    }

    public immutable(ubyte)[] player_data_big_endian() const {
        // Swap endian if necessary and return a copy
        union player_data_union
        {
            ubyte[metaserver_player_data.sizeof] bytes = void;
            metaserver_player_data data;
        }
        metaserver_player_data mspd = metaserver_player_data(
            cast(byte)player_data.coat_of_arms_bitmap_index,
            cast(byte)-1,
            cast(short)0,
            int_to_rgb_color(player_data.primary_color, false),
            int_to_rgb_color(player_data.secondary_color, false),
            cast(short)player_data.order_id,
            cast(short)player_data.game_version,
            cast(short)player_data.build_number
        );
        player_data_union player_data_big_endian = void;
        player_data_big_endian.data = native_to_big_endian(mspd);
        // Pad the result bytes up to a total of 128 bytes
        ubyte[] result_bytes = player_data_big_endian.bytes.dup;
        result_bytes ~= string_to_mac_roman(player_data.nick_name);
        result_bytes ~= string_to_mac_roman(player_data.team_name);

        return result_bytes.idup;
    }

}

struct OrderList {
    int memberCount;
    OrderMember[] members;
}

struct OrderMemberShort {
    uint user_id;
    bool online;
}
