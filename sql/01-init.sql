SET NAMES utf8;

DROP DATABASE `fancytank`;
CREATE DATABASE `fancytank`;
USE `fancytank`;

CREATE TABLE `user` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,

  `email`       VARCHAR(255) NOT NULL,
  `password`    CHAR(50)     DEFAULT NULL COMMENT 'first 40 length for digest, after 10 length for salt(random)',

  `first_name`  VARCHAR(64)  NOT NULL, -- over 192?
  `last_name`   VARCHAR(64)  NOT NULL, -- over 192?
  `time_zone`   VARCHAR(32)  NOT NULL,

  `create_time` INT(11)      DEFAULT NULL,
  `update_time` INT(11)      DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE  KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
