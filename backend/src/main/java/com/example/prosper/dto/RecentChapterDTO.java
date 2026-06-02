package com.example.prosper.dto;

public class RecentChapterDTO {
    private Long id;
    private Integer chapterOrder;
    private String title;
    private Long bookId;
    private String bookTitle;
    private String bookCoverUrl;

    public RecentChapterDTO(Long id, Integer chapterOrder, String title,
                            Long bookId, String bookTitle, String bookCoverUrl) {
        this.id = id;
        this.chapterOrder = chapterOrder;
        this.title = title;
        this.bookId = bookId;
        this.bookTitle = bookTitle;
        this.bookCoverUrl = bookCoverUrl;
    }

    public Long getId() { return id; }
    public Integer getChapterOrder() { return chapterOrder; }
    public String getTitle() { return title; }
    public Long getBookId() { return bookId; }
    public String getBookTitle() { return bookTitle; }
    public String getBookCoverUrl() { return bookCoverUrl; }
}
