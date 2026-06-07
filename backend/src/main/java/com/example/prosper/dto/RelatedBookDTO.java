package com.example.prosper.dto;

import com.example.prosper.model.RelatedBook;

public class RelatedBookDTO {
    private Long id;
    private Long bookId;
    private Long relatedBookId;
    private String relatedBookTitle;
    private String relatedBookAuthor;
    private String relatedBookCoverUrl;
    private String relationType;

    public RelatedBookDTO() {}

    public RelatedBookDTO(RelatedBook relatedBook) {
        this.id = relatedBook.getId();
        this.bookId = relatedBook.getBook().getId();
        this.relatedBookId = relatedBook.getRelatedBook().getId();
        this.relatedBookTitle = relatedBook.getRelatedBook().getTitle();
        this.relatedBookAuthor = relatedBook.getRelatedBook().getAuthor();
        this.relatedBookCoverUrl = relatedBook.getRelatedBook().getCoverUrl();
        this.relationType = relatedBook.getRelationType().toString();
    }

    public RelatedBookDTO(RelatedBook relatedBook, boolean reversed) {
        this.id = relatedBook.getId();
        if (reversed) {
            this.bookId = relatedBook.getRelatedBook().getId();
            this.relatedBookId = relatedBook.getBook().getId();
            this.relatedBookTitle = relatedBook.getBook().getTitle();
            this.relatedBookAuthor = relatedBook.getBook().getAuthor();
            this.relatedBookCoverUrl = relatedBook.getBook().getCoverUrl();
        } else {
            this.bookId = relatedBook.getBook().getId();
            this.relatedBookId = relatedBook.getRelatedBook().getId();
            this.relatedBookTitle = relatedBook.getRelatedBook().getTitle();
            this.relatedBookAuthor = relatedBook.getRelatedBook().getAuthor();
            this.relatedBookCoverUrl = relatedBook.getRelatedBook().getCoverUrl();
        }
        this.relationType = relatedBook.getRelationType().toString();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getBookId() { return bookId; }
    public void setBookId(Long bookId) { this.bookId = bookId; }

    public Long getRelatedBookId() { return relatedBookId; }
    public void setRelatedBookId(Long relatedBookId) { this.relatedBookId = relatedBookId; }

    public String getRelatedBookTitle() { return relatedBookTitle; }
    public void setRelatedBookTitle(String relatedBookTitle) { this.relatedBookTitle = relatedBookTitle; }

    public String getRelatedBookAuthor() { return relatedBookAuthor; }
    public void setRelatedBookAuthor(String relatedBookAuthor) { this.relatedBookAuthor = relatedBookAuthor; }

    public String getRelatedBookCoverUrl() { return relatedBookCoverUrl; }
    public void setRelatedBookCoverUrl(String relatedBookCoverUrl) { this.relatedBookCoverUrl = relatedBookCoverUrl; }

    public String getRelationType() { return relationType; }
    public void setRelationType(String relationType) { this.relationType = relationType; }
}
