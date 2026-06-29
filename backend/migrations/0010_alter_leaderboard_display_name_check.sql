-- Migration number: 0010 hand-written (NOT teeny-generated).
-- Adds CHECK (length(display_name) BETWEEN 1 AND 32) to leaderboard.display_name.
-- SQLite has no ALTER TABLE ADD CONSTRAINT, so the table is rebuilt per the
-- official 12-step procedure (https://sqlite.org/lang_altertable.html). The
-- schema below mirrors 0009 exactly, plus the CHECK. Existing rows are truncated
-- to 32 chars on copy so the new constraint can't fail on legacy data.
--
-- Apply with:  npx wrangler d1 migrations apply verbum --remote
-- Do NOT use `teeny generate`/`teeny deploy` here — they rewrite the whole
-- migration history from an empty ledger.

CREATE TABLE leaderboard_new (
	id TEXT PRIMARY KEY NOT NULL,
	created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	user_id TEXT UNIQUE NOT NULL,
	display_name TEXT NOT NULL CHECK (length(display_name) BETWEEN 1 AND 32),
	xp INTEGER NOT NULL DEFAULT 0
);
INSERT INTO leaderboard_new (id, created, updated, user_id, display_name, xp)
	SELECT id, created, updated, user_id, substr(display_name, 1, 32), xp FROM leaderboard;
DROP TABLE leaderboard;
ALTER TABLE leaderboard_new RENAME TO leaderboard;
CREATE INDEX idx_leaderboard_leaderboard_xp ON leaderboard (xp);
CREATE TRIGGER tgr_leaderboard_raise_on_created_update BEFORE UPDATE OF created ON leaderboard BEGIN SELECT RAISE(FAIL, 'Cannot update created column') WHERE OLD.created != NEW.created; END;
CREATE TRIGGER tgr_leaderboard_update_updated_on_update AFTER UPDATE ON leaderboard BEGIN UPDATE leaderboard SET updated = CURRENT_TIMESTAMP WHERE id = NEW.id AND OLD.updated = NEW.updated; END;
