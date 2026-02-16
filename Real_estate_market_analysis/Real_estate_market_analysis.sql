/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Стукалов Артем Витальевич
 * Дата: 21.10.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        	AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
    
    --группировка объявлений по дням активности с учётом региона и типа населённого пункта
    category_ads AS (
    	SELECT
    		a.id,
    		a.last_price,
    		f.total_area,
    		f.rooms,
    		f.balcony,
    		f.ceiling_height,
    		f.floors_total,   
    		f.floor,
    		f.open_plan,
    		f.parks_around3000,
    		f.ponds_around3000,
    		f.living_area,
    		f.is_apartment,
    		f.kitchen_area,
    		f.airports_nearest,
    		t.type,
    		CASE
    			WHEN a.days_exposition <= 30 THEN '1-30 days'
    			WHEN a.days_exposition <= 90 THEN '31-90 days'
    			WHEN a.days_exposition <= 180 THEN '91-180 days'
    			WHEN a.days_exposition >= 181 THEN '181+ days'
    			ELSE 'active'
    		END AS category_ads,
    		CASE 
            	WHEN a.days_exposition <= 30 THEN 1
            	WHEN a.days_exposition <= 90 THEN 2
            	WHEN a.days_exposition <= 180 THEN 3
            	WHEN a.days_exposition >= 181 THEN 4
            	ELSE 5
        	END AS sort_order,
    		CASE
    			WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
    			ELSE 'Ленинградская область'
    		END AS area_name		
    	FROM real_estate.advertisement AS a
    	INNER JOIN filtered_id AS fi USING(id)
    	INNER JOIN real_estate.flats AS f USING (id)
    	INNER JOIN real_estate.city AS c USING(city_id)
    	INNER JOIN real_estate.type AS t USING (type_id)
    	WHERE t.type ='город'
    		AND EXTRACT(YEAR FROM a.first_day_exposition::timestamp) BETWEEN 2015 AND 2018
    )
    
    SELECT
        area_name, --регион
		category_ads, --сегмент активности
    	COUNT(id) AS ads_count, --количество объявлений
    	ROUND(COUNT(id)::NUMERIC/SUM(COUNT(id)) OVER (PARTITION BY area_name), 2) AS ads_share, --доля объявлений
    	ROUND(AVG(last_price * 1.0 / total_area)::NUMERIC, 2) AS avg_price_for_metre, --средняя стоимость квадратного метра
    	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area, --средняя площадь недвижимости
    	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY rooms) AS median_rooms, --среднее количество комнат
    	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY balcony) AS median_balcony, --среднее количество балконов
    	ROUND(AVG(ceiling_height)::NUMERIC, 2) AS avg_ceiling_height, --средняя высота потолка
    	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY floors_total) AS median_floors_total, -- средняя этажность дома, в котором находится квартира
    	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY floor) AS median_floor, --средний этаж квартиры
    	ROUND(SUM(CASE WHEN open_plan = 1 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)::NUMERIC, 2) AS open_plan_share, --доля квартир с открытой планировкой 
    	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY parks_around3000) AS median_parks_around3000, --среднее число парков в радиусе трёх километров
    	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY ponds_around3000) AS median_ponds_around3000, --среднее число водоёмов в радиусе трёх километров
    	ROUND(AVG(living_area)::NUMERIC, 2) AS avg_living_area, --средняя жилая площадь, в кв. метрах.
    	ROUND(SUM(CASE WHEN is_apartment = 1 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)::NUMERIC, 2) AS apartment_share, --доля апартаментов среди всех квартир
    	ROUND(AVG(kitchen_area)::NUMERIC, 2) AS avg_kitchen_area, --средняя  площадь кухни, в кв. метрах.
    	ROUND(AVG(airports_nearest)::NUMERIC / 1000, 2) AS avg_airports_nearest --среднее расстояние до ближайшего аэропорта, в километрах
   	FROM category_ads
    GROUP BY category_ads, area_name, sort_order
	ORDER BY area_name DESC, sort_order ASC;

    
-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
    
--объединенные данные по недвижимости 
    pooled_data AS (
    	SELECT 
    		a.id,
    		a.first_day_exposition,
    		a.days_exposition,
    		a.last_price,
    		f.total_area,
    		EXTRACT(MONTH FROM a.first_day_exposition::timestamp) AS publish_month,
    		EXTRACT(MONTH FROM a.first_day_exposition::timestamp + INTERVAL'1 day' * a.days_exposition) AS removal_month,
    		ROUND((a.last_price * 1.0 / f.total_area)::NUMERIC, 2) AS price_for_metre
    	FROM real_estate.advertisement AS a
    	INNER JOIN filtered_id AS fi USING(id)
		INNER JOIN real_estate.flats AS f USING (id)
		INNER JOIN real_estate.type AS t USING (type_id)
		WHERE t.type = 'город'
			AND EXTRACT(YEAR FROM a.first_day_exposition::timestamp) BETWEEN 2015 AND 2018
    ),
    
   --данные с момента публикации объявления
    published_ads AS(
    	SELECT
    		publish_month,
    		COUNT(id) AS published_ads,
    		ROUND(COUNT(id)::NUMERIC * 1.0 / SUM(COUNT(id)) OVER(), 2) AS share_of_published_ads,
    		ROUND(AVG(price_for_metre)::NUMERIC, 2) AS published_avg_price_for_metre,
    		ROUND(AVG(total_area)::NUMERIC, 2) AS published_avg_total_area,
    		RANK() OVER(ORDER BY COUNT(id) DESC) AS published_rank
    	FROM pooled_data
    	GROUP BY publish_month
    ),	

    --данные с момента снятия объявления
    removed_ads AS (
    	SELECT
    		removal_month,
    		COUNT(id) AS removed_ads,
    		ROUND(COUNT(id)::NUMERIC * 1.0 / SUM(COUNT(id)) OVER(), 2) AS share_of_removed_ads,
    		ROUND(AVG(price_for_metre)::NUMERIC, 2) AS removed_avg_price_for_metre,
    		ROUND(AVG(total_area)::NUMERIC, 2) AS removed_avg_total_area,
    		RANK() OVER(ORDER BY COUNT(id) DESC) AS removed_rank
    	FROM pooled_data
    	WHERE removal_month IS NOT NULL
    	GROUP BY removal_month
    )
    
    SELECT
    	p.publish_month,
    	TO_CHAR(MAKE_DATE(2023, p.publish_month::integer, 1), 'Month') AS month_name,
    	CASE 
    		WHEN p.publish_month IN (12, 1, 2) THEN 'Зима'
			WHEN p.publish_month IN (3, 4, 5) THEN 'Весна'
			WHEN p.publish_month IN (6, 7, 8) THEN 'Лето'
			WHEN p.publish_month IN (9, 10, 11) THEN 'Осень'
    	END AS season_name,
    	p.published_ads,
    	p.share_of_published_ads,
    	p.published_rank,
    	r.removed_ads,
    	r.share_of_removed_ads,
    	r.removed_rank,
    	p.published_avg_price_for_metre,
    	r.removed_avg_price_for_metre,
    	p.published_avg_total_area,
    	r.removed_avg_total_area
    FROM published_ads AS p
    FULL JOIN removed_ads AS r ON p.publish_month = r.removal_month
    ORDER BY p.publish_month ASC;
    