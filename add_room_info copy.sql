CREATE TABLE room_info (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    room_type TINYINT NOT NULL,
    requires_films BOOLEAN NOT NULL,
    max_users INT NOT NULL,
    order_id INT,
    welcome_message VARCHAR(255),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_active_at DATETIME,
    stopped_at DATETIME,
    last_ownership_change_at DATETIME,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

ALTER TABLE metaserver_games
ADD COLUMN room_id INT,
ADD CONSTRAINT fk_room_id FOREIGN KEY (room_id) REFERENCES room_info(id);