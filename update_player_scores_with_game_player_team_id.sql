

ALTER TABLE player_scores ADD COLUMN game_team_player_id INT;

UPDATE player_scores ps
INNER JOIN metaserver_games mg ON mg.id = ps.game_id
INNER JOIN metaserver_games_teams mgt ON mgt.metaserver_games_id = mg.id
INNER JOIN metaserver_games_teams_players mgtp ON mgtp.metaserver_games_teams_id = mgt.id
AND mgtp.user_id = ps.user_id
SET ps.game_team_player_id = mgtp.id;

ALTER TABLE player_scores
ADD CONSTRAINT fk_game_team_player_id
FOREIGN KEY (game_team_player_id)
REFERENCES metaserver_games_teams_players(id);