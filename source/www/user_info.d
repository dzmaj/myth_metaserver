import std.typecons;

struct UserInfo {
    Nullable!LoginToken loginToken;
    Nullable!User user;
    Nullable!DiscordAttributes discordAttributes;
    bool authenticated;
    Nullable!GrantedAuthority[] authorities;
}

struct LoginToken {
    int id;
    long discordId;
    string userNameToken;
    string passwordToken;
}

struct User {
    int id;
    Nullable!string nickName;
    Nullable!string teamName;
    int primaryColor;
    int secondaryColor;
    int coatOfArmsBitmapIndex;
    // Nullable!string city;
    // Nullable!string state;
    // Nullable!string country;
    // Nullable!string quote;
    int adminLevel;
    // Nullable!string registrationDatetime;
    // Nullable!string lastLoginDatetime;
    // Nullable!string bannedUntil;
    // Nullable!string bannedReason;
}

struct DiscordAttributes {
    Nullable!string discordName;
    long discordId;
}

struct GrantedAuthority {
    string authority;
}