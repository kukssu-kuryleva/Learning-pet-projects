--Аналитические запросы к БД

--Простые запросы(на выборку из таблиц)

--1.Получить список выпускников, находящихся в поиске работы, в алфавитном порядке по фамилии и имени
SELECT first_name, last_name, phone, employment_status
FROM graduates
WHERE employment_status = 'looking for job'
ORDER BY last_name, first_name;

--2.Получить список наставников с опытом работы в программе более 3 лет в порядке возрастания стажа
SELECT first_name, last_name, profession, work_in_programm_years
FROM mentors
WHERE work_in_programm_years > 3
ORDER BY work_in_programm_years;

--3.Получить список активных пар наставник-выпускник в порядке их идентификатора
SELECT pairs_id, graduate_id, mentor_id, status
FROM pairs
WHERE status = 'active'
ORDER BY pairs_id;

--4. Получить список всех встреч, запланированных на 2025 год, с продолжительностью более 60 минут, отсортированных по дате встречи
SELECT meeting_id, pairs_id, meeting_date, duration, notes
FROM meetings
WHERE EXTRACT(YEAR FROM meeting_date) = 2025 AND duration > 60
ORDER BY meeting_date;

--Средние запросы(со склейкой)

--5.Выбрать имена и фамилии всех выпускников, которые находятся в активных парах с наставниками, и профессию их наставника
SELECT g.first_name AS graduate_name, g.last_name AS graduate_surname, m.first_name AS mentor_name, m.last_name AS mentor_surname, m.profession
FROM graduates g
JOIN pairs p ON g.graduate_id = p.graduate_id
JOIN mentors m ON p.mentor_id = m.mentor_id
WHERE p.status = 'active';

--6.Выбрать каждую категорию навыков и количество выпускников, которым нужны навыки из этой категории
SELECT sl.category, COUNT(DISTINCT gp.graduate_id) AS graduates_count
FROM skills_list sl
JOIN graduate_problems gp ON sl.skill_id = gp.skill_id
GROUP BY sl.category
ORDER BY graduates_count DESC;

--7.Выбрать каждого наставника и количество активных пар, в которых он участвует, если у него есть хотя бы одна активная пара 
SELECT m.mentor_id, m.first_name, m.last_name, COUNT(p.pairs_id) AS active_pairs_count
FROM mentors m
JOIN pairs p ON m.mentor_id = p.mentor_id
WHERE p.status = 'active'
GROUP BY m.mentor_id, m.first_name, m.last_name
ORDER BY active_pairs_count DESC;

--Сложные запросы(с избирательными join)

--8. Найти наставников, у которых средняя оценка от выпускников выше 9, и вывести их имена, профессии и количество проведенных встреч
SELECT m.mentor_id, m.first_name, m.last_name, m.profession, COUNT(me.meeting_id) AS meetings_count, AVG(me.graduate_rating) AS avg_graduate_rating
FROM mentors m
JOIN pairs p ON m.mentor_id = p.mentor_id
JOIN meetings me ON p.pairs_id = me.pairs_id
WHERE me.graduate_rating IS NOT NULL
GROUP BY m.mentor_id, m.first_name, m.last_name, m.profession
HAVING AVG(me.graduate_rating) > 9
ORDER BY avg_graduate_rating DESC;

--9.Вывести рейтинг наставников по средней оценке от выпускников на встречах, но только для тех наставников, у которых было не менее 2 встреч с оценками в 2024 году
SELECT m.mentor_id, m.first_name, m.last_name, COUNT(me.meeting_id) AS meetings_2024, ROUND(AVG(me.graduate_rating), 2) AS avg_rating
FROM mentors m
JOIN pairs p ON m.mentor_id = p.mentor_id
JOIN meetings me ON p.pairs_id = me.pairs_id
WHERE EXTRACT(YEAR FROM me.meeting_date) = 2024 AND me.graduate_rating IS NOT NULL
GROUP BY m.mentor_id, m.first_name, m.last_name
HAVING COUNT(me.meeting_id) >= 2
ORDER BY avg_rating DESC;

--10.Определить наставника с наибольшим количеством встреч в 2024 году, вывести его имя, фамилию, профессию и количество проведенных встреч 
SELECT m.mentor_id, m.first_name, m.last_name, m.profession, COUNT(me.meeting_id) AS meetings_count
FROM mentors m
JOIN pairs p ON m.mentor_id = p.mentor_id
JOIN meetings me ON p.pairs_id = me.pairs_id
WHERE EXTRACT(YEAR FROM me.meeting_date) = 2024
GROUP BY m.mentor_id, m.first_name, m.last_name, m.profession
ORDER BY meetings_count DESC
LIMIT 1;

--11.Нумерация встречи каждого наставника по порядку от самой первой до последней
SELECT m.mentor_id, m.first_name, m.last_name, me.meeting_date, me.mentor_rating,
    ROW_NUMBER() OVER (PARTITION BY m.mentor_id ORDER BY me.meeting_date) AS meeting_number
FROM mentors m
JOIN pairs p ON m.mentor_id = p.mentor_id
JOIN meetings me ON p.pairs_id = me.pairs_id
ORDER BY m.mentor_id, me.meeting_date;
