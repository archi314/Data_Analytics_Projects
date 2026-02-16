/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Стукалов Артем Витальевич
 * Дата: 29.09.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь

	WITH total_users_count AS (
		SELECT
			COUNT(DISTINCT u.id) AS total_users, --Общее количество игроков
			(SELECT COUNT(DISTINCT u.id) 
			FROM fantasy.users AS u 
			WHERE u.payer = 1
			) AS total_paying_users --Общее количество платящих игроков
		FROM fantasy.users AS u
	)

	--Доля платящих игроков от их общего количества
	SELECT 
		total_users,
		total_paying_users,
		ROUND(total_paying_users::NUMERIC/total_users::NUMERIC, 5) AS share_paying_users
	FROM total_users_count;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
	
	--Oбщее количество зарегистрированных игроков для каждой расы
	WITH total_race_count AS (
		SELECT
			DISTINCT r.race,
			COUNT(u.id) OVER(PARTITION BY r.race) AS total_users
		FROM fantasy.users AS u
		INNER JOIN fantasy.race AS r ON u.race_id = r.race_id	
	),
	
	-- Общее количество платящих игроков для каждой расы
	paying_race_count AS (
		SELECT 
			DISTINCT r.race,
			COUNT(u.id) OVER(PARTITION BY r.race) AS paying_users
		FROM fantasy.users AS u
		INNER JOIN fantasy.race AS r ON u.race_id = r.race_id	
		WHERE u.payer = 1
	)
	
	--Доля платящих игроков среди всех зарегистрированных игроков для каждой расы.
	SELECT 
		t.race,
		p.paying_users,
		t.total_users,
		ROUND(p.paying_users::numeric/t.total_users::numeric, 5) AS share_paying_users_in_race_context
	FROM total_race_count AS t 
	LEFT JOIN paying_race_count AS p ON t.race = p.race
	ORDER BY share_paying_users_in_race_context DESC;
	

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
	
	SELECT
		COUNT(e.transaction_id) AS purchase_count,
		SUM(e.amount) AS total_amount,
		MIN(e.amount) AS min_price,
		MAX(e.amount) AS max_price,
		ROUND(AVG(e.amount)::NUMERIC, 2) AS avg_price,
		ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY e.amount)::NUMERIC, 2) AS median,
		ROUND(STDDEV(e.amount)::NUMERIC, 2) AS deviation
	FROM fantasy.events AS e;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
	
	--Покупки с нулевой стоимостью
	WITH free_purchases_count AS (
		SELECT
			COUNT(e.transaction_id) AS free_purchases_count
		FROM fantasy.events AS e 
		WHERE e.amount = 0
	),
	
	--Общее количество всех покупок
	all_purchases AS (
		SELECT
			COUNT(e.transaction_id) AS total_purchases_count
		FROM fantasy.events AS e 
	)
	
	--Доля покупок с нулевой стоимостью от общего числа покупок
	SELECT
		free_purchases_count,
		total_purchases_count,
		ROUND(free_purchases_count::NUMERIC / total_purchases_count::NUMERIC, 5) AS share_of_free_purchases
	FROM free_purchases_count, all_purchases;
	
	
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
	
	--фильтрация покупок с нулевой стоимостью
	WITH paying_players AS (	
		SELECT
			e.item_code,
			e.transaction_id,
			e.id AS player_id
		FROM fantasy.events AS e 
		WHERE e.amount > 0
	),
	
	sales_info AS (
		SELECT
			item_code,
			COUNT(DISTINCT transaction_id) AS total_sales, --количество продаж одного предмета
			COUNT(DISTINCT player_id) AS total_paying_players --количество уникальных игроков, купивших один предмет
		FROM paying_players
		GROUP BY item_code
	)
	
	SELECT
		DISTINCT i.game_items,
		si.total_sales,--Общее количество внутриигровых продаж в абсолютном значении
		ROUND(si.total_sales * 1.0/(SELECT COUNT(DISTINCT transaction_id) FROM paying_players), 5) AS share_of_items_sale, --Общее количество внутриигровых продаж в относительном значении,
		ROUND(si.total_paying_players * 1.0/(SELECT COUNT(DISTINCT player_id) FROM paying_players), 5) AS share_of_players --Доля игроков, которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей
	FROM sales_info AS si
	INNER JOIN fantasy.items AS i ON si.item_code = i.item_code 
	GROUP BY i.game_items, si.total_sales, si.total_paying_players
	ORDER BY share_of_items_sale DESC;
	
	
	
-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
	
-- общее количество зарегистрированных игроков для каждой расы.
WITH total_users AS (
	SELECT
		r.race,
		COUNT(DISTINCT u.id) AS total_users
	FROM fantasy.users AS u 
	LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id 
	GROUP BY r.race
),

--количество игроков, которые совершили внутриигровую покупку
buying_users AS (
	SELECT
		r.race,
		COUNT(DISTINCT e.id) AS buying_users
	FROM fantasy.users AS u 
	LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id 
	LEFT JOIN fantasy.events AS e ON u.id = e.id
	WHERE e.amount > 0 
	GROUP BY r.race
),

--количество игроков, которые совершили внутриигровую покупку за реальные деньги.
paying_users AS (
	SELECT
		r.race,
		COUNT(DISTINCT e.id) AS paying_users
	FROM fantasy.users AS u 
	LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id 
	LEFT JOIN fantasy.events AS e ON u.id = e.id
	WHERE e.amount > 0 AND u.payer = 1
	GROUP BY r.race
),

--информацию об активности игроков, совершивших внутриигровую покупку, с учётом расы персонажа.
transaction_activity AS (
	SELECT
		r.race,
		COUNT(e.transaction_id) AS total_transaction,
		SUM(e.amount) AS total_amount
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u ON e.id = u.id 
	LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id 
	WHERE e.amount > 0
	GROUP BY r.race
)

SELECT
	t.race, --название расы
	t.total_users, --общее количество зарегистрированных игроков для каждой расы
	b.buying_users, --количество игроков, которые совершили внутриигровую покупку
	p.paying_users, --количество игроков, которые совершили внутриигровую покупку за реальные деньги
	ROUND(b.buying_users::NUMERIC / t.total_users::NUMERIC, 2) AS share_buying_users, --доля игроков, которые совершают внутриигровые покупки, от общего количества зарегистрированных игроков
	ROUND(p.paying_users::NUMERIC / b.buying_users::NUMERIC, 2) AS share_paying_users, --доля платящих игроков среди игроков, которые совершили внутриигровые покупки
	ROUND(ta.total_transaction::NUMERIC / b.buying_users::NUMERIC, 2) AS avg_purchase_count, --среднее количество покупок на одного игрока, совершившего внутриигровые покупки
	ROUND(ta.total_amount::NUMERIC / ta.total_transaction::NUMERIC, 2) AS avg_purchace_amount, --средняя стоимость одной покупки на одного игрока, совершившего внутриигровые покупки
	ROUND(ta.total_amount::NUMERIC / b.buying_users::NUMERIC, 2) AS avg_amount_all_purchases --средняя суммарная стоимость всех покупок на одного игрока, совершившего внутриигровые покупки
FROM total_users AS t
LEFT JOIN buying_users AS b ON t.race = b.race
LEFT JOIN paying_users AS p ON t.race = p.race
LEFT JOIN transaction_activity AS ta ON t.race = ta.race;
	
