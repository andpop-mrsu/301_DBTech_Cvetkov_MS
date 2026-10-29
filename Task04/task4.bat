#!/bin/bash
chcp 65001

cd "$(dirname "$0")"

rm -f movies_rating.db
sqlite3 movies_rating.db < db_init.sql

echo "1. Найти пары пользователей, оценивших один и тот же фильм. Вывести первые 100 записей."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -header "
SELECT u1.name AS user1, u2.name AS user2, m.title AS movie
FROM ratings r1
JOIN ratings r2 ON r1.movie_id = r2.movie_id AND r1.user_id < r2.user_id
JOIN users u1 ON u1.id = r1.user_id
JOIN users u2 ON u2.id = r2.user_id
JOIN movies m ON m.id = r1.movie_id
ORDER BY m.title, user1, user2
LIMIT 100;
"
echo " "

echo "2. Найти 10 самых старых оценок от разных пользователей."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -header "
SELECT m.title AS movie, u.name AS user, r.rating,
       date(r.timestamp, 'unixepoch') AS review_date
FROM ratings r
JOIN movies m ON m.id = r.movie_id
JOIN users u ON u.id = r.user_id
ORDER BY r.timestamp ASC, r.id ASC
LIMIT 10;
"
echo " "

echo "3. Вывести фильмы с максимальным и минимальным средним рейтингом."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -header "
WITH averages AS (
    SELECT m.id, m.title, m.year, AVG(r.rating) AS avg_rating
    FROM movies m
    JOIN ratings r ON r.movie_id = m.id
    GROUP BY m.id, m.title, m.year
),
extremes AS (
    SELECT MAX(avg_rating) AS max_rating, MIN(avg_rating) AS min_rating
    FROM averages
)
SELECT a.title AS movie, a.year, ROUND(a.avg_rating, 3) AS avg_rating,
       CASE
           WHEN a.avg_rating = e.max_rating THEN 'Да'
           ELSE 'Нет'
       END AS 'Рекомендуем'
FROM averages a CROSS JOIN extremes e
WHERE a.avg_rating = e.max_rating OR a.avg_rating = e.min_rating
ORDER BY a.year, a.title;
"
echo " "

echo "4. Количество и средняя оценка фильмов от пользователей-мужчин за 2011–2014 годы."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -header "
SELECT COUNT(*) AS ratings_count, ROUND(AVG(r.rating), 3) AS average_rating
FROM ratings r
JOIN users u ON u.id = r.user_id
WHERE u.gender = 'male'
  AND date(r.timestamp, 'unixepoch') >= '2011-01-01'
  AND date(r.timestamp, 'unixepoch') < '2015-01-01';
"
echo " "

echo "5. Средняя оценка и количество пользователей для каждого фильма. Первые 20 записей."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -header "
SELECT m.title AS movie, m.year,
       ROUND(AVG(r.rating), 3) AS avg_rating,
       COUNT(DISTINCT r.user_id) AS users_count
FROM movies m
JOIN ratings r ON r.movie_id = m.id
GROUP BY m.id, m.title, m.year
ORDER BY m.year, m.title
LIMIT 20;
"
echo " "

echo "6. Найти самый распространённый жанр и количество фильмов в нём."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -header "
WITH RECURSIVE genre_split(movie_id, rest, genre) AS (
    SELECT id, genres || '|', ''
    FROM movies
    WHERE genres IS NOT NULL AND genres <> ''
    UNION ALL
    SELECT movie_id,
           substr(rest, instr(rest, '|') + 1),
           substr(rest, 1, instr(rest, '|') - 1)
    FROM genre_split
    WHERE rest <> ''
),
genre_counts AS (
    SELECT genre, COUNT(DISTINCT movie_id) AS movie_count
    FROM genre_split
    WHERE genre <> ''
    GROUP BY genre
)
SELECT genre, movie_count
FROM genre_counts
WHERE movie_count = (SELECT MAX(movie_count) FROM genre_counts)
ORDER BY genre;
"
echo " "

echo "7. Десять последних зарегистрированных пользователей: Фамилия Имя|Дата регистрации."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -separator '|' "
SELECT
    substr(name, instr(name, ' ') + 1) || ' ' ||
    substr(name, 1, instr(name, ' ') - 1) AS 'Фамилия Имя',
    register_date
FROM users
WHERE register_date IS NOT NULL
ORDER BY register_date DESC, id DESC
LIMIT 10;
"
echo " "

echo "8. День недели дня рождения в каждом году (временно указано 01-01; замените на свой месяц и день)."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -header "
WITH RECURSIVE years(y) AS (
    SELECT CAST(strftime('%Y', MIN(register_date)) AS INTEGER)
    FROM users
    UNION ALL
    SELECT y + 1 FROM years WHERE y < CAST(strftime('%Y', 'now') AS INTEGER)
)
SELECT y AS year,
       date(printf('%04d-01-01', y), '+0 days') AS birthday_date,
       CASE strftime('%w', printf('%04d-01-01', y))
           WHEN '0' THEN 'Воскресенье'
           WHEN '1' THEN 'Понедельник'
           WHEN '2' THEN 'Вторник'
           WHEN '3' THEN 'Среда'
           WHEN '4' THEN 'Четверг'
           WHEN '5' THEN 'Пятница'
           WHEN '6' THEN 'Суббота'
       END AS weekday
FROM years
ORDER BY y;
"
echo " "
