package com.example.prosper.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.Book;

@Repository
public interface BookRepository extends JpaRepository<Book, Long> { }
