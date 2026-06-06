package com.example.prosper.config;

import java.util.List;
import java.util.Map;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class PgTrgmConfig {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PostConstruct
    public void initialize() {
        enablePgTrgm();
        migrateSearchVector();
    }

    private void enablePgTrgm() {
        try {
            jdbcTemplate.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm");
            System.out.println("[PgTrgm] pg_trgm extension enabled");
        } catch (Exception e) {
            System.out.println("[PgTrgm] pg_trgm enable failed: " + e.getMessage());
        }
    }

    private void migrateSearchVector() {
        try {
            // Query the generated expression from pg_catalog to check if title is included
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT pg_get_expr(d.adbin, d.adrelid) AS expr " +
                "FROM pg_attribute a " +
                "JOIN pg_class c ON c.oid = a.attrelid " +
                "JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum " +
                "WHERE c.relname = 'chapters' AND a.attname = 'search_vector'"
            );

            String currentExpr = rows.isEmpty() ? "" : String.valueOf(rows.get(0).get("expr"));

            if (!currentExpr.contains("title")) {
                System.out.println("[PgTrgm] Migrating search_vector to include title...");
                jdbcTemplate.execute("ALTER TABLE chapters DROP COLUMN IF EXISTS search_vector");
                jdbcTemplate.execute(
                    "ALTER TABLE chapters ADD COLUMN search_vector tsvector " +
                    "GENERATED ALWAYS AS (" +
                    "  to_tsvector('russian', COALESCE(title, '') || ' ' || COALESCE(content, ''))" +
                    ") STORED"
                );
                jdbcTemplate.execute("DROP INDEX IF EXISTS idx_chapters_fts");
                jdbcTemplate.execute("DROP INDEX IF EXISTS idx_chapters_search_vector");
                jdbcTemplate.execute(
                    "CREATE INDEX idx_chapters_search_vector ON chapters USING GIN(search_vector)"
                );
                System.out.println("[PgTrgm] search_vector migration complete (title + content)");
            } else {
                System.out.println("[PgTrgm] search_vector already includes title, skipping migration");
            }
        } catch (Exception e) {
            System.out.println("[PgTrgm] search_vector migration error: " + e.getMessage());
        }
    }
}
