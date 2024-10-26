/*1. Write a query that will show each employee’s first name, salary, department number, average salary for their department, and 
how their salary compares in rank with other employees across the company.  Using dense ranking, assign the highest paid employee 
the rank of 1.  Order the output by Department number ascending, then salary descending. */

SELECT FNAME,SALARY,DNO,AVG(SALARY) OVER (PARTITION BY DNO) AS DeptAvgSalary,
DENSE_RANK() OVER (ORDER BY SALARY DESC) AS SalaryRank
FROM EMPLOYEE 
ORDER BY DNO ASC,SALARY DESC;

/*2. Write a query that lists for Home Depot (HD) all trades from 2023.  The output should include the Ticker symbol, trade date,
closing stock price, the overall closing price rank (with ties and gaps after ties) aliased as CloseRank, and cumulative average 
of the closing price over time starting from the beginning of the year.  List the stocks in order of trade date. */

SELECT TICKER,TRADEDATE,ST_CLOSE,RANK() OVER (ORDER BY ST_CLOSE DESC) AS CloseRank,
    AVG(ST_CLOSE) OVER (ORDER BY TRADEDATE ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumulativeCloseAverage 
FROM STOCKDATA
WHERE TICKER = 'HD' AND EXTRACT(YEAR FROM TRADEDATE) = 2023
ORDER BY TRADEDATE

/*3.  List the Ticker symbol, trade date, closing price, previous day closing price aliased as PrevClose, and subsequent closing price as 
NextClose, and the average of the three closing prices aliased as AvgPrevCurNext.  Order the output by TradeDate, then Ticker.*/
--USING CTE

WITH TradePrices AS (
    SELECT TICKER,TRADEDATE,ST_CLOSE,
	LAG(ST_CLOSE, 1) OVER (PARTITION BY TICKER ORDER BY TRADEDATE) AS PrevClose,
	LEAD(ST_CLOSE, 1) OVER (PARTITION BY TICKER ORDER BY TRADEDATE) AS NextClose 
	FROM STOCKDATA
)
SELECT TICKER, TRADEDATE, ST_CLOSE, PrevClose,NextClose,
	(ISNULL(PrevClose, 0) + ST_CLOSE + ISNULL(NextClose, 0)) / 3 AS AvgPrevCurNext
FROM TradePrices
ORDER BY TRADEDATE,TICKER;


/*4. The following query lists for each Ticker its largest change in closing price since the previous day.  Examine the query closely so that 
you can understand how it is operating.  Then rewrite the query as follows:

   a.	First, run the query below so you can see the results.
   b.	Next, Create a VIEW called ChangeInClose which will create a virtual table for each ticker that shows for a given tradedate the closing 
        price, and the change from the previous days closing price.
   c.	Then, write an SQL query based on ChangeInClose which will display the maximum change in close for each ticker.  Order the output from 
        largest to smallest maximum change in closing price.
   d.	Finally, test your view and query to verify that the same results are obtained as the original query. */

/*A: Run the query */
SELECT Ticker
    , MAX(DC) AS MaxChangeClose
FROM
(SELECT Tradedate
        , Ticker
        , ST_Close - LAG(ST_Close) OVER(PARTITION BY Ticker ORDER BY Tradedate) DC
FROM Stockdata) ChangeInClose
GROUP BY Ticker
ORDER BY MAX(DC) DESC;

/* B: Create a VIEW */
CREATE VIEW ChangeInClose AS
	SELECT TICKER,TRADEDATE,ST_CLOSE,
		ST_CLOSE - LAG(ST_CLOSE) OVER(PARTITION BY TICKER ORDER BY TRADEDATE) AS ChangeFromPrevST_Close
	FROM STOCKDATA;

/* C: Write an SQL Query */
SELECT TICKER, MAX(ChangeFromPrevST_Close) AS MaxChangeInClose FROM ChangeInClose
GROUP BY TICKER
ORDER BY MaxChangeInClose DESC;


/* D: Test VIEW and Query, Verify That the result obtained is the same as initial query in A*/
SELECT TICKER, MAX(ChangeFromPrevST_Close) AS MaxChangeInClose FROM ChangeInClose
GROUP BY TICKER
ORDER BY MaxChangeInClose DESC;

SELECT Ticker
    , MAX(DC) AS MaxChangeClose
FROM
(SELECT Tradedate
        , Ticker
        , ST_Close - LAG(ST_Close) OVER(PARTITION BY Ticker ORDER BY Tradedate) DC
FROM Stockdata) ChangeInClose
GROUP BY Ticker
ORDER BY MAX(DC) DESC;

/* 5. Create a View of the stockdata table called StockdataView. The view should contain each column from the stockdata table as 
well as a ProfitLoss column calculated as the opening price subtracted from the closing price, and the %Profit/Loss. Additionally,
the view should have a column that is only the Year portion of the tradedate. Wouldn't this be nice to write queries against
so you don't always have to EXTRACT the year from Tradedate???? */

CREATE VIEW StockdataView AS
	SELECT *,(ST_CLOSE - ST_OPEN) AS ProfitLoss, ((ST_CLOSE - ST_OPEN)/NULLIF(ST_OPEN,0))*100 AS PercentProfitLoss,
	YEAR(TRADEDATE) AS TRADEYEAR FROM STOCKDATA;


/*6.  During the learning content you created a view called ProcureProduct.  Use that view to provide details from each order 
including a total for each order, and a cumulative average across all orders. */

--CREATE VIEW
CREATE VIEW ProcureProduct
AS
SELECT  TOP 8
    O.Order_No AS OrderNo,
    OL.Line_No AS OrderLine,
    OL.Prod_Code AS ProdCode,
    P.Prod_Desc AS ProdDesc,
    OL.Qty AS Quantity,
    P.Prod_Price AS PriceEach,
    OL.Qty * P.Prod_Price AS OrderPrice
FROM Orders O 
JOIN Orderline OL 
    ON O.Order_No = OL.Order_No
JOIN Product P 
    ON OL.Prod_Code = P.Prod_Code
ORDER BY O.Order_No, OL.Line_No;

--VERIFY VIEW
SELECT * FROM ProcureProduct;

WITH OrderDetails AS (
    SELECT 
	OrderNo, ProdCode, ProdDesc, Quantity, OrderPrice, SUM(OrderPrice) OVER (PARTITION BY OrderNo) AS OrderTotal
    FROM ProcureProduct
)
SELECT 
    OrderNo, ProdCode, ProdDesc, Quantity, OrderPrice, OrderTotal,
    AVG(OrderTotal) OVER (ORDER BY OrderNo ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS AvgOrder
FROM OrderDetails
ORDER BY OrderNo, ProdCode;

/*7.  Write a stored procedure named pr_HalloweenFun that will support a funny MadLib situation for Halloween. Your stored 
procedure should be designed to allow for the following input parameters:
     •	Month
     •	Adjective
     •	Location
     •	Action Verb
     •	Plural Noun

Based on the input parameter, the stored procedure should display the following short story replacing the placeholders [   ] with 
the values from the input parameters.

     Every year at the end of _[name a month]_  kids dress up in _[adjective]_ costumes 
     and roam about _[location]_.  They _[action verb]_ doorbells and ask for _[plural noun]_.

Your answer should include both the SQL to create the stored procedure, and an example of the stored procedure being executed. */

-- Step 1: Create the stored procedure
CREATE PROCEDURE pr_HalloweenFun
    @Month NVARCHAR(20), 
    @Adjective NVARCHAR(50),
    @Location NVARCHAR(100),
    @ActionVerb NVARCHAR(50),
    @PluralNoun NVARCHAR(50)
AS
BEGIN
    PRINT 'Every year at the end of ' + @Month + 
          ', kids dress up in ' + @Adjective + 
          ' costumes and roam about ' + @Location + 
          '. They ' + @ActionVerb + ' doorbells and ask for ' + @PluralNoun + '.';
END;


-- Example execution of the stored procedure
EXEC pr_HalloweenFun 
    @Month = 'October', 
    @Adjective = 'Halloween', 
    @Location = 'the neighborhood', 
    @ActionVerb = 'ring', 
    @PluralNoun = 'trick or treat';



/*8. Create a stored procedure called StockHighLow to display for a given ticker and tradedate: the stocks high price for the day, the low price for the day, 
the percent change between the high and the low, and the volume. */
CREATE PROCEDURE StockHighLow 
    @TICKER NVARCHAR(20), 
    @TRADEDATE DATE
AS
BEGIN
    SELECT TICKER,TRADEDATE,ST_HIGH,ST_LOW, ((ST_HIGH - ST_LOW)/NULLIF(ST_LOW,0) *100) AS PercentChange, VOLUME  
    FROM STOCKDATA
    WHERE TICKER = @TICKER AND TRADEDATE = @TRADEDATE;
END;


EXEC StockHighLow @Ticker = 'HD', @TradeDate = '2021-03-09';


/*9.  Create a VIEW called Vendor615 to select all the vendors from the vendor table with area code 615.  The virtual table, 
Vendor615, should have the following columns:
     •	Vendor Code
     •	Vendor Contact
     •	Vendor Phone formatted as (xxx)xxx-xxxx
     •	Vendor Email

Once you have create your view, select all rows from the view to verify the data. */
--DROP VIEW Vendor615

CREATE VIEW Vendor615 AS
	SELECT Vend_Code AS Vendor_Code, Vend_Contact AS Vendor_Contact,
	'(' + CAST(Vend_AreaCode AS VARCHAR(3)) + ')' + SUBSTRING(Vend_Phone, 1, 3) + '-' + SUBSTRING(Vend_Phone, 4, 4) AS Vendor_Phone,
	EmailAddress AS Vendor_Email FROM VENDOR
	WHERE Vend_AreaCode = 615;

--VERIFY VIEW DATA
SELECT * FROM Vendor615;



/*10.  Create a stored procedure called pr_Vend615Details that allows the user to pass in a Vendor Code; in return the stored 
procedure should select the Vendor Name, Phone Number, and Email from the Vendor615 table.

Your answer should include both the SQL to create the stored procedure, and an example of the stored procedure being executed. */

-- Step 1: Create the stored procedure
CREATE PROCEDURE pr_Vend615Details
    @VendorCode INT
AS
BEGIN
    SELECT Vendor_Contact AS Vendor_Name, Vendor_Phone, Vendor_Email
    FROM Vendor615
    WHERE Vendor_Code = @VendorCode;
END;

--Example of the stored procedure being executed
EXEC pr_Vend615Details @VendorCode = 234



