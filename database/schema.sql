--Проектирование и реализация базы данных для системы менторской поддержки выпускников детских домов

--DROP DATABASE IF EXISTS "k.kuryleva";

--CREATE DATABASE "k.kuryleva"
--  WITH ENCODING 'UTF8';

--\connect "k.kuryleva";

-- Таблица 1 - данные о выпускниках детских домов, включая личные данные (first_name, last_name, birth_date, gender, phone), уровень образования (education_level) и статус занятости (employment_status)

CREATE TABLE graduates (
graduate_id integer PRIMARY KEY, 
first_name varchar(50) NOT NULL,
last_name varchar(50) NOT NULL,
birth_date date NOT NULL,
gender char(1),
phone varchar(15) NOT NULL,
education_level varchar(30),
employment_status varchar(30),

CHECK (employment_status IN ('studying', 'working', 'looking for job', 'not working')),
CHECK (gender IN ('M', 'F') OR gender IS NULL),
CHECK (birth_date BETWEEN '1990-01-01' AND '2010-12-31'),
CHECK (education_level IN('school','college','university','graduated','not studying') OR education_level IS NULL)
);

-- Таблица 2 - данные о наставниках с указанием их профессии (profession) и стажа работы в программе (work_in_programm_years)

CREATE TABLE mentors (
    mentor_id integer PRIMARY KEY,
    first_name varchar(50) NOT NULL,
    last_name varchar(50) NOT NULL,
    profession varchar(100) NOT NULL,
    work_in_programm_years integer NOT NULL,
    phone varchar(15) NOT NULL,
	
	CHECK (work_in_programm_years >= 0)
);

--Таблица 3 - справочник навыков по категориям education, work, housing, communication, legal, finance

CREATE TABLE skills_list (
    skill_id integer PRIMARY KEY,
    skill_name varchar(50) NOT NULL, --название навыка
    category varchar(30) NOT NULL, --категория навыка
    description text, --вариативно описание
	
    CHECK (category IN ('education', 'work', 'housing', 'communication', 'legal', 'finance'))
);

--Таблица 4 - связь многие ко многим(выпускники - навыки), где фиксируются навыки (skill_id), которые выпускнику (graduate_id) необходимо развить

CREATE TABLE graduate_problems (
    graduate_id integer NOT NULL,
    skill_id integer NOT NULL,
	
    PRIMARY KEY (graduate_id, skill_id),
    FOREIGN KEY (graduate_id) REFERENCES graduates(graduate_id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills_list(skill_id) ON DELETE CASCADE   
);

--Таблица 5 - связь м:м, отражающая компетенции каждого наставника (mentor_id) в конкретных навыках (skill_id)

CREATE TABLE mentor_competencies (
    mentor_id integer NOT NULL,
    skill_id integer NOT NULL,
	
    PRIMARY KEY (mentor_id, skill_id),
    FOREIGN KEY (mentor_id) REFERENCES mentors(mentor_id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills_list(skill_id) ON DELETE CASCADE
);

--Таблица 6 - пары выпускник-наставник, фиксируется статус пары - 'active', 'completed successfully', 'completed early'

CREATE TABLE pairs(
    pairs_id integer,
    graduate_id integer NOT NULL,
    mentor_id integer NOT NULL,
    status varchar(40) DEFAULT 'active',

	PRIMARY KEY (pairs_id), 
	FOREIGN KEY (graduate_id) REFERENCES graduates(graduate_id) ON DELETE CASCADE,
	FOREIGN KEY (mentor_id) REFERENCES mentors(mentor_id) ON DELETE CASCADE,
	
	CHECK (status IN ('active', 'completed successfully', 'completed early'))
);

--Таблица 7 - встречи, организованные в рамках пары выпускник - наставник с указанием даты (meeting_date), продолжительности (duration), взаимных оценок (graduate_rating, mentor_rating) и заметок (notes)

CREATE TABLE meetings (
    meeting_id integer,
    pairs_id integer NOT NULL,
    meeting_date date NOT NULL,
    duration integer NOT NULL ,
	graduate_rating integer,
    mentor_rating integer,
    notes text,
	
	PRIMARY KEY (meeting_id),
	FOREIGN KEY (pairs_id) REFERENCES pairs(pairs_id) ON DELETE CASCADE,
	
	CHECK (duration > 0),
	CHECK (meeting_date >= '2020-01-01'),
	CHECK (graduate_rating BETWEEN 0 AND 10 OR graduate_rating IS NULL),
	CHECK (mentor_rating BETWEEN 0 AND 10 OR mentor_rating IS NULL)
);

CREATE EXTENSION IF NOT EXISTS btree_gist;

--Уникальность выпускника по ФИ, дате рождения и телефону
ALTER TABLE graduates
    ADD CONSTRAINT uq_graduates_identity 
    UNIQUE (first_name, last_name, birth_date, phone);

--Уникальность наставника по ФИ и телефону
ALTER TABLE mentors
    ADD CONSTRAINT uq_mentors_identity 
    UNIQUE (first_name, last_name, phone);

--Уникальность названия навыка с привязкой к категории
ALTER TABLE skills_list
    ADD CONSTRAINT uq_skills_list_name 
    UNIQUE (skill_name);

--Ограничение на одну встречу в день для пары
ALTER TABLE meetings
    ADD CONSTRAINT uq_one_meeting_in_day
    UNIQUE (pairs_id, meeting_date);

--Ограничение - у одного выпусника не может быть более 1 активной пары
ALTER TABLE pairs
    ADD CONSTRAINT exclude_duplicate_active_graduates
    EXCLUDE USING gist (
        graduate_id WITH =,
        status WITH =
    ) WHERE (status = 'active');

--Индексы

CREATE INDEX idx_pairs_status ON pairs(status); --статус пары
CREATE INDEX idx_graduate_problems_graduate ON graduate_problems(graduate_id); --все проблемы выпускника
CREATE INDEX idx_graduate_problems_skill ON graduate_problems(skill_id); --навык в таблице проблем выпусника
CREATE INDEX idx_mentor_competencies_mentor ON mentor_competencies(mentor_id); --все навыки, которые владеет наставник
CREATE INDEX idx_mentor_competencies_skill ON mentor_competencies(skill_id); --все наставники с конкретным навыком
CREATE INDEX idx_pairs_mentor ON pairs(mentor_id); --количество активных пар у наставника
CREATE INDEX idx_meetings_pair ON meetings(pairs_id); --все встречи конкретной пары

--Данные БД

--Данные о выпускниках

INSERT INTO graduates (graduate_id, first_name, last_name, birth_date, gender, phone, education_level, employment_status) VALUES
(1, 'Artem', 'Smirnov', '2010-03-15', 'M', '+7-901-123-4501', 'school', 'studying'),
(2, 'Anna', 'Kuznetsova', '2009-07-22', 'F', '+7-901-123-4502', 'school', 'studying'),
(3, 'Dmitry', 'Popov', '2008-11-08', 'M', '+7-901-123-4503', 'school', 'studying'),
(4, 'Elena', 'Vasilieva', '2010-01-30', 'F', '+7-901-123-4504', 'school', 'studying'),
(5, 'Ivan', 'Petrov', '2009-05-12', 'M', '+7-901-123-4505', 'school', 'studying'),
(6, 'Mariya', 'Ivanova', '2008-09-18', 'F', '+7-901-123-4506', 'school', 'studying'),
(7, 'Maksim', 'Mikhailov', '2007-12-03', 'M', '+7-901-123-4507', 'school', 'studying'),
(8, 'Sofiya', 'Fedorova', '2010-04-25', 'F', '+7-901-123-4508', 'school', 'studying'),
(9, 'Daniil', 'Morozov', '2009-08-14', 'M', '+7-901-123-4509', 'school', 'working'),
(10, 'Viktoriya', 'Volkova', '2008-10-28', 'F', '+7-901-123-4510', 'school', 'working'),
(11, 'Nikita', 'Alekseev', '2007-06-19', 'M', '+7-901-123-4511', 'school', 'looking for job'),
(12, 'Anastasiya', 'Lebedeva', '2007-02-14', 'F', '+7-901-123-4512', 'school', 'looking for job'),
(13, 'Egor', 'Semenov', '2006-02-19', 'M', '+7-902-234-5601', 'college', 'studying'),
(14, 'Polina', 'Pavlova', '2005-06-07', 'F', '+7-902-234-5602', 'university', 'studying'),
(15, 'Kirill', 'Grigoriev', '2004-10-10', 'M', '+7-902-234-5603', 'college', 'studying'),
(16, 'Alisa', 'Stepanova', '2006-12-21', 'F', '+7-902-234-5604', 'university', 'studying'),
(17, 'Matvey', 'Nikolaev', '2005-03-28', 'M', '+7-902-234-5605', 'college', 'studying'),
(18, 'Varvara', 'Orlova', '2004-07-15', 'F', '+7-902-234-5606', 'university', 'studying'),
(19, 'Timofey', 'Andreev', '2006-11-22', 'M', '+7-902-234-5607', 'college', 'working'),
(20, 'Kseniya', 'Makarova', '2005-01-09', 'F', '+7-902-234-5608', 'university', 'working'),
(21, 'Vladislav', 'Soloviev', '2004-04-18', 'M', '+7-902-234-5609', 'college', 'working'),
(22, 'Margarita', 'Borisova', '2005-09-30', 'F', '+7-902-234-5610', 'university', 'looking for job'),
(23, 'Gleb', 'Tikhonov', '2006-08-05', 'M', '+7-902-234-5611', 'college', 'looking for job'),
(24, 'Arina', 'Tarasova', '2005-12-14', 'F', '+7-902-234-5612', 'university', 'looking for job'),
(25, 'Vsevolod', 'Egorov', '2003-03-20', 'M', '+7-903-345-6701', 'university', 'studying'),
(26, 'Aleksandra', 'Zaytseva', '2002-07-11', 'F', '+7-903-345-6702', 'college', 'studying'),
(27, 'Sergey', 'Kovalev', '2001-11-03', 'M', '+7-903-345-6703', 'university', 'studying'),
(28, 'Darya', 'Nikitina', '2003-05-27', 'F', '+7-903-345-6704', 'graduated', 'working'),
(29, 'Pavel', 'Sidorov', '2002-09-19', 'M', '+7-903-345-6705', 'graduated', 'working'),
(30, 'Elizaveta', 'Krylova', '2001-01-12', 'F', '+7-903-345-6706', 'university', 'working'),
(31, 'Andrey', 'Maksimov', '2000-04-08', 'M', '+7-903-345-6707', 'college', 'working'),
(32, 'Yuliya', 'Belyaeva', '2002-10-25', 'F', '+7-903-345-6708', 'graduated', 'working'),
(33, 'Konstantin', 'Gerasimov', '2003-06-17', 'M', '+7-903-345-6709', 'graduated', 'looking for job'),
(34, 'Ekaterina', 'Ushakova', '2001-08-30', 'F', '+7-903-345-6710', 'university', 'looking for job'),
(35, 'Roman', 'Kulikov', '2000-12-05', 'M', '+7-903-345-6711', 'graduated', 'looking for job'),
(36, 'Valeriya', 'Larina', '2003-02-28', 'F', '+7-903-345-6712', 'college', 'looking for job'),
(37, 'Mikhail', 'Komarov', '2001-07-14', 'M', '+7-903-345-6713', 'graduated', 'not working'),
(38, 'Veronika', 'Saveleva', '2000-11-29', 'F', '+7-903-345-6714', 'university', 'not working'),
(39, 'Aleksandr', 'Timofeev', '1999-03-09', 'M', '+7-904-456-7801', 'graduated', 'working'),
(40, 'Vasilisa', 'Zhukova', '1998-08-22', 'F', '+7-904-456-7802', 'graduated', 'working'),
(41, 'Ilya', 'Voronin', '1997-12-01', 'M', '+7-904-456-7803', 'graduated', 'working'),
(42, 'Antonina', 'Shcherbakova', '1996-04-17', 'F', '+7-904-456-7804', 'university', 'working'),
(43, 'Denis', 'Bogdanov', '1999-10-08', 'M', '+7-904-456-7805', 'graduated', 'working'),
(44, 'Lyubov', 'Osipova', '1998-01-24', 'F', '+7-904-456-7806', 'college', 'working'),
(45, 'Vyacheslav', 'Dmitriev', '1997-06-15', 'M', '+7-904-456-7807', 'graduated', 'working'),
(46, 'Agata', 'Emelyanova', '1996-09-30', 'F', '+7-904-456-7808', 'university', 'working'),
(47, 'Oleg', 'Gavrilov', '1995-05-19', 'M', '+7-904-456-7809', 'graduated', 'working'),
(48, 'Karina', 'Ilyina', '1995-02-10', 'F', '+7-904-456-7810', 'graduated', 'looking for job'),
(49, 'Evgeniy', 'Fomichev', '1998-07-23', 'M', '+7-904-456-7811', 'graduated', 'looking for job'),
(50, 'Alina', 'Kiseleva', '1997-11-05', 'F', '+7-904-456-7812', 'university', 'looking for job'),
(51, 'Nikolay', 'Sokolov', '1996-03-18', 'M', '+7-904-456-7813', 'graduated', 'looking for job'),
(52, 'Taisiya', 'Guseva', '1999-08-27', 'F', '+7-904-456-7814', 'graduated', 'not working'),
(53, 'Igor', 'Maslov', '1998-12-12', 'M', '+7-904-456-7815', 'graduated', 'not working'),
(54, 'Yana', 'Koroleva', '1997-04-03', 'F', '+7-904-456-7816', 'college', 'not working'),
(55, 'Vladimir', 'Medvedev', '2002-07-04', 'M', '+7-905-567-8901', NULL, 'looking for job'),
(56, 'Oksana', 'Abramova', '1998-12-28', 'F', '+7-905-567-8902', NULL, 'working'),
(57, 'Grigoriy', 'Ermakov', '1995-05-09', 'M', '+7-905-567-8903', NULL, 'looking for job'),
(58, 'Ruslan', 'Kozlov', '2006-03-22', NULL, '+7-905-567-8904', 'college', 'looking for job'),
(59, 'Svetlana', 'Novikova', '2001-11-13', NULL, '+7-905-567-8905', 'graduated', 'working'),
(60, 'Vera', 'Frolova', '1997-08-30', NULL, '+7-905-567-8906', 'university', 'studying');

--Данные о наставниках

INSERT INTO mentors (mentor_id, first_name, last_name, profession, work_in_programm_years, phone) VALUES
(1, 'Alexey', 'Smirnov', 'Senior Software Engineer', 5, '+7-901-123-4501'),
(2, 'Elena', 'Volkova', 'DevOps Architect', 4, '+7-901-123-4502'),
(3, 'Dmitry', 'Kuznetsov', 'Data Scientist', 3, '+7-901-123-4503'),
(4, 'Olga', 'Sokolova', 'Product Manager', 6, '+7-901-123-4504'),
(5, 'Andrey', 'Popov', 'Cybersecurity Specialist', 2, '+7-901-123-4505'),
(6, 'Tatyana', 'Lebedeva', 'HR Director', 7, '+7-902-234-5606'),
(7, 'Sergey', 'Morozov', 'Career Coach', 4, '+7-902-234-5607'),
(8, 'Natalia', 'Novikova', 'Talent Acquisition Specialist', 3, '+7-902-234-5608'),
(9, 'Pavel', 'Fedorov', 'Labor Market Analyst', 2, '+7-902-234-5609'),
(10, 'Irina', 'Mikhailova', 'Financial Analyst', 5, '+7-903-345-6710'),
(11, 'Vladimir', 'Volkov', 'Tax Advisor', 6, '+7-903-345-6711'),
(12, 'Anna', 'Zaytseva', 'Investment Banker', 4, '+7-903-345-6712'),
(13, 'Mikhail', 'Solovyov', 'Corporate Lawyer', 8, '+7-904-456-7813'),
(14, 'Ekaterina', 'Vasilyeva', 'Legal Consultant', 3, '+7-904-456-7814'),
(15, 'Nikolay', 'Petrov', 'University Professor', 6, '+7-905-567-8915'),
(16, 'Svetlana', 'Ivanova', 'Academic Advisor', 4, '+7-905-567-8916'),
(17, 'Igor', 'Sidorov', 'Curriculum Developer', 2, '+7-905-567-8917'),
(18, 'Yulia', 'Kozlova', 'Marketing Director', 5, '+7-906-678-9018'),
(19, 'Roman', 'Orlov', 'Public Relations Specialist', 3, '+7-906-678-9019'),
(20, 'Maria', 'Nikolaeva', 'Content Strategist', 4, '+7-906-678-9020'),
(21, 'Viktor', 'Makarov', 'Real Estate Broker', 7, '+7-907-789-0121'),
(22, 'Oksana', 'Andreeva', 'Property Manager', 3, '+7-907-789-0122'),
(23, 'Denis', 'Tarasov', 'Clinical Psychologist', 5, '+7-908-890-1233'),
(24, 'Anastasia', 'Belova', 'Life Coach', 2, '+7-908-890-1234'),
(25, 'Evgeny', 'Grigoriev', 'Healthcare Administrator', 4, '+7-908-890-1235');

--Справочник навыков/проблем

INSERT INTO skills_list (skill_id, skill_name, category, description) VALUES
(1, 'Academic Writing', 'education', 'Writing essays, research papers, and reports'),
(2, 'Critical Thinking', 'education', 'Analyzing information objectively'),
(3, 'Exam Preparation', 'education', 'Strategies for passing tests and certifications'),
(4, 'Research Skills', 'education', 'Finding and evaluating credible sources'),
(5, 'Note Taking', 'education', 'Effective methods for lectures and self-study'),
(6, 'Presentation Skills', 'education', 'Creating and delivering academic presentations'),
(7, 'University Application', 'education', 'Process of applying to higher education institutions'),
(8, 'Resume Writing', 'work', 'Creating professional CVs tailored to specific jobs'),
(9, 'Interview Preparation', 'work', 'Behavioral and technical interview techniques'),
(10, 'Negotiation Skills', 'work', 'Salary and job offer negotiation'),
(11, 'Project Management', 'work', 'Agile, Scrum, and task prioritization'),
(12, 'Time Management', 'work', 'Planning, prioritizing tasks and meeting deadlines'),
(13, 'Professional Networking', 'work', 'Building connections and personal brand'),
(14, 'Public Speaking', 'work', 'Presenting ideas confidently to groups'),
(15, 'Finding Accommodation', 'housing', 'How to search for rental apartments'),
(16, 'Rental Agreement Review', 'housing', 'Understanding lease contracts and tenant rights'),
(17, 'Budgeting for Rent', 'housing', 'Managing housing expenses including utilities'),
(18, 'Cooking Basics', 'housing', 'Simple meal preparation and kitchen safety'),
(19, 'Roommate Management', 'housing', 'Setting expectations, splitting bills, resolving conflicts'),
(20, 'Active Listening', 'communication', 'Understanding others without interrupting'),
(21, 'Conflict Resolution', 'communication', 'Handling disagreements professionally'),
(22, 'Email Etiquette', 'communication', 'Professional written communication'),
(23, 'Assertiveness Training', 'communication', 'Expressing needs respectfully'),
(24, 'Nonverbal Communication', 'communication', 'Understanding body language and tone'),
(25, 'Employment Law Basics', 'legal', 'Understanding labor rights, contracts, workplace discrimination'),
(26, 'Tax Filing', 'legal', 'Basic knowledge of personal tax declaration'),
(27, 'Consumer Rights', 'legal', 'Understanding warranties, returns, and disputes with sellers'),
(28, 'Budget Planning', 'finance', 'Basics of personal finance management'),
(29, 'Debt Management', 'finance', 'Loans, credit cards, and repayment strategies'),
(30, 'Emergency Fund Planning', 'finance', 'Building financial cushion for unexpected expenses');

--Проблемы(запросы) выпусников

INSERT INTO graduate_problems (graduate_id, skill_id) VALUES
(1, 7), (1, 12), (1, 5),
(2, 7), (2, 2), (2, 5),
(3, 3), (3, 12), (3, 5),
(4, 7), (4, 1), (4, 20),
(5, 12), (5, 5), (5, 2),
(6, 7), (6, 6), (6, 20),
(7, 3), (7, 12), (7, 5), (7, 1),
(8, 7), (8, 6), (8, 20),
(9, 12), (9, 8), (9, 20), (9, 28),
(10, 12), (10, 9), (10, 21), (10, 28),
(11, 8), (11, 9), (11, 12), (11, 28),
(12, 8), (12, 9), (12, 13), (12, 28),
(13, 1), (13, 2), (13, 12), (13, 6),
(14, 1), (14, 6), (14, 20), (14, 28),
(15, 4), (15, 5), (15, 12), (15, 2),
(16, 1), (16, 6), (16, 14), (16, 20),
(17, 2), (17, 5), (17, 12), (17, 7),
(18, 1), (18, 6), (18, 20), (18, 28),
(19, 12), (19, 8), (19, 21), (19, 28), (19, 10),
(20, 9), (20, 13), (20, 28), (20, 20), (20, 14),
(21, 8), (21, 12), (21, 28), (21, 21), (21, 15),
(22, 8), (22, 9), (22, 13), (22, 28), (22, 21),
(23, 8), (23, 9), (23, 12), (23, 28), (23, 15),
(24, 8), (24, 9), (24, 13), (24, 28), (24, 20),
(25, 1), (25, 6), (25, 28), (25, 15),
(26, 5), (26, 12), (26, 28), (26, 21),
(27, 1), (27, 14), (27, 20), (27, 28),
(28, 10), (28, 14), (28, 21), (28, 28), (28, 25),
(29, 9), (29, 13), (29, 28), (29, 20), (29, 10),
(30, 8), (30, 12), (30, 28), (30, 21), (30, 15),
(31, 10), (31, 14), (31, 25), (31, 28), (31, 29),
(32, 9), (32, 13), (32, 21), (32, 28), (32, 11),
(33, 8), (33, 9), (33, 13), (33, 28), (33, 10),
(34, 8), (34, 9), (34, 13), (34, 28), (34, 20),
(35, 8), (35, 9), (35, 10), (35, 28), (35, 29),
(36, 8), (36, 9), (36, 13), (36, 28), (36, 21),
(37, 8), (37, 9), (37, 28), (37, 21), (37, 15),
(38, 8), (38, 9), (38, 28), (38, 20), (38, 29),
(39, 10), (39, 11), (39, 25), (39, 29), (39, 30),
(40, 14), (40, 21), (40, 25), (40, 28), (40, 29),
(41, 10), (41, 11), (41, 29), (41, 30), (41, 26),
(42, 14), (42, 21), (42, 25), (42, 28), (42, 16),
(43, 10), (43, 11), (43, 29), (43, 30), (43, 27),
(44, 21), (44, 25), (44, 28), (44, 29), (44, 16),
(45, 10), (45, 14), (45, 25), (45, 29), (45, 30),
(46, 11), (46, 21), (46, 25), (46, 28), (46, 27),
(47, 10), (47, 14), (47, 29), (47, 30), (47, 26),
(48, 8), (48, 9), (48, 10), (48, 13), (48, 28),
(49, 8), (49, 9), (49, 10), (49, 13), (49, 28),
(50, 8), (50, 9), (50, 10), (50, 13), (50, 28),
(51, 8), (51, 9), (51, 10), (51, 13), (51, 28),
(52, 8), (52, 9), (52, 28), (52, 21), (52, 15),
(53, 8), (53, 9), (53, 28), (53, 21), (53, 29),
(54, 8), (54, 9), (54, 28), (54, 15), (54, 16),
(55, 8), (55, 9), (55, 28), (55, 21),
(56, 10), (56, 14), (56, 25), (56, 28),
(57, 8), (57, 9), (57, 28), (57, 21), (57, 15),
(58, 8), (58, 9), (58, 28), (58, 15),
(59, 10), (59, 14), (59, 25), (59, 28), (59, 29),
(60, 1), (60, 6), (60, 28), (60, 20);

--Компетенции наставников

INSERT INTO mentor_competencies (mentor_id, skill_id) VALUES
(1, 2), (1, 8), (1, 9), (1, 10), (1, 11), (1, 12), (1, 14), (1, 25),
(2, 2), (2, 8), (2, 9), (2, 11), (2, 12), (2, 25), (2, 28),
(3, 1), (3, 2), (3, 4), (3, 6), (3, 14), (3, 28), (3, 30),
(4, 2), (4, 8), (4, 9), (4, 10), (4, 11), (4, 12), (4, 13), (4, 14), (4, 20), (4, 21),
(5, 2), (5, 8), (5, 9), (5, 12), (5, 25), (5, 27),
(6, 8), (6, 9), (6, 10), (6, 13), (6, 20), (6, 21), (6, 22), (6, 23), (6, 25),
(7, 8), (7, 9), (7, 10), (7, 13), (7, 14), (7, 20), (7, 21), (7, 23),
(8, 8), (8, 9), (8, 13), (8, 20), (8, 22), (8, 25),
(9, 2), (9, 8), (9, 9), (9, 13), (9, 25), (9, 28), (9, 29),
(10, 2), (10, 10), (10, 25), (10, 26), (10, 28), (10, 29), (10, 30),
(11, 25), (11, 26), (11, 27), (11, 28), (11, 29), (11, 30),
(12, 2), (12, 10), (12, 28), (12, 29), (12, 30),
(13, 2), (13, 10), (13, 16), (13, 25), (13, 26), (13, 27),
(14, 2), (14, 16), (14, 25), (14, 26), (14, 27),
(15, 1), (15, 2), (15, 3), (15, 4), (15, 5), (15, 6), (15, 7), (15, 14),
(16, 1), (16, 2), (16, 3), (16, 5), (16, 6), (16, 7), (16, 20),
(17, 1), (17, 2), (17, 3), (17, 4), (17, 5), (17, 6), (17, 7),
(18, 2), (18, 8), (18, 9), (18, 13), (18, 14), (18, 20), (18, 21), (18, 22), (18, 23),
(19, 2), (19, 13), (19, 14), (19, 20), (19, 21), (19, 22), (19, 23), (19, 24),
(20, 1), (20, 2), (20, 6), (20, 14), (20, 20), (20, 22),
(21, 10), (21, 15), (21, 16), (21, 17), (21, 19), (21, 27),
(22, 15), (22, 16), (22, 17), (22, 19), (22, 20), (22, 21),
(23, 2), (23, 20), (23, 21), (23, 22), (23, 23), (23, 24),
(24, 2), (24, 12), (24, 14), (24, 20), (24, 21), (24, 23), (24, 28),
(25, 2), (25, 8), (25, 9), (25, 11), (25, 12), (25, 20), (25, 21), (25, 25);

--Образованные пары

INSERT INTO pairs (pairs_id, graduate_id, mentor_id, status) VALUES
(1, 1, 15, 'active'),
(2, 3, 15, 'active'),
(3, 5, 15, 'active'),
(4, 7, 15, 'active'),
(5, 2, 16, 'active'),
(6, 4, 16, 'active'),
(7, 6, 16, 'active'),
(8, 8, 16, 'active'),
(9, 14, 17, 'active'),
(10, 26, 17, 'active'),
(11, 9, 1, 'active'),
(12, 19, 1, 'active'),
(13, 21, 1, 'active'),
(14, 30, 1, 'active'),
(15, 20, 4, 'active'),
(16, 28, 4, 'active'),
(17, 10, 7, 'active'),
(18, 11, 7, 'active'),
(19, 22, 7, 'active'),
(20, 24, 7, 'active'),
(21, 12, 8, 'active'),
(22, 23, 8, 'active'),
(23, 48, 9, 'active'),
(24, 49, 9, 'active'),
(25, 55, 9, 'active'),
(26, 29, 10, 'active'),
(27, 31, 10, 'active'),
(28, 35, 10, 'active'),
(29, 56, 10, 'active'),
(30, 41, 12, 'active'),
(31, 53, 12, 'active'),
(32, 59, 12, 'active'),
(33, 42, 14, 'active'),
(34, 44, 14, 'active'),
(35, 46, 14, 'active'),
(36, 54, 21, 'active'),
(37, 57, 21, 'active'),
(38, 58, 21, 'active'),
(39, 15, 21, 'active'),
(40, 38, 11, 'active'),
(41, 43, 11, 'active'),
(42, 47, 11, 'active'),
(43, 25, 13, 'active'),
(44, 27, 13, 'active'),
(45, 32, 18, 'active'),
(46, 34, 18, 'active'),
(47, 36, 18, 'active'),
(48, 33, 19, 'active'),
(49, 37, 19, 'active'),
(50, 39, 20, 'active'),
(51, 40, 20, 'active'),
(52, 45, 22, 'active'),
(53, 52, 22, 'active'),
(54, 60, 23, 'active'),
(55, 13, 23, 'active'),
(56, 16, 24, 'active'),
(57, 18, 24, 'active'),
(58, 50, 25, 'active'),
(59, 28, 4, 'completed successfully'),
(60, 29, 10, 'completed successfully'),
(61, 33, 19, 'completed successfully'),
(62, 48, 9, 'completed successfully'),
(63, 50, 25, 'completed successfully'),
(64, 51, 9, 'completed successfully'),
(65, 5, 15, 'completed early'),
(66, 11, 7, 'completed early'),
(67, 23, 8, 'completed early'),
(68, 38, 11, 'completed early');

--Встречи пар

INSERT INTO meetings (meeting_id, pairs_id, meeting_date, duration, graduate_rating, mentor_rating, notes) VALUES
(1, 1, '2024-01-15', 60, 9, 8, 'Discussed resume structure. Assigned homework.'),
(2, 1, '2024-02-01', 90, 10, 9, 'Practice interview. Good progress.'),
(3, 2, '2024-01-20', 75, 8, 7, 'Created a monthly budget plan.'),
(4, 3, '2023-11-10', 120, 10, 10, 'Prepared university application package.'),
(5, 3, '2023-12-05', 60, 9, 9, 'Final review before submission.'),
(6, 4, '2024-01-25', 90, 7, 8, 'Reviewed standard rental agreement clauses.'),
(7, 5, '2024-02-10', 60, 8, 7, 'Role-played conflict situation.'),
(8, 6, '2024-01-18', 120, 9, 9, 'Technical resume and LinkedIn profile.'),
(9, 7, '2023-10-15', 90, 6, 7, 'Student decided to take a gap year.'),
(10, 8, '2024-02-05', 60, 8, 8, 'How to search for apartments online.'),
(11, 9, '2024-01-30', 75, 9, 8, 'Networking event strategies.'),
(12, 10, '2024-02-12', 90, 10, 9, 'Public speaking techniques.'),
(13, 11, '2024-01-22', 60, 7, 7, 'Basic emotional regulation methods.'),
(14, 12, '2024-02-14', 120, 9, 10, 'Deep dive into time management tools.'),
(15, 14, '2023-12-20', 60, 10, 10, 'Final meeting, successful completion.'),
(16, 18, '2023-11-30', 90, 5, 6, 'Graduate stopped responding. Pair closed early.'),
(17, 1, '2025-01-20', 60, NULL, NULL, 'Planned: Job search update'),
(18, 1, '2025-03-10', 90, NULL, NULL, 'Planned: Mock interview with HR'),
(19, 2, '2025-02-15', 75, NULL, NULL, 'Planned: Annual budget review'),
(20, 2, '2025-04-05', 60, NULL, NULL, 'Planned: Investment basics'),
(21, 4, '2025-01-25', 90, NULL, NULL, 'Planned: Lease negotiation strategies'),
(22, 4, '2025-06-10', 60, NULL, NULL, 'Planned: Legal rights as a tenant'),
(23, 5, '2025-03-18', 120, NULL, NULL, 'Planned: Advanced conflict resolution'),
(24, 6, '2025-02-28', 90, NULL, NULL, 'Planned: Tech industry networking'),
(25, 8, '2025-05-15', 60, NULL, NULL, 'Planned: Apartment hunting field trip'),
(26, 9, '2025-04-20', 75, NULL, NULL, 'Planned: LinkedIn optimization'),
(27, 10, '2025-03-05', 90, NULL, NULL, 'Planned: Presentation skills workshop'),
(28, 11, '2025-02-10', 60, NULL, NULL, 'Planned: Stress management techniques'),
(29, 12, '2025-06-25', 120, NULL, NULL, 'Planned: Project management tools'),
(30, 13, '2025-07-10', 60, NULL, NULL, 'Planned: Tax planning for freelancers'),
(31, 15, '2025-08-15', 90, NULL, NULL, 'Planned: Career path planning'),
(32, 16, '2025-09-20', 60, NULL, NULL, 'Planned: University selection criteria'),
(33, 17, '2025-11-05', 75, NULL, NULL, 'Planned: Property purchase basics'),
(34, 1, '2026-01-10', 60, NULL, NULL, 'Planned: Yearly career review'),
(35, 2, '2026-02-20', 90, NULL, NULL, 'Planned: Retirement planning introduction'),
(36, 4, '2026-03-01', 120, NULL, NULL, 'Planned: Contract law basics'),
(37, 6, '2026-01-30', 90, NULL, NULL, 'Planned: Salary negotiation tactics'),
(38, 9, '2026-02-15', 60, NULL, NULL, 'Planned: Professional branding'),
(39, 3, '2024-10-15', 60, NULL, NULL, 'Follow-up: University admission results'),
(40, 7, '2024-09-20', 90, NULL, NULL, 'Follow-up: Gap year plans'),
(41, 14, '2024-11-10', 60, NULL, NULL, 'Follow-up: Career progression check'),
(42, 18, '2024-08-05', 75, NULL, NULL, 'Follow-up: Financial stability check');
