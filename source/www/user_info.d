
struct UserInfo {
    LoginToken loginToken;
    User user;
    DiscordAttributes discordAttributes;
    bool authenticated;
    GrantedAuthority[] authorities;
}

struct LoginToken {
    int id;
    long discordId;
    string userNameToken;
    string passwordToken;
}

struct User {
    int id;
    string nickName;
    string teamName;
    int primaryColor;
    int secondaryColor;
    int coatOfArmsBitmapIndex;
    string city;
    string state;
    string country;
    string quote;
    int adminLevel;
    string registrationDatetime;
    string lastLoginDatetime;
    string bannedUntil;
    string bannedReason;
}

struct DiscordAttributes {
    string discordName;
    long discordId;
}

struct GrantedAuthority {
    string authority;
}
