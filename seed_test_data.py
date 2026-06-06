#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Seed script: 200 users + ratings + reviews + comments
"""
import psycopg2
import psycopg2.extras
import random
from datetime import datetime, timedelta

random.seed(42)

conn = psycopg2.connect(
    host="localhost", port=5433, dbname="prosper",
    user="postgres", password="12345",
)
cur = conn.cursor()

# ─── текущие max id ────────────────────────────────────────────────────────────
def max_id(table):
    cur.execute(f"SELECT COALESCE(MAX(id), 0) FROM {table}")
    return cur.fetchone()[0]

# ─── все книги ────────────────────────────────────────────────────────────────
cur.execute("SELECT id FROM books ORDER BY id")
book_ids = [r[0] for r in cur.fetchall()]
print(f"Книг в БД: {len(book_ids)}")

# ══════════════════════════════════════════════════════════════════════════════
# ШАГ 2 — 200 пользователей
# ══════════════════════════════════════════════════════════════════════════════
ADJECTIVES = [
    "dark", "night", "silver", "wild", "lost", "brave", "cold", "swift",
    "iron", "storm", "red", "black", "white", "golden", "silent", "shadow",
    "magic", "epic", "cool", "true", "deep", "fast", "lunar", "solar",
    "frozen", "burning", "royal", "sacred", "hidden", "ancient",
]
NOUNS = [
    "reader", "wolf", "knight", "hunter", "hero", "ranger", "mage",
    "blade", "storm", "falcon", "raven", "fox", "dragon", "tiger",
    "phoenix", "ghost", "legend", "pilgrim", "wanderer", "dreamer",
    "scholar", "archer", "monk", "sage", "oracle", "seeker", "guardian",
    "warrior", "prophet", "scribe",
]
DOMAINS = ["gmail.com", "mail.ru", "yandex.ru", "gmail.com", "gmail.com"]

used_nicknames = set()
used_emails = set()

uid_start = max_id("users") + 1
users = []

while len(users) < 200:
    adj  = random.choice(ADJECTIVES)
    noun = random.choice(NOUNS)
    num  = random.randint(1, 999)
    nick = f"{adj}_{noun}_{num}"
    if nick in used_nicknames:
        continue
    used_nicknames.add(nick)

    domain = random.choice(DOMAINS)
    email  = f"{nick}@{domain}"
    if email in used_emails:
        continue
    used_emails.add(email)

    uid = uid_start + len(users)
    users.append((
        uid,
        email,
        "$2b$12$placeholder_hash_for_test_data",
        "USER",
        nick,
        None,    # avatar_url
        False,   # is_banned
    ))

cur.executemany(
    """INSERT INTO users (id, email, password, role, nickname, avatar_url, is_banned)
       VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING""",
    users,
)
conn.commit()
user_ids = [u[0] for u in users]
print(f"Пользователей добавлено: {cur.rowcount} (из {len(users)})")

# ══════════════════════════════════════════════════════════════════════════════
# ШАГ 3 — оценки (book_ratings)
# ══════════════════════════════════════════════════════════════════════════════
# Взвешенное распределение: больше высоких оценок
RATING_WEIGHTS = [1,1,1,2,3,5,8,14,18,12]   # веса для 1..10

def rand_rating():
    return random.choices(range(1, 11), weights=RATING_WEIGHTS, k=1)[0]

def rand_date(days_back=730):
    return datetime.now() - timedelta(
        days=random.randint(0, days_back),
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59),
    )

br_start = max_id("book_ratings") + 1
ratings_rows = []

for uid in user_ids:
    # каждый пользователь оценивает 30-80% книг
    fraction = random.uniform(0.30, 0.80)
    sampled  = random.sample(book_ids, k=int(len(book_ids) * fraction))
    for bid in sampled:
        ratings_rows.append((
            br_start + len(ratings_rows),
            rand_date(),
            rand_rating(),
            bid,
            uid,
        ))

psycopg2.extras.execute_values(
    cur,
    """INSERT INTO book_ratings (id, created_at, rating, book_id, user_id)
       VALUES %s ON CONFLICT DO NOTHING""",
    ratings_rows,
    page_size=500,
)
conn.commit()
ratings_inserted = cur.rowcount
print(f"Оценок добавлено: {ratings_inserted} (из {len(ratings_rows)})")

# ══════════════════════════════════════════════════════════════════════════════
# ШАГ 4 — рецензии (reviews)
# ══════════════════════════════════════════════════════════════════════════════
REVIEW_TEMPLATES = [
    # позитивные
    ("positive", "Отличная новелла, читал не отрываясь! Персонажи живые, сюжет держит в напряжении до самого конца."),
    ("positive", "Давно искал что-то подобное. Главный герой вызывает искреннее сочувствие, а развитие сюжета удивляет."),
    ("positive", "Прочитал за два дня, не мог оторваться. Рекомендую всем любителям жанра."),
    ("positive", "Невероятно атмосферно! Мир проработан до мелочей, хочется читать ещё и ещё."),
    ("positive", "Одна из лучших новелл, что я читал за последний год. Автор молодец."),
    ("positive", "Перечитываю уже второй раз — каждый раз замечаю новые детали. Шедевр."),
    ("positive", "Главная героиня — настоящий персонаж, а не картонная фигура. Очень понравилось!"),
    ("positive", "Сюжет развивается стремительно, скучных глав практически нет. 10/10."),
    ("positive", "Хорошо проработанный мир и интересные второстепенные персонажи. Читается легко."),
    ("positive", "Финал оказался неожиданным — приятно удивлён. Буду ждать продолжения."),
    # нейтральные
    ("neutral", "В целом неплохо. Местами затянуто, но общее впечатление положительное."),
    ("neutral", "Стандартная история для жанра, но выполнена добротно. Скоротать вечер — самое то."),
    ("neutral", "Начало затянутое, зато потом разгоняется. Можно читать."),
    ("neutral", "Средненько. Есть сильные моменты, но и провальные главы тоже встречаются."),
    ("neutral", "Неплохая новелла, хотя ожидал чего-то большего после отзывов."),
    ("neutral", "Читал без особого восторга, но и без разочарования. Нормально."),
    ("neutral", "Для своего жанра — твёрдая четвёрка. Любителям зайдёт."),
    ("neutral", "Перевод приличный, сюжет понятный. Читается легко, но ничего особенного."),
    ("neutral", "Хорошая работа переводчиков, сам текст — на любителя."),
    ("neutral", "Пройдёт ещё немного времени, и забуду о чём это. Не плохо, но и не запоминается."),
    # критические
    ("negative", "Слишком много воды в начале. Терпения хватило только до половины."),
    ("negative", "Главный герой раздражает своей пассивностью. Сюжет топчется на месте."),
    ("negative", "Ожидал большего. Завязка интересная, а дальше всё скатилось в шаблон."),
    ("negative", "Слишком предсказуемо. Каждый поворот угадывается за три главы вперёд."),
    ("negative", "Диалоги неестественные, персонажи картонные. Не моё, увы."),
    ("negative", "Начало многообещающее, но автор явно не знал, куда ведёт историю."),
    ("negative", "Для любителей жанра, возможно, зайдёт. Мне лично — нет."),
    ("negative", "Слишком много ненужных отступлений. Суть тонет в описаниях."),
    ("negative", "Разочарован. После таких оценок ждал чего-то выдающегося."),
    ("negative", "Бросил на 40-й главе. Не моё."),
]

SENTIMENTS = [s for s, _ in REVIEW_TEMPLATES]

rev_start = max_id("reviews") + 1
reviews_rows = []
used_review_pairs = set()   # (user_id, book_id) — один отзыв на книгу

for bid in book_ids:
    count = random.randint(3, 8)
    chosen_users = random.sample(user_ids, k=min(count, len(user_ids)))
    for uid in chosen_users:
        if (uid, bid) in used_review_pairs:
            continue
        used_review_pairs.add((uid, bid))

        sentiment, text = random.choice(REVIEW_TEMPLATES)
        rating = rand_rating()
        if sentiment == "positive" and rating < 6:
            rating = random.randint(6, 10)
        elif sentiment == "negative" and rating > 5:
            rating = random.randint(1, 5)

        reviews_rows.append((
            rev_start + len(reviews_rows),
            uid,
            bid,
            "review",       # type
            rating,
            sentiment,
            text,
            rand_date(500), # created_at
            None,           # parent_id
            None,           # title
        ))

psycopg2.extras.execute_values(
    cur,
    """INSERT INTO reviews (id, user_id, book_id, type, rating, sentiment,
                             content, created_at, parent_id, title)
       VALUES %s ON CONFLICT DO NOTHING""",
    reviews_rows,
    page_size=500,
)
conn.commit()
reviews_inserted = cur.rowcount
print(f"Рецензий добавлено: {reviews_inserted} (из {len(reviews_rows)})")

# ══════════════════════════════════════════════════════════════════════════════
# ШАГ 5 — комментарии (comments)
# ══════════════════════════════════════════════════════════════════════════════
COMMENT_TEMPLATES = [
    "Обожаю эту новеллу, перечитываю уже второй раз!",
    "Когда выйдет следующая глава? Не могу дождаться!",
    "Главная героиня — лучший персонаж во всей новелле.",
    "Спасибо переводчикам за такую быструю работу!",
    "Этот момент в середине просто разорвал мне сердце...",
    "Долго не мог начать читать, а теперь не могу остановиться.",
    "Кто-нибудь знает, продолжается ли оригинал?",
    "Эта глава была просто шедевральной!",
    "Читал всю ночь, не заметил как рассвело.",
    "Рекомендую всем друзьям — они тоже в восторге.",
    "Злодей в этой истории получился неожиданно глубоким.",
    "Хочу больше таких новелл! Где найти похожее?",
    "Перечитал три раза — каждый раз по-новому.",
    "Финальная арка просто взорвала мозг.",
    "Тихо страдаю в ожидании новых глав.",
    "Главный герой поначалу раздражал, но потом стал любимым.",
    "Такие новеллы и делают этот сайт лучшим!",
    "Плакал на 47-й главе, не стыжусь признаться.",
    "Вот это поворот! Не ожидал такого от автора.",
    "Ставлю 10 из 10 только за атмосферу.",
    "Читается на одном дыхании — редкость в последнее время.",
    "Перевод топовый, спасибо команде!",
    "Эта история заставила меня пересмотреть своё отношение к жанру.",
    "Боюсь, что конец расстроит, но всё равно читаю.",
    "Давно так не переживал за персонажей.",
    "Уже жду экранизацию :)",
    "Автор явно знает, как держать читателя в напряжении.",
    "Не могу выбрать любимую главу — все хороши!",
    "Пришёл за одной главой, остался на три часа.",
    "Надеюсь, переводчики не бросят эту новеллу!",
    "Третий раз перечитываю и снова плачу в конце.",
    "Такие истории напоминают, зачем вообще читать.",
    "Подсадил на эту новеллу половину офиса.",
    "Главная пара — огонь, просто огонь!",
    "Интересно, задумывал ли автор такую концовку изначально?",
    "Добавил в избранное после первой же главы.",
    "Читаю вслух собаке, она тоже в восторге.",
    "Это лучшее, что я читал за этот год.",
    "Сижу и жду уведомления о новой главе как маньяк.",
    "Всем советую начать именно с этой новеллы!",
    "Мир здесь прописан лучше, чем во многих изданных книгах.",
    "Каждая глава заканчивается клиффхэнгером, издевательство!",
    "Боковые персонажи получились живее главных — это редкость.",
    "Уже неделю хожу с этими мыслями в голове.",
    "Хотел прочитать одну главу перед сном... прочитал двадцать.",
    "Спасибо за эту новеллу, она именно то, что мне было нужно.",
    "Просто оставлю здесь свои слёзы.",
    "Когда думал, что понял куда идёт сюжет — автор снова удивил.",
    "Несправедливо мало оценок у такой хорошей новеллы.",
    "Уже пишу отзыв другу в телеграм пока читаю.",
]

# Получаем словарь user_id -> nickname для reply_to_nickname
cur.execute("SELECT id, nickname FROM users WHERE id = ANY(%s)", (user_ids,))
uid_to_nick = {r[0]: r[1] for r in cur.fetchall()}

cm_start = max_id("comments") + 1
comments_rows = []

for bid in book_ids:
    count = random.randint(5, 15)
    chosen = random.sample(user_ids, k=min(count, len(user_ids)))
    for uid in chosen:
        text = random.choice(COMMENT_TEMPLATES)
        created = rand_date(400)
        comments_rows.append((
            cm_start + len(comments_rows),
            uid,
            bid,
            None,           # chapter_id
            None,           # parent_id
            text,
            created,
            None,           # reply_to_nickname
        ))

psycopg2.extras.execute_values(
    cur,
    """INSERT INTO comments (id, user_id, book_id, chapter_id, parent_id,
                              content, created_at, reply_to_nickname)
       VALUES %s ON CONFLICT DO NOTHING""",
    comments_rows,
    page_size=500,
)
conn.commit()
comments_inserted = cur.rowcount
print(f"Комментариев добавлено: {comments_inserted} (из {len(comments_rows)})")

# ══════════════════════════════════════════════════════════════════════════════
# ИТОГ
# ══════════════════════════════════════════════════════════════════════════════
cur.execute("SELECT COUNT(*) FROM users")
total_users = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM book_ratings")
total_ratings = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM reviews")
total_reviews = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM comments")
total_comments = cur.fetchone()[0]

print("\n" + "="*55)
print("ИТОГ (всего в БД после заполнения):")
print(f"  Пользователей : {total_users}")
print(f"  Оценок        : {total_ratings}")
print(f"  Рецензий      : {total_reviews}")
print(f"  Комментариев  : {total_comments}")
print("="*55)

cur.close()
conn.close()
