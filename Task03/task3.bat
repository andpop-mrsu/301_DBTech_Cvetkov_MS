#!/bin/bash
chcp 65001

sqlite3 movies_rating.db < db_init.sql

echo "1. Составить список фильмов, имеющих хотя бы одну оценку. Список фильмов отсортировать по году выпуска и по названиям. В списке оставить первые 10 фильмов."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT DISTINCT m.title, m.year FROM movies m INNER JOIN ratings r ON r.movie_id = m.id ORDER BY (m.year IS NULL), m.year, m.title LIMIT 10;"
echo " "

echo "2. Вывести список пользователей, фамилии которых начинаются на букву A. Список отсортировать по дате регистрации. Оставить первых 5 пользователей."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT id, name, register_date FROM users WHERE UPPER(TRIM(SUBSTR(name, INSTR(name, ' ') + 1, LENGTH(name))) LIKE 'A%') ORDER BY register_date LIMIT 5;"
echo " "

echo "3. Вывести рейтинги в читаемом формате: имя и фамилия эксперта, название фильма, год выпуска, оценка и дата оценки."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT u.name AS expert, m.title AS movie, m.year, r.rating, DATE(r.timestamp, 'unixepoch') AS rating_date FROM ratings r JOIN users u ON u.id = r.user_id JOIN movies m ON m.id = r.movie_id ORDER BY u.name, m.title, r.rating LIMIT 50;"
echo " "

echo "4. Вывести фильмы с тегами пользователей. Сортировать по году, названию фильма и тегу. Оставить первые 40 записей."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT m.title, m.year, t.tag FROM tags t JOIN movies m ON m.id = t.movie_id ORDER BY m.year, m.title, t.tag LIMIT 40;"
echo " "

echo "5. Вывести все фильмы последнего года выпуска в базе данных."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT title, year FROM movies WHERE year = (SELECT MAX(year) FROM movies) ORDER BY title;"
echo " "

echo "6. Найти драмы после 2005 года, которые женщины оценили не ниже 4.5. Вывести название, год и количество таких оценок."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT m.title, m.year, COUNT(*) AS high_ratings FROM movies m JOIN ratings r ON r.movie_id = m.id JOIN users u ON u.id = r.user_id WHERE m.year > 2005 AND m.genres LIKE '%Drama%' AND u.gender = 'female' AND r.rating >= 4.5 GROUP BY m.id, m.title, m.year ORDER BY m.year, m.title;"
echo " "

echo "7. Вывести количество пользователей, зарегистрировавшихся в каждом году, и определить годы с максимальным и минимальным количеством регистраций."
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH yearly AS (SELECT SUBSTR(register_date, 1, 4) AS year, COUNT(*) AS user_count FROM users WHERE register_date IS NOT NULL GROUP BY SUBSTR(register_date, 1, 4)) SELECT year, user_count, CASE WHEN user_count = (SELECT MAX(user_count) FROM yearly) THEN 'MAX' WHEN user_count = (SELECT MIN(user_count) FROM yearly) THEN 'MIN' ELSE '' END AS status FROM yearly ORDER BY year;"
