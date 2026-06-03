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

--Таблица 4 - связь многие ко многим(выпускники - навыки), где фиксируются навыки 
(skill_id), которые выпускнику (graduate_id) необходимо развить

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
(1, 'Anna', 'Ivanova', '1998-03-15', 'F', '+79161234567', 'university', 'looking for job'),
(2, 'Ivan', 'Petrov', '1999-07-22', 'M', '+79262345678', 'college', 'working'),
(3, 'Maria', 'Sidorova', '2000-11-05', 'F', '+79373456789', 'school', 'studying'),
(4, 'Alexey', 'Kuznetsov', '1995-12-30', 'M', '+79484567890', 'graduated', 'working'),
(5, 'Elena', 'Smirnova', '1997-05-18', 'F', '+79595678901', 'university', 'not working'),
(6, 'Dmitry', 'Vasilev', '1996-09-10', 'M', '+79606789012', 'college', 'looking for job'),
(7, 'Olga', 'Popova', '2001-02-28', 'F', '+79717890123', 'school', 'studying'),
(8, 'Sergey', 'Novikov', '1994-08-14', 'M', '+79828901234', 'graduated', 'working'),
(9, 'Natalia', 'Volkova', '1993-04-25', 'F', '+79939012345', 'university', 'working'),
(10, 'Andrey', 'Fedorov', '2002-06-19', 'M', '+79140123456', 'school', 'studying'),
(11, 'Ekaterina', 'Morozova', '1992-01-11', 'F', '+79251234567', 'graduated', 'not working'),
(12, 'Pavel', 'Alekseev', '1998-10-07', 'M', '+79362345678', 'university', 'looking for job'),
(13, 'Tatiana', 'Lebedeva', '1999-12-03', 'F', '+79473456789', 'college', 'working'),
(14, 'Mikhail', 'Sokolov', '1997-02-21', 'M', '+79584567890', 'university', 'working'),
(15, 'Irina', 'Kozlova', '1996-07-17', 'F', '+79695678901', 'college', 'looking for job'),
(16, 'Artem', 'Orlov', '2000-05-30', 'M', '+79706789012', 'school', 'studying'),
(17, 'Svetlana', 'Guseva', '1995-09-08', 'F', '+79817890123', 'graduated', 'working'),
(18, 'Viktor', 'Titov', '1994-11-12', 'M', '+79928901234', 'graduated', 'not working');

--Данные о наставниках

INSERT INTO mentors (mentor_id, first_name, last_name, profession, work_in_programm_years, phone) VALUES
(1, 'Alexander', 'Baranov', 'Software Engineer', 3, '+79031234567'),
(2, 'Elena', 'Zaitseva', 'HR Manager', 5, '+79042345678'),
(3, 'Dmitry', 'Medvedev', 'Lawyer', 2, '+79053456789'),
(4, 'Olga', 'Vorobieva', 'Financial Analyst', 4, '+79064567890'),
(5, 'Igor', 'Karpov', 'Psychologist', 6, '+79075678901'),
(6, 'Nina', 'Solovieva', 'Career Counselor', 3, '+79086789012'),
(7, 'Stanislav', 'Grigoriev', 'Accountant', 1, '+79097890123'),
(8, 'Marina', 'Filatova', 'Social Worker', 7, '+79108901234'),
(9, 'Roman', 'Davidov', 'Business Owner', 4, '+79119012345'),
(10, 'Anastasia', 'Egorova', 'University Teacher', 2, '+79120123456');

--Справочник навыков/проблем

INSERT INTO skills_list (skill_id, skill_name, category, description) VALUES
(1, 'Resume Writing', 'work', 'How to create an effective CV'),
(2, 'Interview Preparation', 'work', 'Techniques for successful job interviews'),
(3, 'Budget Planning', 'finance', 'Basics of personal finance management'),
(4, 'Rental Agreement Review', 'legal', 'Understanding rental contracts'),
(5, 'Conflict Resolution', 'communication', 'Methods for resolving interpersonal conflicts'),
(6, 'Time Management', 'work', 'Planning and prioritizing tasks'),
(7, 'Cooking Basics', 'housing', 'Simple meal preparation skills'),
(8, 'University Application', 'education', 'Process of applying to higher education institutions'),
(9, 'Public Speaking', 'communication', 'Overcoming fear of public speaking'),
(10, 'Tax Filing', 'finance', 'Basic knowledge of personal tax declaration'),
(11, 'Finding Accommodation', 'housing', 'How to search for rental apartments'),
(12, 'Professional Networking', 'work', 'Building connections in professional field');

--Проблемы(запросы) выпусников

INSERT INTO graduate_problems (graduate_id, skill_id) VALUES
(1, 1), (1, 2), (1, 6),
(2, 3), (2, 10),
(3, 8), (3, 9),
(4, 4), (4, 11),
(5, 5), (5, 7),
(6, 1), (6, 2), (6, 12),
(7, 8),
(8, 4), (8, 11),
(9, 12),
(10, 8), (10, 9),
(11, 3), (11, 5),
(12, 1), (12, 2), (12, 6),
(13, 10),
(14, 12),
(15, 1), (15, 6),
(16, 8),
(17, 4), (17, 10),
(18, 3), (18, 5);

--Компетенции наставников

INSERT INTO mentor_competencies (mentor_id, skill_id) VALUES
(1, 1), (1, 2), (1, 6), (1, 12),
(2, 2), (2, 5), (2, 12),
(3, 4), (3, 10),
(4, 3), (4, 6), (4, 10),
(5, 5), (5, 9),
(6, 1), (6, 2), (6, 8),
(7, 3), (7, 10),
(8, 4), (8, 5), (8, 7), (8, 11),
(9, 1), (9, 3), (9, 6), (9, 12),
(10, 8), (10, 9);

--Образованные пары

INSERT INTO pairs (pairs_id, graduate_id, mentor_id, status) VALUES
(1, 1, 6, 'active'),
(2, 2, 4, 'active'),
(3, 3, 10, 'completed successfully'), 
(4, 4, 3, 'active'),
(5, 5, 5, 'active'),
(6, 6, 1, 'active'),
(7, 7, 10, 'completed early'),
(8, 8, 8, 'active'),
(9, 9, 9, 'active'),
(10, 10, 10, 'active'),
(11, 11, 5, 'active'),
(12, 12, 1, 'active'),
(13, 13, 7, 'active'),
(14, 14, 9, 'completed successfully'),
(15, 15, 6, 'active'),
(16, 16, 10, 'active'),
(17, 17, 3, 'active'),
(18, 18, 5, 'completed early'); 

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