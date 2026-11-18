#!/bin/bash
chcp 65001 >/dev/null 2>&1 || true
set -e

sqlite3 movies_rating.db < db_init.sql

echo "1. Десять фильмов с наибольшим средним рейтингом"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH movie_avg AS (
    SELECT m.id, m.title, m.year, AVG(r.rating) AS avg_rating
    FROM movies AS m
    LEFT JOIN ratings AS r ON r.movie_id = m.id
    GROUP BY m.id
),
ranked AS (
    SELECT title, year, ROUND(avg_rating, 2) AS avg_rating,
           RANK() OVER (ORDER BY avg_rating DESC) AS rank_by_avg_rating
    FROM movie_avg
    WHERE avg_rating IS NOT NULL
)
SELECT title, year, avg_rating, rank_by_avg_rating
FROM ranked
ORDER BY rank_by_avg_rating, title
LIMIT 10;
"
echo " "

echo "2. Средний рейтинг и ранг каждого жанра"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE split_genres(movie_id, genre, rest) AS (
    SELECT id, '', COALESCE(genres, '') || '|'
    FROM movies
    UNION ALL
    SELECT movie_id,
           SUBSTR(rest, 1, INSTR(rest, '|') - 1),
           SUBSTR(rest, INSTR(rest, '|') + 1)
    FROM split_genres
    WHERE rest <> ''
),
movie_avg AS (
    SELECT movie_id, AVG(rating) AS avg_rating
    FROM ratings
    GROUP BY movie_id
),
genre_avg AS (
    SELECT s.genre, AVG(a.avg_rating) AS avg_rating
    FROM split_genres AS s
    JOIN movie_avg AS a ON a.movie_id = s.movie_id
    WHERE s.genre <> ''
    GROUP BY s.genre
)
SELECT genre, ROUND(avg_rating, 2) AS avg_rating,
       RANK() OVER (ORDER BY avg_rating DESC) AS genre_rank
FROM genre_avg
ORDER BY genre_rank, genre;
"
echo " "

echo "3. Количество фильмов каждого жанра"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE split_genres(movie_id, genre, rest) AS (
    SELECT id, '', COALESCE(genres, '') || '|'
    FROM movies
    UNION ALL
    SELECT movie_id,
           SUBSTR(rest, 1, INSTR(rest, '|') - 1),
           SUBSTR(rest, INSTR(rest, '|') + 1)
    FROM split_genres
    WHERE rest <> ''
)
SELECT genre, COUNT(DISTINCT movie_id) AS movie_count
FROM split_genres
WHERE genre <> ''
GROUP BY genre
ORDER BY movie_count DESC, genre;
"
echo " "

echo "4. Количество тегов и доля каждого жанра в общем числе тегов"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH RECURSIVE split_genres(movie_id, genre, rest) AS (
    SELECT id, '', COALESCE(genres, '') || '|'
    FROM movies
    UNION ALL
    SELECT movie_id,
           SUBSTR(rest, 1, INSTR(rest, '|') - 1),
           SUBSTR(rest, INSTR(rest, '|') + 1)
    FROM split_genres
    WHERE rest <> ''
),
genre_tags AS (
    SELECT s.genre, COUNT(t.id) AS tag_count
    FROM split_genres AS s
    JOIN tags AS t ON t.movie_id = s.movie_id
    WHERE s.genre <> ''
    GROUP BY s.genre
)
SELECT genre, tag_count,
       ROUND(100.0 * tag_count / NULLIF((SELECT COUNT(*) FROM tags), 0), 2)
           AS tag_share
FROM genre_tags
ORDER BY tag_count DESC, genre;
"
echo " "

echo "5. Десять пользователей с наибольшим числом оценок"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
SELECT user_id,
       COUNT(*) AS rating_count,
       ROUND(AVG(rating), 2) AS avg_rating,
       DATETIME(MIN(timestamp), 'unixepoch') AS first_rating_date,
       DATETIME(MAX(timestamp), 'unixepoch') AS last_rating_date
FROM ratings
GROUP BY user_id
ORDER BY rating_count DESC, user_id
LIMIT 10;
"
echo " "

echo "6. Категория поведения каждого пользователя"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH rating_counts AS (
    SELECT user_id, COUNT(*) AS rating_count
    FROM ratings
    GROUP BY user_id
),
tag_counts AS (
    SELECT user_id, COUNT(*) AS tag_count
    FROM tags
    GROUP BY user_id
)
SELECT u.id AS user_id,
       COALESCE(r.rating_count, 0) AS rating_count,
       COALESCE(t.tag_count, 0) AS tag_count,
       CASE
           WHEN COALESCE(r.rating_count, 0) >= 10
            AND COALESCE(t.tag_count, 0) >= 10 THEN 'Активные'
           WHEN COALESCE(r.rating_count, 0) < 5
            AND COALESCE(t.tag_count, 0) < 5 THEN 'Пассивные'
           WHEN COALESCE(t.tag_count, 0) > COALESCE(r.rating_count, 0)
                THEN 'Комментаторы'
           WHEN COALESCE(r.rating_count, 0) > COALESCE(t.tag_count, 0)
                THEN 'Оценщики'
           ELSE 'Без категории'
       END AS behavior_category
FROM users AS u
LEFT JOIN rating_counts AS r ON r.user_id = u.id
LEFT JOIN tag_counts AS t ON t.user_id = u.id
ORDER BY u.id;
"
echo " "

echo "7. Последний оценённый фильм каждого пользователя"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "
WITH last_ratings AS (
    SELECT user_id, movie_id, timestamp,
           ROW_NUMBER() OVER (
               PARTITION BY user_id
               ORDER BY timestamp DESC, id DESC
           ) AS row_num
    FROM ratings
)
SELECT u.id AS user_id,
       u.name,
       m.title AS last_rated_movie_title,
       lr.timestamp AS last_rating_timestamp
FROM users AS u
LEFT JOIN last_ratings AS lr
       ON lr.user_id = u.id AND lr.row_num = 1
LEFT JOIN movies AS m ON m.id = lr.movie_id
ORDER BY u.id;
"
