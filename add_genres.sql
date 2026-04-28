CREATE TABLE IF NOT EXISTS public.genres (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.book_genres (
    book_id BIGINT NOT NULL,
    genre_id BIGINT NOT NULL,
    PRIMARY KEY (book_id, genre_id),
    CONSTRAINT fk_book
        FOREIGN KEY (book_id)
        REFERENCES public.books (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_genre
        FOREIGN KEY (genre_id)
        REFERENCES public.genres (id)
        ON DELETE CASCADE
);

INSERT INTO public.genres (name) VALUES
    ('Боевик'),
    ('Боевые искусства'),
    ('Гарем'),
    ('Героическое фэнтези'),
    ('Детектив'),
    ('Драма'),
    ('Исекай'),
    ('Комедия'),
    ('Магия'),
    ('Меха'),
    ('Мистика'),
    ('Научная фантастика'),
    ('Повседневность'),
    ('Постапокалиптика'),
    ('Приключения'),
    ('Психология'),
    ('Романтика'),
    ('Сверхъестественное'),
    ('Сэйнэн'),
    ('Сёдзё'),
    ('Сёнэн'),
    ('Трагедия'),
    ('Триллер'),
    ('Ужасы'),
    ('Фантастика'),
    ('Фэнтези'),
    ('Школа')
ON CONFLICT (name) DO NOTHING;
