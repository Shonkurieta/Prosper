package com.example.prosper.model;

import jakarta.persistence.*;

@Entity
@Table(name = "related_books")
public class RelatedBook {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "book_id", nullable = false)
    private Book book;

    @ManyToOne
    @JoinColumn(name = "related_book_id", nullable = false)
    private Book relatedBook;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RelationType relationType;

    public enum RelationType {
        SEQUEL, PREQUEL, SIDE_STORY
    }

    public RelatedBook() {}

    public RelatedBook(Book book, Book relatedBook, RelationType relationType) {
        this.book = book;
        this.relatedBook = relatedBook;
        this.relationType = relationType;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Book getBook() { return book; }
    public void setBook(Book book) { this.book = book; }

    public Book getRelatedBook() { return relatedBook; }
    public void setRelatedBook(Book relatedBook) { this.relatedBook = relatedBook; }

    public RelationType getRelationType() { return relationType; }
    public void setRelationType(RelationType relationType) { this.relationType = relationType; }
}
