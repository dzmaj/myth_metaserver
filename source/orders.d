module orders;

import private_api;
import mac_roman;
import endian;

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
            ubyte[PlayerData.sizeof] bytes = void;
            PlayerData data;
        }
        player_data_union player_data_big_endian = void;
        player_data_big_endian.data = native_to_big_endian(player_data);
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
