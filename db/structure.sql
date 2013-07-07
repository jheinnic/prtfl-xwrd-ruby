CREATE TABLE `crosswords` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bonus_word` varchar(5) NOT NULL DEFAULT '',
  `bonus_value` int(11) NOT NULL DEFAULT '-1',
  `revealed` varchar(18) NOT NULL DEFAULT '',
  `last_calc_revealed` varchar(18) NOT NULL DEFAULT '',
  `actual_prize` int(11) DEFAULT NULL,
  `pays00` int(11) NOT NULL DEFAULT '0',
  `pays01` int(11) NOT NULL DEFAULT '0',
  `pays02` int(11) NOT NULL DEFAULT '0',
  `pays03` int(11) NOT NULL DEFAULT '0',
  `pays04` int(11) NOT NULL DEFAULT '0',
  `pays05` int(11) NOT NULL DEFAULT '0',
  `pays06` int(11) NOT NULL DEFAULT '0',
  `pays07` int(11) NOT NULL DEFAULT '0',
  `pays08` int(11) NOT NULL DEFAULT '0',
  `pays09` int(11) NOT NULL DEFAULT '0',
  `pays10` int(11) NOT NULL DEFAULT '0',
  `pays11` int(11) NOT NULL DEFAULT '0',
  `pays12` int(11) NOT NULL DEFAULT '0',
  `pays13` int(11) NOT NULL DEFAULT '0',
  `pays14` int(11) NOT NULL DEFAULT '0',
  `pays15` int(11) NOT NULL DEFAULT '0',
  `pays16` int(11) NOT NULL DEFAULT '0',
  `pays17` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=utf8;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `word_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `crossword_id` int(11) NOT NULL,
  `text_value` varchar(12) NOT NULL DEFAULT '',
  `x_coordinate` int(2) NOT NULL DEFAULT '-1',
  `y_coordinate` int(2) NOT NULL DEFAULT '-1',
  `is_horizontal` tinyint(1) DEFAULT '0',
  `triple_letter_index` int(2) NOT NULL DEFAULT '-1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_word_items_on_crossword_id_and_text_value` (`crossword_id`,`text_value`)
) ENGINE=InnoDB AUTO_INCREMENT=755 DEFAULT CHARSET=utf8;

INSERT INTO schema_migrations (version) VALUES ('20121226092101');