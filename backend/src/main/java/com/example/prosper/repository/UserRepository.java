package com.example.prosper.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.prosper.model.User;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    Optional<User> findByNickname(String nickname);
    
    Optional<User> findByEmail(String email);
    
    Optional<User> findById(Long id);
}