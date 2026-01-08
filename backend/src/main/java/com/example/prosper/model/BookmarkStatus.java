package com.example.prosper.model;

public enum BookmarkStatus {
    READING("В процессе"),
    COMPLETED("Прочитанное"),
    FAVORITE("Любимое"),
    DROPPED("Брошенное"),
    PLANNED("В планах");

    private final String displayName;

    BookmarkStatus(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}