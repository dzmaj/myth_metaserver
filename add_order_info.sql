

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
ADD COLUMN `order_info` VARCHAR(255)
ADD COLUMN `owner_id` INT
ADD FOREIGN KEY (`owner_id`) REFERENCES `metaserver_users` (`id`);

CREATE TABLE IF NOT EXISTS `order_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `order_id` INT NOT NULL,
  `user_id` INT NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`),
  FOREIGN KEY (`user_id`) REFERENCES `metaserver_users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

