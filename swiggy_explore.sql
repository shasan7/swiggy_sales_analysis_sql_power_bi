SELECT * FROM swiggy_data

-- Data validation and cleaning
-- Null check

SELECT
	SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS null_state,
	SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS null_city,
	SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
	SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurent,
	SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS null_location,
	SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
	SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) AS null_dish,
	SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END) AS null_price,
	SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
	SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_data; -- No null available here

-- Blank/empty string check

SELECT *
FROM swiggy_data
WHERE
State = '' OR City = '' OR Restaurant_Name = '' OR Location = '' OR Category = ''
OR Dish_Name = ''; -- No blank string as well

-- Check duplicates

SELECT 
State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name, 
Price_INR, Rating, Rating_Count, COUNT(*) AS CNT
FROM swiggy_data
GROUP BY
State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name, 
Price_INR, Rating, Rating_Count
HAVING COUNT(*) > 1 -- Got 29 duplicate records

-- Delete duplicates

WITH CTE AS (
SELECT *, ROW_NUMBER() Over(
	PARTITION BY State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name, 
	Price_INR, Rating, Rating_Count
	ORDER BY (SELECT NULL)
	) AS ROW_NUM
FROM swiggy_data
)
DELETE FROM CTE WHERE ROW_NUM > 1; -- 29 Rows with ROW_Num = 2 was deleted


-- Creating schema
-- Dimension tables
-- Date table

CREATE TABLE dim_date(
	date_id INT IDENTITY(1,1) PRIMARY KEY,
	full_date DATE,
	year INT,
	quarter INT,
	month INT,
	month_name VARCHAR(20),
	week INT,
	day INT
);


-- Location table

CREATE TABLE dim_location(
	loc_id INT IDENTITY(1,1) PRIMARY KEY,
	state VARCHAR(100),
	CITY VARCHAR(100),
	location VARCHAR(200)
);


-- Restaurant table

CREATE TABLE dim_restaurant(
	restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
	restaurant_name VARCHAR(200),
);


-- Category table

CREATE TABLE dim_category(
	category_id INT IDENTITY(1,1) PRIMARY KEY,
	category VARCHAR(200),
);


-- Dish table

CREATE TABLE dim_dish(
	dish_id INT IDENTITY(1,1) PRIMARY KEY,
	dish_name VARCHAR(200),
);


-- Fact table

CREATE TABLE fact_swiggy_orders(
	order_id INT IDENTITY(1,1) PRIMARY KEY,
	date_id INT,
	Price_INR DECIMAL(10,2),
	Rating DECIMAL(4,2),
	Rating_Count INT,

	location_id INT,
	restaurant_id INT,
	category_id INT,
	dish_id INT,

	FOREIGN KEY(date_id) REFERENCES dim_date(date_id),
	FOREIGN KEY(location_id) REFERENCES dim_location(loc_id),
	FOREIGN KEY(restaurant_id) REFERENCES dim_restaurant(restaurant_id),
	FOREIGN KEY(category_id) REFERENCES dim_category(category_id),
	FOREIGN KEY(dish_id) REFERENCES dim_dish(dish_id)
);


-- Insert data into dimension tables
-- the dim_date table

INSERT INTO dim_date(full_date, year, quarter, month, month_name, week, day)
SELECT DISTINCT
	Order_Date,
	YEAR(Order_Date),
	DATEPART(QUARTER, Order_Date),
	MONTH(Order_Date),
	DATENAME(MONTH, Order_Date),
	DATEPART(WEEK, Order_Date),
	DAY(Order_Date)
FROM swiggy_data
WHERE Order_Date IS NOT NULL;


-- the dim_location table

INSERT INTO dim_location(state, city, location)
SELECT DISTINCT
	State,
	City,
	Location
FROM swiggy_data;


-- the dim_restaurant table

INSERT INTO dim_restaurant(restaurant_name)
SELECT DISTINCT
	Restaurant_Name
FROM swiggy_data;


-- the dim_category table

INSERT INTO dim_category(category)
SELECT DISTINCT
	Category
FROM swiggy_data;


-- the dim_dish table

INSERT INTO dim_dish(dish_name)
SELECT DISTINCT
	Dish_Name
FROM swiggy_data;


-- Insert into the fact table

INSERT INTO fact_swiggy_orders(
	date_id,
	Price_INR,
	Rating,
	Rating_Count,
	location_id,
	restaurant_id,
	category_id,
	dish_id
)
SELECT
	dd.date_id,
	s.Price_INR,
	s.rating,
	s.rating_count,

	dl.loc_id,
	dr.restaurant_id,
	dc.category_id,
	dsh.dish_id
FROM swiggy_data s

JOIN dim_date dd
	ON dd.full_date = s.Order_Date

JOIN dim_location dl
	ON dl.state = s.State
	AND dl.city = s.City
	AND dl.location = s.Location

JOIN dim_restaurant dr
	ON dr.restaurant_name = s.Restaurant_Name

JOIN dim_category dc
	ON dc.category = s.Category

JOIN dim_dish dsh
	ON dsh.dish_name = s.Dish_Name;


-- View the final fact table

SELECT * FROM fact_swiggy_orders f
	JOIN dim_date d ON d.date_id = f.date_id
	JOIN dim_location l ON l.loc_id = f.location_id
	JOIN dim_restaurant r ON r.restaurant_id = f.restaurant_id
	JOIN dim_category c ON c.category_id = f.category_id
	JOIN dim_dish di ON di.dish_id = f.dish_id


--KPIs
-- Total orders, revenue, and average rating

SELECT 
	COUNT(order_id) AS [Total Orders],
	SUM(Price_INR)/1000000 AS [Total Revenue in Millions],
	AVG(Rating) AS Avg_Rating
FROM fact_swiggy_orders;


-- Monthly trends

SELECT
	d.year,
	d.month,
	d.month_name,
	COUNT(order_id) AS [Monthly Total Orders],
	SUM(Price_INR) AS [Monthly Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_date d ON d.date_id = f.date_id
GROUP BY d.year, d.month, d.month_name
ORDER BY SUM(Price_INR) DESC;


-- Quarterly trends

SELECT
	d.year,
	d.quarter,
	COUNT(order_id) AS [Quarterly Total Orders],
	SUM(Price_INR) AS [Quarterly Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_date d ON d.date_id = f.date_id
GROUP BY d.year, d.quarter
ORDER BY SUM(Price_INR) DESC;


-- Yearly trends

SELECT
	d.year,
	COUNT(order_id) AS [Yearly Total Orders],
	SUM(Price_INR) AS [Yearly Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_date d ON d.date_id = f.date_id
GROUP BY d.year
ORDER BY SUM(Price_INR) DESC;


-- Day of week trends

SELECT
	DATENAME(WEEKDAY, d.full_date) AS [Day Name],
	COUNT(order_id) AS [Day-wise Total Orders],
	SUM(Price_INR) AS [Day-wise Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_date d ON d.date_id = f.date_id
GROUP BY DATENAME(WEEKDAY, d.full_date), DATEPART(WEEKDAY, d.full_date)
ORDER BY DATEPART(WEEKDAY, d.full_date);


-- Top 10 cities by order volume

SELECT TOP 10
	l.state,
	l.city,
	COUNT(order_id) AS [City-wise Total Orders],
	SUM(Price_INR) AS [City-wise Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_location l ON l.loc_id = f.location_id
GROUP BY l.state, l.city
ORDER BY SUM(Price_INR) DESC;


-- Revenue contribution by state

SELECT TOP 10
	l.state,
	COUNT(order_id) AS [State-wise Total Orders],
	SUM(Price_INR) AS [State-wise Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_location l ON l.loc_id = f.location_id
GROUP BY l.state
ORDER BY SUM(Price_INR) DESC;


-- Top 10 restaurants by orders and revenue

SELECT TOP 10
	r.restaurant_name,
	COUNT(order_id) AS [Restaurant-wise Total Orders],
	SUM(Price_INR) AS [Restaurant-wise Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_restaurant r ON r.restaurant_id = f.restaurant_id
GROUP BY r.restaurant_name
ORDER BY SUM(Price_INR) DESC;


-- Top categories by revenue and order volume

SELECT TOP 10
	c.category,
	COUNT(order_id) AS [Category-wise Total Orders],
	SUM(Price_INR) AS [Category-wise Total Revenue]
FROM fact_swiggy_orders f
	JOIN dim_category c ON c.category_id = f.category_id
GROUP BY c.category
ORDER BY SUM(Price_INR) DESC;


-- Most ordered dishes

SELECT TOP 10
	dd.dish_name,
	COUNT(order_id) AS [Total Orders per Dishes]
FROM fact_swiggy_orders f
	JOIN dim_dish dd ON dd.dish_id = f.dish_id
GROUP BY dd.dish_name
ORDER BY COUNT(order_id) DESC;


-- Total orders by price range

SELECT 
	CASE
		WHEN CONVERT(FLOAT, Price_INR) < 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 100 AND 199 THEN '100 - 199'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 200 AND 299 THEN '200 - 299'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 300 AND 399 THEN '300 - 399'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 400 AND 499 THEN '400 - 499'
		ELSE 'Over 500'
	END AS [Price Interval],
	COUNT(order_id) AS [Interval-wise Total Orders],
	SUM(Price_INR) AS [Interval-wise Total Revenue]
FROM fact_swiggy_orders
GROUP BY
	CASE
		WHEN CONVERT(FLOAT, Price_INR) < 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 100 AND 199 THEN '100 - 199'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 200 AND 299 THEN '200 - 299'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 300 AND 399 THEN '300 - 399'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 400 AND 499 THEN '400 - 499'
		ELSE 'Over 500'
	END
ORDER BY SUM(Price_INR) DESC;


-- Rating analysis

SELECT
	rating,
	COUNT(*) AS [Rating Count]
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY COUNT(*) DESC;