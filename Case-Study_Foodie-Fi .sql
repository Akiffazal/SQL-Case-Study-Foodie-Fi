SELECT * FROM plans;
SELECT * FROM subscriptions;

-- ------------------------------------------------------------------------------------------------------------------------

-- 1. How many customers has Foodie-Fi ever had? 
SELECT 
	COUNT(DISTINCT customer_id) AS total_customers
FROM subscriptions;

-- ------------------------------------------------------------------------------------------------------------------------

-- 2. What is the monthly distribution of trial plan start_date values for our dataset 
	-- use the start of the month as the group by value 
SELECT * FROM plans;
SELECT * FROM subscriptions;

-- method_01
SELECT 
	count(plan_id) as count_trial_plan, 
    month(start_date) as months
FROM subscriptions
	GROUP BY months, plan_id
HAVING plan_id=0;


-- method_02
SELECT 
	COUNT(plan_id), 
    MONTH(start_date) AS months
FROM subscriptions
	WHERE plan_id = 0
GROUP BY months;


-- method_03 (this query will not work in MySQL)
SELECT 
	DATE_TRUNC('month',start_date) as month,
	COUNT(customer_id) as trial_starts
FROM subscriptions
	WHERE plan_id = 0
GROUP BY DATE_TRUNC('month',start_date);

-- ------------------------------------------------------------------------------------------------------------------------

-- 3. What plan start_date values occur after the year 2020 for our dataset? 
-- Show the breakdown by count of events for each plan_name...
SELECT * FROM plans;
SELECT * FROM subscriptions;

SELECT 
	s.plan_id,
    p.plan_name,
    count(p.plan_name) as event_count
FROM subscriptions s INNER JOIN plans p
	on s.plan_id = p.plan_id
	WHERE YEAR(s.start_date) > 2020
GROUP BY s.plan_id, p.plan_name;

-- ------------------------------------------------------------------------------------------------------------------------

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place? 
SELECT * FROM plans;
SELECT * FROM subscriptions;

SELECT 
	COUNT(DISTINCT customer_id) as customer_count, 
    ROUND((count(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) * 100, 1) as percentage
from subscriptions 
	where plan_id=4;

-- ------------------------------------------------------------------------------------------------------------------------

/* 5. How many customers have churned straight after their initial free trial 
what percentage is this rounded to the nearest whole number? */

SELECT * FROM plans;
SELECT * FROM subscriptions;

-- Method_01
SELECT
    COUNT(prev_plan) AS cnt_churn,
    ROUND(COUNT(*) * 100 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 0) AS perc_churn
FROM
    (SELECT
         *,
         LAG(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id) AS prev_plan
     FROM
         subscriptions) AS cte_churn
WHERE
    plan_id = 4 AND prev_plan = 0;
    

-- Method_02 (using CTE)

/*
CTE EXPLANATION:
	This Common Table Expression (CTE) named `cte_churn` is being used to analyze subscription data, likely in a database context. 
    Here's a brief explanation of what each part does:

	1. CTE Name (`cte_churn`): 
		This is the identifier given to the Common Table Expression. 
		It will be used to reference this temporary result set in subsequent parts of the query.

	2. SELECT Statement: 
		This selects data from the `subscriptions` table.

	3. LAG() Function: 
		This function is used to retrieve the value of a column from the previous row in the partition 
		defined by the `PARTITION BY` clause. In this case, it's used to get the previous `plan_id` for each `customer_id`.

	4. OVER() Clause: 
		This is a window function that defines the partitioning and ordering of rows for the window function (in this case, `LAG()`). 
		`PARTITION BY customer_id` indicates that the `LAG()` function will operate separately for each `customer_id`, 
		creating distinct partitions.

	5. prev_plan Alias: 
		This is an alias assigned to the result of the `LAG()` function, making it easier to refer to the previous plan ID.

	Overall, this CTE is likely being used to analyze customer churn by comparing the current plan to the previous plan for each customer, as indicated by the use of `LAG()` to retrieve the previous plan ID.
    */

WITH cte_churn AS (
	SELECT *, LAG(plan_id, 1)  OVER(PARTITION BY customer_id) AS prev_plan
	FROM subscriptions
)
SELECT
	COUNT(prev_plan) AS cnt_churn,
	ROUND(COUNT(*) * 100/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),0) AS perc_churn
FROM cte_churn
WHERE plan_id = 4 and prev_plan = 0;


-- Method_03(using CTE)
WITH CTE_chrun AS (
	SELECT customer_id, plan_name,
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) as row_numbr
FROM subscriptions as S
	INNER JOIN plans as P on S.plan_id = P.plan_id
)
SELECT 
	COUNT(DISTINCT customer_id) as churned_after_trial,
	ROUND((COUNT(DISTINCT customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions))*100,0) as percent_churn_after_trial
FROM CTE_chrun
	WHERE row_numbr = 2
	AND plan_name = 'churn';

-- ------------------------------------------------------------------------------------------------------------------------

-- 6. What is the number and percentage of customer plans after their initial free trial?
/*
1. Common Table Expression (CTE) - explanation:
    - This part of the query defines a CTE named `cte_next_plan`.
    - The CTE selects all columns from the `subscriptions` table and calculates the next plan for each customer using the `LEAD` function.
    - `LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id)` retrieves the next `plan_id` for each customer, partitioned by `customer_id` and ordered by `plan_id`.

2. Main Query - explanation:
    - This part of the query retrieves the result from the CTE and performs further calculations.
    - It selects the `next_plan`, counts the number of customers (`num_cust`), and calculates the percentage of customers (`perc_next_plan`) for each next plan.
    - The `WHERE` clause filters out rows where the `next_plan` is not null (meaning there is a next plan) and the current plan is a trial plan (plan_id = 0).
    - The `GROUP BY` clause groups the results by the next plan.
    - The `ORDER BY` clause orders the results by the next plan.

 -> In summary, this query analyzes the plans chosen by customers after their initial free trial. It calculates both the number and percentage of customers for each subsequent plan, excluding the trial plan itself.
*/

-- method_01

WITH cte_next_plan AS (
	SELECT 
		*,
		LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id) AS next_plan
	FROM subscriptions)
    
SELECT
	next_plan,
	COUNT(*) AS num_cust,
	ROUND(COUNT(*) * 100/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),1) AS perc_next_plan
FROM cte_next_plan
	WHERE next_plan is not null and plan_id = 0
GROUP BY next_plan;


-- Method_02
WITH CTE AS (
	SELECT customer_id, plan_name, ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) as row_nmbr
FROM subscriptions S INNER JOIN plans P 
	ON P.plan_id = S.plan_id)
    
SELECT 
	plan_name,
	COUNT(customer_id) as customer_count,
	ROUND((COUNT(customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM CTE))*100,1) as customer_percent
FROM CTE
	WHERE row_nmbr = 2
	GROUP BY plan_name;

-- ------------------------------------------------------------------------------------------------------------------------

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
/* method_01;
	1.Common Table Expression (CTE) - explanation:
		- WITH CTE AS: This defines a Common Table Expression (CTE) named `CTE`.
		- SELECT *: Selects all columns from the `subscriptions` table.
		- ROW_NUMBER() OVER(...): Assigns a row number to each row within each partition of `customer_id`, ordered by `start_date` in descending order. 
        - * -> This helps in identifying the latest subscription for each customer.
		- PARTITION BY customer_id: Partitions the data into groups based on the unique `customer_id`.
		- ORDER BY start_date DESC: Orders the rows within each partition by `start_date` in descending order, ensuring that the latest subscription comes first.
		- WHERE start_date <= '2020-12-31': Filters the data to include only subscriptions with a `start_date` before or on December 31, 2020.
	2.Main Query - explanation:
		- SELECT plan_name: Selects the plan name.
		- COUNT(customer_id) as customer_count: Counts the number of customers for each plan.
		- ROUND(...)*100,1) as percent_of_customers: Calculates the percentage of customers for each plan, rounded to one decimal place.
		- FROM CTE: Specifies that the data is retrieved from the Common Table Expression `CTE`.
		- INNER JOIN plans as P on CTE.plan_id = P.plan_id: Joins the CTE with the `plans` table on the `plan_id` column to retrieve the plan names.
		- WHERE rn = 1: Filters the data to include only the latest subscription for each customer (where `rn` is equal to 1).
		- GROUP BY plan_name: Groups the results by plan name.
	In summary, this query calculates the number and percentage of customers for each plan based on their latest subscription before or on December 31, 2020. It uses a Common Table Expression to identify the latest subscription for each customer and then joins this data with the `plans` table to retrieve the plan names. Finally, it calculates the count and percentage of customers for each plan and groups the results by plan name.
*/

WITH My_CTE AS (
	SELECT  
		*, 
		ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) as rwnmbr
	FROM subscriptions
		WHERE start_date <= '2020-12-31')
        
SELECT 
	plan_name,
	COUNT(customer_id) as customer_count,
	ROUND((COUNT(customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM My_CTE))*100,1) as percent_of_customers
FROM My_CTE mc INNER JOIN plans as P ON mc.plan_id = P.plan_id
	WHERE rwnmbr = 1
	GROUP BY plan_name;


-- method_02
WITH cte_next_date AS (
	SELECT
		*,
		LEAD(start_date, 1) OVER(PARTITION BY customer_id ORDER BY start_date) AS next_date
	FROM subscriptions
    WHERE start_date <= '2020-12-31'),
plans_breakdown AS(
	SELECT
		plan_id,
		COUNT(DISTINCT customer_id) AS num_customer
	FROM cte_next_date
	WHERE (next_date IS NOT NULL AND (start_date < '2020-12-31' AND next_date > '2020-12-31'))
		  OR (next_date IS NULL AND start_date < '2020-12-31')
	GROUP BY plan_id)
    
SELECT
	plan_id,
	num_customer,
    ROUND(num_customer * 100/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),1) AS perc_customer
FROM plans_breakdown
	GROUP BY plan_id, num_customer;

-- ------------------------------------------------------------------------------------------------------------------------

-- 8. How many customers have upgraded to an annual in 2020?
SELECT * FROM plans;
SELECT * FROM subscriptions;

SELECT count(*) AS count_annual_plan_2020
FROM subscriptions
	WHERE Year(start_date) = 2020 and plan_id = 3;

-- ------------------------------------------------------------------------------------------------------------------------

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
SELECT * FROM plans;
SELECT * FROM subscriptions;

WITH trail_plan AS (
	SELECT  customer_id, 
			start_date AS trail_dates
    FROM subscriptions
    WHERE plan_id=0
),
annual_plan as (
	select  customer_id, 
			start_date as annual_dates
    from subscriptions
    where plan_id=3
)

SELECT 
	ROUND(AVG(DATEDIFF(annual_dates, trail_dates)),0) AS avg_days_annual_upgrade
FROM annual_plan ap JOIN trail_plan tp
ON ap.customer_id = tp.customer_id;

-- ------------------------------------------------------------------------------------------------------------------------

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

WITH annual_plan AS (
	SELECT
		customer_id,
        start_date AS annual_date
	FROM subscriptions
    WHERE plan_id = 3),
trial_plan AS (
	SELECT
		customer_id,
        start_date AS trial_date
	FROM subscriptions
    WHERE plan_id = 0
),
day_period AS (
	SELECT
		DATEDIFF(annual_date, trial_date) AS diff
	FROM trial_plan tp LEFT JOIN annual_plan ap 
	ON tp.customer_id = ap.customer_id
		WHERE annual_date is not null
),
bins AS (
	SELECT
		*, 
		FLOOR(diff/30) AS bins
	FROM day_period)
    
SELECT
	CONCAT((bins * 30) + 1, ' - ', (bins + 1) * 30, ' days ') AS days,
	COUNT(diff) AS total
FROM bins
GROUP BY bins;

-- ------------------------------------------------------------------------------------------------------------------------

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

WITH next_plan AS (
	SELECT 
		*,
		LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY start_date, plan_id) AS plan
	FROM subscriptions)
    
SELECT
	COUNT(DISTINCT customer_id) AS num_downgrade
FROM next_plan np LEFT JOIN plans p 
ON p.plan_id = np.plan_id
	WHERE p.plan_name = 'pro monthly' AND np.plan = 1 AND start_date <= '2020-12-31';

