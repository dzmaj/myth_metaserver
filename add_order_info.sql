

CREATE TABLE IF NOT EXISTS `orders` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE `metaserver_users`
ADD COLUMN `order_id` INT,
ADD FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`);

ALTER TABLE `orders`
ADD COLUMN `description` VARCHAR(255),
ADD COLUMN `owner_id` INT,
ADD FOREIGN KEY (`owner_id`) REFERENCES `metaserver_users` (`id`);

CREATE TABLE IF NOT EXISTS `order_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `order_id` INT NOT NULL,
  `user_id` INT NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`),
  FOREIGN KEY (`user_id`) REFERENCES `metaserver_users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE `orders`
ADD COLUMN `password` VARCHAR(255),
ADD COLUMN `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE `orders`
MODIFY COLUMN `description` VARCHAR(255) NOT NULL DEFAULT '';

ALTER TABLE `orders`
DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `orders`
MODIFY COLUMN `name` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
MODIFY COLUMN `description` VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
MODIFY COLUMN `password` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci;

CREATE TABLE authorities (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE user_authorities (
    user_id INT,
    authority_id BIGINT,
    PRIMARY KEY (user_id, authority_id),
    FOREIGN KEY (user_id) REFERENCES metaserver_users(id),
    FOREIGN KEY (authority_id) REFERENCES authorities(id)
);